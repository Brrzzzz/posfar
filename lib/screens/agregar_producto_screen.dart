import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:pos_farmacia_v2/models/producto.dart';

class AgregarProductoScreen extends StatefulWidget {
  final Producto? producto;
  const AgregarProductoScreen({super.key, this.producto});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  // Controladores para todos los campos de texto
  final _nombreController = TextEditingController();
  final _codigoBarrasController = TextEditingController();
  final _sustanciaActivaController = TextEditingController();
  final _precioController = TextEditingController();
  final _costoController = TextEditingController();
  final _stockMinimoController = TextEditingController();
  final _stockTotalController = TextEditingController();
  final _laboratorioController = TextEditingController();
  final _tipoProductoController = TextEditingController();
  final _proveedorController = TextEditingController();

  // Variables de estado de la pantalla
  late bool _requiereControlLote;
  final List<Lote> _lotes = [];
  bool get _isEditing => widget.producto != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // MODO EDICIÓN: Llenar campos con datos existentes
      final p = widget.producto!;
      _nombreController.text = p.nombre;
      _codigoBarrasController.text = p.codigoBarras;
      _sustanciaActivaController.text = p.sustanciaActiva;
      _precioController.text = p.precio.toString();
      _costoController.text = p.costo.toString();
      _stockMinimoController.text = p.stockMinimo.toString();
      _laboratorioController.text = p.detallesAdicionales.laboratorio;
      _tipoProductoController.text = p.detallesAdicionales.tipoDeProducto;
      _proveedorController.text = p.detallesAdicionales.proveedor;
      _requiereControlLote = p.requiereControlLote;
      _lotes.addAll(p.lotes);
    } else {
      // MODO AÑADIR: Iniciar con valores por defecto
      _requiereControlLote = true;
    }
    _actualizarStockTotalCalculado();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoBarrasController.dispose();
    _sustanciaActivaController.dispose();
    _precioController.dispose();
    _costoController.dispose();
    _stockMinimoController.dispose();
    _stockTotalController.dispose();
    _laboratorioController.dispose();
    _tipoProductoController.dispose();
    _proveedorController.dispose();
    super.dispose();
  }

  // Función segura para actualizar el stock total cuando se usan lotes
  void _actualizarStockTotalCalculado() {
    if (_requiereControlLote) {
      final stockCalculado = _lotes.fold<int>(0, (sum, lote) => sum + lote.stockEnLote);
      _stockTotalController.text = stockCalculado.toString();
    }
  }

  Future<void> _guardarProducto() async {
    if (_nombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre del producto es obligatorio.'), backgroundColor: Colors.red));
      return;
    }
    try {
      int stockTotal;
      if (_requiereControlLote) {
        stockTotal = _lotes.fold<int>(0, (sum, lote) => sum + lote.stockEnLote);
      } else {
        stockTotal = int.tryParse(_stockTotalController.text) ?? 0;
      }

      final productoData = {
        'nombre': _nombreController.text.trim(),
        'codigoBarras': _codigoBarrasController.text.trim(),
        'sustanciaActiva': _sustanciaActivaController.text.trim(),
        'precio': double.tryParse(_precioController.text) ?? 0.0,
        'costo': double.tryParse(_costoController.text) ?? 0.0,
        'stockMinimo': int.tryParse(_stockMinimoController.text) ?? 0,
        'stockTotal': stockTotal,
        'requiereControlLote': _requiereControlLote,
        'detallesAdicionales': {'laboratorio': _laboratorioController.text.trim(),'proveedor': _proveedorController.text.trim(),'tipoDeProducto': _tipoProductoController.text.trim(),},
        'lotes': _requiereControlLote ? _lotes.map((lote) => lote.toMap()).toList() : [],
      };
      
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('productos').doc(widget.producto!.id).update(productoData);
      } else {
        await FirebaseFirestore.instance.collection('productos').add(productoData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Producto ${_isEditing ? 'actualizado' : 'guardado'} con éxito'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _mostrarDialogoAnadirLote() async {
    final loteIdController = TextEditingController();
    final stockController = TextEditingController();
    final caducidadController = TextEditingController();
    final mascaraFecha = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Añadir Nuevo Lote'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: loteIdController, decoration: const InputDecoration(labelText: 'Clave del Lote')),
                TextField(controller: stockController, decoration: const InputDecoration(labelText: 'Cantidad en este Lote'), keyboardType: TextInputType.number),
                TextField(
                  controller: caducidadController,
                  inputFormatters: [mascaraFecha],
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Fecha de Caducidad',
                    hintText: 'DD/MM/AAAA',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                          locale: const Locale('es', 'MX'),
                        );
                        if (picked != null) {
                          String fechaFormateada = DateFormat('dd/MM/yyyy').format(picked);
                          caducidadController.text = fechaFormateada;
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('CANCELAR'), onPressed: () => Navigator.of(context).pop()),
            FilledButton(
              child: const Text('AÑADIR'),
              onPressed: () {
                DateTime? fechaDeCaducidad;
                if (caducidadController.text.isNotEmpty) {
                  try {
                    fechaDeCaducidad = DateFormat('dd/MM/yyyy').parse(caducidadController.text);
                  } catch (e) { return; }
                }
                if (loteIdController.text.isEmpty || stockController.text.isEmpty || fechaDeCaducidad == null) return;
                
                final nuevoLote = Lote(loteId: loteIdController.text, stockEnLote: int.tryParse(stockController.text) ?? 0, fechaCaducidad: fechaDeCaducidad);
                setState(() {
                  _lotes.add(nuevoLote);
                  _actualizarStockTotalCalculado(); // Actualizamos el stock total
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar Producto' : 'Añadir Nuevo Producto'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [IconButton(icon: const Icon(Icons.save), onPressed: _guardarProducto)],
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.info_outline), text: 'Info. General'),
              const Tab(icon: Icon(Icons.label_outline), text: 'Detalles'),
              Tab(icon: Icon(Icons.inventory_2_outlined, color: _requiereControlLote ? null : Colors.grey), child: Text('Lotes', style: TextStyle(color: _requiereControlLote ? null : Colors.grey))),
            ],
          ),
        ),
        body: TabBarView(
          physics: _requiereControlLote ? null : const NeverScrollableScrollPhysics(),
          children: [
            _buildInfoGeneralTab(),
            _buildDetallesTab(),
            _requiereControlLote
                ? _buildLotesTab()
                : const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('El control de lotes está desactivado para este producto.', textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Requiere Control de Lote y Caducidad'),
            value: _requiereControlLote,
            onChanged: (bool value) { setState(() { _requiereControlLote = value; _actualizarStockTotalCalculado(); }); },
            secondary: const Icon(Icons.track_changes),
          ),
          const Divider(),
          TextField(controller: _codigoBarrasController, decoration: const InputDecoration(labelText: 'Código de Barras', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre del Producto', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(
            controller: _stockTotalController,
            decoration: InputDecoration(
                labelText: 'Stock Total',
                border: const OutlineInputBorder(),
                enabled: !_requiereControlLote,
                fillColor: _requiereControlLote ? Colors.grey.shade200 : null,
                filled: _requiereControlLote),
            keyboardType: TextInputType.number,
            readOnly: _requiereControlLote,
          ),
          const SizedBox(height: 16),
          TextField(controller: _sustanciaActivaController, decoration: const InputDecoration(labelText: 'Sustancia Activa', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: _costoController, decoration: const InputDecoration(labelText: 'Costo', prefixText: '\$ ', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
            const SizedBox(width: 16),
            Expanded(child: TextField(controller: _precioController, decoration: const InputDecoration(labelText: 'Precio de Venta', prefixText: '\$ ', border: OutlineInputBorder()), keyboardType: TextInputType.number))
          ]),
          const SizedBox(height: 16),
          TextField(controller: _stockMinimoController, decoration: const InputDecoration(labelText: 'Stock Mínimo', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildDetallesTab() {
     return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _laboratorioController, decoration: const InputDecoration(labelText: 'Laboratorio', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _tipoProductoController, decoration: const InputDecoration(labelText: 'Tipo de Producto (ej. Patente, Genérico)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _proveedorController, decoration: const InputDecoration(labelText: 'Proveedor', border: OutlineInputBorder())),
        ],
      ),
    );
  }

  Widget _buildLotesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Añadir Lote'),
              onPressed: _mostrarDialogoAnadirLote,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))),
          const SizedBox(height: 24),
          Text('Lotes Añadidos:', style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          Expanded(
              child: _lotes.isEmpty
                  ? const Center(child: Text('Aún no has añadido ningún lote.'))
                  : ListView.builder(
                      itemCount: _lotes.length,
                      itemBuilder: (context, index) {
                        final lote = _lotes[index];
                        return Card(
                            child: ListTile(
                                title: Text('Lote: ${lote.loteId}'),
                                subtitle: Text('Cantidad: ${lote.stockEnLote} - Caduca: ${DateFormat('dd/MM/yyyy').format(lote.fechaCaducidad)}'),
                                trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _lotes.removeAt(index);
                                        _actualizarStockTotalCalculado();
                                      });
                                    })));
                      }))
        ],
      ),
    );
  }
}