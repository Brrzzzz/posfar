import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_farmacia_v2/models/compra.dart';
import 'package:pos_farmacia_v2/models/producto.dart';

class LineaCompra {
  final Producto producto;
  final TextEditingController cantidadController = TextEditingController(text: '1');
  final TextEditingController costoController;
  final TextEditingController precioController;

  LineaCompra({required this.producto})
      : costoController = TextEditingController(text: producto.costo.toStringAsFixed(2)),
        precioController = TextEditingController(text: producto.precio.toStringAsFixed(2));

  void dispose() {
    cantidadController.dispose();
    costoController.dispose();
    precioController.dispose();
  }
}

class IngresarCompraScreen extends StatefulWidget {
  const IngresarCompraScreen({super.key});

  @override
  State<IngresarCompraScreen> createState() => _IngresarCompraScreenState();
}

class _IngresarCompraScreenState extends State<IngresarCompraScreen> {
  final _proveedorController = TextEditingController();
  final _facturaController = TextEditingController();
  final _codigoController = TextEditingController();
  final _codigoFocusNode = FocusNode();
  final List<LineaCompra> _listaCompra = [];
  List<Producto> _catalogoCompleto = [];
  bool _cargandoCatalogo = true;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _proveedorController.dispose();
    _facturaController.dispose();
    _codigoController.dispose();
    _codigoFocusNode.dispose();
    for (var linea in _listaCompra) {
      linea.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('productos').get();
      final productosCargados = snapshot.docs.map((doc) => Producto.fromFirestore(doc)).toList();
      if (mounted) setState(() { _catalogoCompleto = productosCargados; _cargandoCatalogo = false; });
    } catch (e) {
      if (mounted) setState(() => _cargandoCatalogo = false);
    }
  }

  void _agregarProductoACompra(String codigo) {
    if (codigo.isEmpty) { _codigoFocusNode.requestFocus(); return; }
    try {
      final productoEncontrado = _catalogoCompleto.firstWhere((p) => p.codigoBarras == codigo);
      final yaExiste = _listaCompra.any((linea) => linea.producto.id == productoEncontrado.id);
      if (yaExiste) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${productoEncontrado.nombre} ya está en la lista. Ajuste la cantidad directamente.'), backgroundColor: Colors.orange));
      } else {
        setState(() {
          _listaCompra.add(LineaCompra(producto: productoEncontrado));
        });
      }
      _codigoController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Producto con código "$codigo" no encontrado.'), backgroundColor: Colors.red));
    }
    _codigoFocusNode.requestFocus();
  }

  void _quitarDeLaLista(int index) {
    setState(() {
      _listaCompra[index].dispose();
      _listaCompra.removeAt(index);
    });
  }

  // --- ¡LÓGICA DE GUARDADO FINAL! ---
  Future<void> _guardarCompra() async {
    if (_listaCompra.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La lista de compra está vacía.'), backgroundColor: Colors.orange));
      return;
    }
    // Mostramos un indicador de carga para que el usuario sepa que algo está pasando
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      // 1. Creamos la "lista de tareas" atómica
      final batch = FirebaseFirestore.instance.batch();
      double totalDeLaCompra = 0;
      List<ItemCompra> itemsParaElRegistro = [];

      // 2. Recorremos cada producto en nuestra lista visual
      for (var linea in _listaCompra) {
        final productoRef = FirebaseFirestore.instance.collection('productos').doc(linea.producto.id);
        
        final nuevoCosto = double.tryParse(linea.costoController.text) ?? linea.producto.costo;
        final nuevoPrecio = double.tryParse(linea.precioController.text) ?? linea.producto.precio;
        final cantidadRecibida = int.tryParse(linea.cantidadController.text) ?? 0;

        if (cantidadRecibida > 0) {
          // Tarea A: Actualizar el producto en el inventario
          batch.update(productoRef, {
            'costo': nuevoCosto,
            'precio': nuevoPrecio,
            'stockTotal': FieldValue.increment(cantidadRecibida),
            // Por ahora no manejamos lotes en esta pantalla simplificada
          });

          // Acumulamos los datos para el recibo de la compra
          totalDeLaCompra += nuevoCosto * cantidadRecibida;
          itemsParaElRegistro.add(ItemCompra(
            productoId: linea.producto.id,
            productoNombre: linea.producto.nombre,
            cantidad: cantidadRecibida,
            costo: nuevoCosto,
          ));
        }
      }

      // 3. Tarea B: Crear el registro de la compra en la colección "compras"
      if (itemsParaElRegistro.isNotEmpty) {
        final compraRef = FirebaseFirestore.instance.collection('compras').doc();
        final nuevaCompra = Compra(
          id: compraRef.id,
          proveedor: _proveedorController.text.trim(),
          facturaNro: _facturaController.text.trim(),
          fecha: DateTime.now(),
          totalCompra: totalDeLaCompra,
          items: itemsParaElRegistro,
        );
        batch.set(compraRef, nuevaCompra.toMap());
      }

      // 4. Ejecutamos todas las tareas a la vez
      await batch.commit();

      // 5. Si todo sale bien, limpiamos la pantalla
      if (mounted) {
        Navigator.of(context).pop(); // Cierra el diálogo de carga
        setState(() {
          for (var linea in _listaCompra) { linea.dispose(); }
          _listaCompra.clear();
          _proveedorController.clear();
          _facturaController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compra guardada y stock actualizado con éxito.'), backgroundColor: Colors.green));
      }
    } catch (e) {
       if (mounted) {
        Navigator.of(context).pop(); // Cierra el diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar la compra: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoCatalogo) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zona 1: Datos de la Factura
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                Expanded(child: TextField(controller: _proveedorController, decoration: const InputDecoration(labelText: 'Proveedor', border: OutlineInputBorder()))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _facturaController, decoration: const InputDecoration(labelText: 'No. de Factura / Remisión', border: OutlineInputBorder()))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // Zona 2: Búsqueda de Productos
          TextField(
            controller: _codigoController,
            focusNode: _codigoFocusNode,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Escanear o digitar código para añadir producto...', border: OutlineInputBorder(), suffixIcon: Icon(Icons.qr_code_scanner)),
            onSubmitted: _agregarProductoACompra,
          ),
          const Divider(height: 32),
          // Zona 3: Lista de Productos
          Text('Productos en esta Compra:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: _listaCompra.isEmpty
                  ? const Center(child: Text('Añade productos para verlos aquí.'))
                  : ListView.builder(
                      itemCount: _listaCompra.length,
                      itemBuilder: (context, index) {
                        final linea = _listaCompra[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(flex: 4, child: Text(linea.producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold))),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: TextField(controller: linea.cantidadController, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number)),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: TextField(controller: linea.costoController, decoration: const InputDecoration(labelText: 'Costo', prefixText: '\$'), keyboardType: TextInputType.number)),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: TextField(controller: linea.precioController, decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$'), keyboardType: TextInputType.number)),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _quitarDeLaLista(index)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Zona 4: Botón de Guardar
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('GUARDAR COMPRA EN INVENTARIO'),
            onPressed: _guardarCompra,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}