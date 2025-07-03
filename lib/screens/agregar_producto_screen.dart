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
  // La llave para nuestro formulario
  final _formKey = GlobalKey<FormState>();

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

  late bool _requiereControlLote;
  late bool _esControlado;
  final List<Lote> _lotes = [];
  bool get _isEditing => widget.producto != null;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.producto!;
      _nombreController.text = p.nombre;
      _codigoBarrasController.text = p.codigoBarras;
      _sustanciaActivaController.text = p.sustanciaActiva;
      _precioController.text = p.precio.toStringAsFixed(2);
      _costoController.text = p.costo.toStringAsFixed(2);
      _stockMinimoController.text = p.stockMinimo.toString();
      _laboratorioController.text = p.detallesAdicionales.laboratorio;
      _tipoProductoController.text = p.detallesAdicionales.tipoDeProducto;
      _proveedorController.text = p.detallesAdicionales.proveedor;
      _requiereControlLote = p.requiereControlLote;
      _esControlado = p.esControlado;
      _stockTotalController.text = p.stockTotal.toString();
      if (p.requiereControlLote) {
        _lotes.addAll(p.lotes);
      }
    } else {
      _requiereControlLote = false;
      _esControlado = false;
      _stockTotalController.text = '0';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose(); _codigoBarrasController.dispose(); _sustanciaActivaController.dispose();
    _precioController.dispose(); _costoController.dispose(); _stockMinimoController.dispose();
    _stockTotalController.dispose(); _laboratorioController.dispose(); _tipoProductoController.dispose();
    _proveedorController.dispose();
    super.dispose();
  }

  void _actualizarStockTotalCalculado() {
    if (_requiereControlLote) {
      final stockCalculado = _lotes.fold<int>(0, (sum, lote) => sum + lote.stockEnLote);
      setState(() {
        _stockTotalController.text = stockCalculado.toString();
      });
    }
  }

  Future<void> _guardarProducto() async {
    // La validación ahora funcionará porque la llave está conectada
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSaving = true; });

    try {
      int stockTotal;
      if (_requiereControlLote) {
        stockTotal = _lotes.fold<int>(0, (sum, lote) => sum + lote.stockEnLote);
      } else {
        stockTotal = int.tryParse(_stockTotalController.text) ?? 0;
      }
      final productoData = {
        'nombre': _nombreController.text.trim(), 'codigoBarras': _codigoBarrasController.text.trim(),
        'sustanciaActiva': _sustanciaActivaController.text.trim(), 'precio': double.tryParse(_precioController.text) ?? 0.0,
        'costo': double.tryParse(_costoController.text) ?? 0.0, 'stockMinimo': int.tryParse(_stockMinimoController.text) ?? 0,
        'stockTotal': stockTotal, 'requiereControlLote': _requiereControlLote,
        'esControlado': _esControlado,
        'detallesAdicionales': { 'laboratorio': _laboratorioController.text.trim(), 'proveedor': _proveedorController.text.trim(), 'tipoDeProducto': _tipoProductoController.text.trim() },
        'lotes': _requiereControlLote ? _lotes.map((lote) => lote.toMap()).toList() : [],
      };
      
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('productos').doc(widget.producto!.id).update(productoData);
      } else {
        await FirebaseFirestore.instance.collection('productos').add(productoData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Producto ${_isEditing ? 'actualizado' : 'guardado'} con éxito'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }
  
  void _mostrarDialogoAnadirLote() {
    final loteController = TextEditingController();
    final stockLoteController = TextEditingController();
    final caducidadController = TextEditingController();
    final mascaraFecha = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Añadir Nuevo Lote'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: loteController, decoration: const InputDecoration(labelText: 'ID del Lote'), autofocus: true),
                TextField(controller: stockLoteController, decoration: const InputDecoration(labelText: 'Stock del Lote'), keyboardType: TextInputType.number),
                TextField(controller: caducidadController, decoration: const InputDecoration(labelText: 'Fecha de Caducidad', hintText: 'DD/MM/AAAA'), keyboardType: TextInputType.datetime, inputFormatters: [mascaraFecha]),
              ]),
              actions: [
                TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
                FilledButton(
                    child: const Text('Añadir'),
                    onPressed: () {
                      if (loteController.text.isNotEmpty && stockLoteController.text.isNotEmpty && caducidadController.text.isNotEmpty) {
                        try {
                          final fecha = DateFormat('dd/MM/yyyy').parse(caducidadController.text);
                          setState(() {
                            _lotes.add(Lote(loteId: loteController.text, stockEnLote: int.tryParse(stockLoteController.text) ?? 0, fechaCaducidad: fecha));
                            _actualizarStockTotalCalculado();
                          });
                          Navigator.of(context).pop();
                        } catch (e) {
                          // Manejar error de fecha inválida si es necesario
                        }
                      }
                    }),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Añadir Nuevo Producto'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form( // El Formulario usa la llave _formKey
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Información General', style: Theme.of(context).textTheme.headlineSmall),
                    const Divider(height: 24),
                    TextFormField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre del Producto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.abc))),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _codigoBarrasController, decoration: const InputDecoration(labelText: 'Código de Barras', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)))),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(controller: _sustanciaActivaController, decoration: const InputDecoration(labelText: 'Sustancia Activa', border: OutlineInputBorder(), prefixIcon: Icon(Icons.science_outlined)))),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _costoController, decoration: const InputDecoration(labelText: 'Costo', prefixText: '\$', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(controller: _precioController, decoration: const InputDecoration(labelText: 'Precio de Venta', prefixText: '\$', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 32),
                    Text('Detalles Adicionales', style: Theme.of(context).textTheme.headlineSmall),
                    const Divider(height: 24),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _laboratorioController, decoration: const InputDecoration(labelText: 'Laboratorio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.factory_outlined)))),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(controller: _tipoProductoController, decoration: const InputDecoration(labelText: 'Tipo de Producto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)))),
                    ]),
                    const SizedBox(height: 16),
                    TextFormField(controller: _proveedorController, decoration: const InputDecoration(labelText: 'Proveedor', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_shipping_outlined))),
                    const SizedBox(height: 32),
                    Text('Control de Inventario y Venta', style: Theme.of(context).textTheme.headlineSmall),
                    const Divider(height: 24),
                    SwitchListTile(title: const Text('Requiere Control de Lote'), subtitle: const Text('Activar si se controla por lotes y caducidades'), value: _requiereControlLote, onChanged: (bool value) { setState(() { _requiereControlLote = value; if(!value) { _lotes.clear(); } _actualizarStockTotalCalculado(); }); }),
                    SwitchListTile(title: const Text('Es Antibiótico / Controlado'), subtitle: const Text('Marcar si requiere receta médica para su venta'), value: _esControlado, onChanged: (bool value) { setState(() { _esControlado = value; }); }, secondary: Icon(Icons.shield_outlined, color: _esControlado ? Colors.red.shade700 : Colors.grey)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _stockMinimoController, decoration: const InputDecoration(labelText: 'Stock Mínimo', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(controller: _stockTotalController, decoration: const InputDecoration(labelText: 'Stock Total', border: OutlineInputBorder()), readOnly: _requiereControlLote, keyboardType: TextInputType.number)),
                    ]),
                    if (_requiereControlLote) _buildLotesSection(),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(width: double.infinity, child: FilledButton.icon(
              icon: _isSaving ? Container() : const Icon(Icons.save),
              label: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : Text(_isEditing ? 'ACTUALIZAR PRODUCTO' : 'GUARDAR PRODUCTO'),
              onPressed: _isSaving ? null : _guardarProducto,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildLotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Gestión de Lotes', style: Theme.of(context).textTheme.headlineSmall), TextButton.icon(onPressed: _mostrarDialogoAnadirLote, icon: const Icon(Icons.add), label: const Text('Añadir Lote'))]),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
          child: _lotes.isEmpty ? const Center(child: Text('No hay lotes para este producto.')) : ListView.builder(
            itemCount: _lotes.length,
            itemBuilder: (context, index) {
              final lote = _lotes[index];
              return ListTile(
                title: Text('Lote: ${lote.loteId}'),
                subtitle: Text('Caducidad: ${DateFormat('dd/MM/yyyy').format(lote.fechaCaducidad)}'),
                trailing: Text('Stock: ${lote.stockEnLote}'),
                dense: true,
              );
            },
          ),
        ),
      ],
    );
  }
}