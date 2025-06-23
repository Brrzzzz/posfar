// Archivo Simplificado: lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_farmacia_v2/models/producto.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _cargandoDatos = true;
  double _ventasDelDia = 0.0;
  int _numeroDeTickets = 0;
  int _alertasStockBajo = 0;
  int _alertasCaducidad = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosDashboard();
  }

  Future<void> _cargarDatosDashboard() async {
    if (!mounted) return;
    setState(() { _cargandoDatos = true; });

    final ahora = DateTime.now();
    final inicioDelDia = DateTime(ahora.year, ahora.month, ahora.day);
    final finDelDia = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);

    final queryVentas = await FirebaseFirestore.instance
        .collection('ventas')
        .where('fecha', isGreaterThanOrEqualTo: inicioDelDia)
        .where('fecha', isLessThanOrEqualTo: finDelDia)
        .where('estado', isEqualTo: 'Completada')
        .get();

    double ventasTemp = 0.0;
    for (var doc in queryVentas.docs) {
      ventasTemp += (doc.data()['total'] as num?)?.toDouble() ?? 0.0;
    }
    
    final queryProductos = await FirebaseFirestore.instance.collection('productos').get();
    final productos = queryProductos.docs.map((doc) => Producto.fromFirestore(doc)).toList();

    int stockBajoTemp = 0;
    int caducidadTemp = 0;
    final fechaLimiteCaducidad = DateTime.now().add(const Duration(days: 30));

    for (var producto in productos) {
      if (producto.stockTotal > 0 && producto.stockTotal <= producto.stockMinimo) {
        stockBajoTemp++;
      }
      if (producto.requiereControlLote) {
        bool productoYaContado = false;
        for (var lote in producto.lotes) {
          if (lote.fechaCaducidad.isBefore(fechaLimiteCaducidad) && !productoYaContado) {
            caducidadTemp++;
            productoYaContado = true;
          }
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _ventasDelDia = ventasTemp;
        _numeroDeTickets = queryVentas.docs.length;
        _alertasStockBajo = stockBajoTemp;
        _alertasCaducidad = caducidadTemp;
        _cargandoDatos = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _cargandoDatos
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatosDashboard,
              child: ListView(
                children: [
                  Text('Resumen del Día', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 4,
                    child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _buildResumen('Ventas Totales', '\$${_ventasDelDia.toStringAsFixed(2)}'),
                          _buildResumen('N° de Tickets', _numeroDeTickets.toString()),
                        ],),),
                  ),
                  const SizedBox(height: 24),
                  Text('Alertas Críticas', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 4,
                    color: (_alertasStockBajo > 0 || _alertasCaducidad > 0) ? Colors.red.shade50 : Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _buildResumen('Stock Bajo', _alertasStockBajo.toString(), color: _alertasStockBajo > 0 ? Colors.red.shade700 : Colors.green),
                          _buildResumen('Por Caducar (30d)', _alertasCaducidad.toString(), color: _alertasCaducidad > 0 ? Colors.orange.shade800 : Colors.green),
                        ],),),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildResumen(String titulo, String valor, {Color color = Colors.black}) {
    return Column(
      children: [
        Text(titulo, style: TextStyle(color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}