import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_farmacia_v2/models/producto.dart';

class VerificadorPreciosScreen extends StatefulWidget {
  const VerificadorPreciosScreen({super.key});

  @override
  State<VerificadorPreciosScreen> createState() => _VerificadorPreciosScreenState();
}

class _VerificadorPreciosScreenState extends State<VerificadorPreciosScreen> {
  final _codigoController = TextEditingController();
  final _codigoFocusNode = FocusNode();
  List<Producto> _catalogoCompleto = [];
  bool _cargando = true;
  Producto? _productoEncontrado;
  String? _mensajeDeEstado;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }
  
  @override
  void dispose() {
    _codigoController.dispose();
    _codigoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('productos').get();
      final productosCargados = snapshot.docs.map((doc) => Producto.fromFirestore(doc)).toList();
      if (mounted) {
        setState(() {
          _catalogoCompleto = productosCargados;
          _cargando = false;
          _mensajeDeEstado = 'Escanee un producto para ver su precio';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _buscarProducto(String codigo) {
    if (codigo.isEmpty) return;
    try {
      final producto = _catalogoCompleto.firstWhere((p) => p.codigoBarras == codigo);
      setState(() { _productoEncontrado = producto; _mensajeDeEstado = null; });
    } catch (e) {
      setState(() { _productoEncontrado = null; _mensajeDeEstado = 'Producto no encontrado'; });
    } finally {
      _codigoController.clear();
      _codigoFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
      child: Column(
        children: [
          TextField(controller: _codigoController, focusNode: _codigoFocusNode, autofocus: true, style: const TextStyle(fontSize: 22), decoration: const InputDecoration(labelText: 'Escanear Código de Barras', prefixIcon: Icon(Icons.qr_code_scanner, size: 30), border: OutlineInputBorder()), onSubmitted: _buscarProducto),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                child: _cargando ? const Center(child: CircularProgressIndicator()) : _buildResultado(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultado() {
    if (_productoEncontrado != null) {
      final producto = _productoEncontrado!;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- NUEVA ALERTA DE PRODUCTO CONTROLADO ---
            if (producto.esControlado)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Chip(
                  label: const Text('ANTIBIÓTICO / CONTROLADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.red.shade700,
                  avatar: const Icon(Icons.warning, color: Colors.white),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            // --- NOMBRE Y PRECIO DESTACADOS ---
            Text(producto.nombre, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('\$${producto.precio.toStringAsFixed(2)}', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor)),
            const Divider(height: 32),
            
            // --- DETALLES EN DOS COLUMNAS ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildDetailRow('Código:', producto.codigoBarras),
                  _buildDetailRow('Sustancia Activa:', producto.sustanciaActiva),
                  _buildDetailRow('Laboratorio:', producto.detallesAdicionales.laboratorio),
                ])),
                const SizedBox(width: 24),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildDetailRow('Existencia:', producto.stockTotal.toString()),
                  _buildDetailRow('Tipo de Producto:', producto.detallesAdicionales.tipoDeProducto),
                  _buildDetailRow('Proveedor:', producto.detallesAdicionales.proveedor),
                ])),
              ],
            )
          ],
        ),
      );
    } else {
      // Mensaje de estado
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_mensajeDeEstado == 'Producto no encontrado' ? Icons.error_outline : Icons.info_outline, size: 100, color: _mensajeDeEstado == 'Producto no encontrado' ? Colors.red : Colors.grey),
        const SizedBox(height: 16),
        Text(_mensajeDeEstado ?? '', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700), textAlign: TextAlign.center),
      ]));
    }
  }

  // Pequeño widget de ayuda para crear cada fila de detalle
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}