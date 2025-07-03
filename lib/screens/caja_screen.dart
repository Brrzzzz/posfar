import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => CajaScreenState();
}

class CajaScreenState extends State<CajaScreen> {
  bool _cargando = true;
  double _totalVentas = 0.0;
  double _totalVentasEfectivo = 0.0;
  double _totalVentasTarjeta = 0.0;
  int _numeroTickets = 0;
  int _productosVendidos = 0;
  DateTime _fechaSeleccionada = DateTime.now();
  double _fondoDeCaja = 0.0;

  @override
  void initState() {
    super.initState();
    calcularCorteDeCaja();
  }

  Future<void> calcularCorteDeCaja() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final String docId = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
      
      final fondoDoc = await FirebaseFirestore.instance.collection('cortes').doc(docId).get();
      if (fondoDoc.exists) {
        _fondoDeCaja = (fondoDoc.data()?['fondoInicial'] as num?)?.toDouble() ?? 0.0;
      } else {
        _fondoDeCaja = 0.0;
      }

      final inicioDelDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day);
      final finDelDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day, 23, 59, 59);

      final queryVentas = await FirebaseFirestore.instance.collection('ventas')
          .where('fecha', isGreaterThanOrEqualTo: inicioDelDia)
          .where('fecha', isLessThanOrEqualTo: finDelDia)
          .where('estado', isEqualTo: 'Completada').get();

      double ventasTemp = 0.0;
      double ventasEfectivoTemp = 0.0;
      double ventasTarjetaTemp = 0.0;
      int productosTemp = 0;

      for (var doc in queryVentas.docs) {
        final data = doc.data();
        final totalVenta = (data['total'] as num?)?.toDouble() ?? 0.0;
        ventasTemp += totalVenta;
        
        if (data['formaDePago'] == 'Tarjeta') {
          ventasTarjetaTemp += totalVenta;
        } else {
          ventasEfectivoTemp += totalVenta;
        }

        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        for (var item in items) {
          productosTemp += (item['cantidad'] as num?)?.toInt() ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _totalVentas = ventasTemp;
          _totalVentasEfectivo = ventasEfectivoTemp;
          _totalVentasTarjeta = ventasTarjetaTemp;
          _numeroTickets = queryVentas.docs.length;
          _productosVendidos = productosTemp;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }
  
  Future<void> _mostrarDialogoFondoDeCaja() async {
    final fondoController = TextEditingController(text: _fondoDeCaja > 0 ? _fondoDeCaja.toString() : '');
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Establecer Fondo de Caja Inicial'),
          content: TextField(controller: fondoController, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto Inicial', prefixText: '\$ ')),
          actions: [
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
            FilledButton(
              child: const Text('Guardar'),
              onPressed: () async {
                final monto = double.tryParse(fondoController.text) ?? 0.0;
                final String docId = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
                await FirebaseFirestore.instance.collection('cortes').doc(docId).set({'fondoInicial': monto});
                if (mounted) Navigator.of(context).pop();
                await calcularCorteDeCaja();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _fechaSeleccionada, firstDate: DateTime(2020), lastDate: DateTime.now(), locale: const Locale('es'));
    if (picked != null && picked != _fechaSeleccionada) {
      setState(() { _fechaSeleccionada = picked; });
      calcularCorteDeCaja();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month, color: Colors.grey),
              const SizedBox(width: 8),
              Text('Mostrando corte para:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 16),
              TextButton(
                child: Text(DateFormat.yMMMMEEEEd('es').format(_fechaSeleccionada), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
                onPressed: () => _seleccionarFecha(context),
              ),
              const Spacer(),
              ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Actualizar'), onPressed: calcularCorteDeCaja),
            ],
          ),
          const Divider(height: 32),
          _cargando
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: ListView(
                    children: [
                      _buildFondoDeCajaCard(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Ventas en Efectivo', '\$${_totalVentasEfectivo.toStringAsFixed(2)}', Icons.money_rounded, Colors.green)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Ventas con Tarjeta', '\$${_totalVentasTarjeta.toStringAsFixed(2)}', Icons.credit_card, Colors.lightBlue)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Nº de Tickets', _numeroTickets.toString(), Icons.receipt_long, Colors.purple)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Productos Vendidos', _productosVendidos.toString(), Icons.inventory_2, Colors.orange)),
                        ],
                      ),
                       const SizedBox(height: 16),
                      Card(
                        elevation: 6,
                        color: Theme.of(context).colorScheme.primary,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.summarize, size: 50, color: Colors.white),
                              const SizedBox(width: 24),
                              Column(
                                children: [
                                  Text("Venta Total del Día", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                                  Text('\$${_totalVentas.toStringAsFixed(2)}', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFondoDeCajaCard() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.savings_outlined, color: Colors.brown, size: 40),
        title: const Text('Fondo de Caja Inicial'),
        subtitle: Text('\$${_fondoDeCaja.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        trailing: TextButton(
          child: const Text('Establecer / Editar'),
          onPressed: _mostrarDialogoFondoDeCaja,
        ),
      ),
    );
  }

  // --- FUNCIÓN COMPLETA QUE FALTABA ---
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}