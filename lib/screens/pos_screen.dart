import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pos_farmacia_v2/models/medico.dart';
import 'package:pos_farmacia_v2/models/producto.dart';
import 'package:pos_farmacia_v2/models/venta.dart';
import 'package:pos_farmacia_v2/screens/agregar_medico_screen.dart';
import 'package:pos_farmacia_v2/widgets/product_search_delegate.dart';

class LineaVenta {
  final Producto producto;
  final Lote loteSeleccionado;
  final TextEditingController cantidadController;
  final TextEditingController descuentoController = TextEditingController(text: '0');

  LineaVenta({required this.producto, required this.loteSeleccionado, int cantidadInicial = 1})
      : cantidadController = TextEditingController(text: cantidadInicial.toString());

  int get cantidad => int.tryParse(cantidadController.text) ?? 1;

  void dispose() {
    cantidadController.dispose();
    descuentoController.dispose();
  }
}

class PosScreen extends StatefulWidget {
  final ValueChanged<bool>? onCartStateChanged;
  const PosScreen({super.key, this.onCartStateChanged});

  @override
  State<PosScreen> createState() => PosScreenState();
}

class PosScreenState extends State<PosScreen> {
  bool get isCartNotEmpty => _carrito.isNotEmpty;

  late String _folioVenta;
  final _clienteController = TextEditingController(text: 'Cliente Mostrador');
  final _observacionesController = TextEditingController();
  final _codigoController = TextEditingController();
  final _codigoFocusNode = FocusNode();
  final List<LineaVenta> _carrito = [];
  double _subtotal = 0.0;
  double _iva = 0.0;
  double _total = 0.0;
  List<Producto> _catalogoCompleto = [];
  bool _cargandoCatalogo = true;
  int? _filaSeleccionada;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
    _generarNuevoFolio();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clienteController.dispose();
    _observacionesController.dispose();
    _codigoController.dispose();
    _codigoFocusNode.dispose();
    for (var linea in _carrito) {
      linea.dispose();
    }
    super.dispose();
  }

  void _notificarCambioEnCarrito() {
    widget.onCartStateChanged?.call(_carrito.isNotEmpty);
  }

  void _generarNuevoFolio() {
    setState(() {
      _folioVenta = 'VT-${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  Future<void> _cargarCatalogo() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('productos').get();
      final productosCargados = snapshot.docs.map((doc) => Producto.fromFirestore(doc)).toList();
      if (mounted)
        setState(() {
          _catalogoCompleto = productosCargados;
          _cargandoCatalogo = false;
        });
    } catch (e) {
      if (mounted) setState(() => _cargandoCatalogo = false);
    }
  }

  void _agregarProductoAlCarrito(String codigo) {
    if (codigo.isEmpty) {
      _codigoFocusNode.requestFocus();
      return;
    }
    try {
      final productoEncontrado = _catalogoCompleto.firstWhere((p) => p.codigoBarras == codigo, orElse: () => throw Exception('Producto no encontrado'));
      
      Lote loteParaVender;
      if (productoEncontrado.requiereControlLote) {
        var lotesDisponibles = productoEncontrado.lotes.where((l) => l.stockEnLote > 0).toList();
        if (lotesDisponibles.isEmpty) {
           loteParaVender = productoEncontrado.lotes.isNotEmpty 
            ? productoEncontrado.lotes.first 
            : Lote(loteId: 'SIN LOTE', stockEnLote: 0, fechaCaducidad: DateTime.now());
        }
        else {
          lotesDisponibles.sort((a, b) => a.fechaCaducidad.compareTo(b.fechaCaducidad));
          loteParaVender = lotesDisponibles.first;
        }
      } else {
        loteParaVender = Lote(loteId: 'N/A', stockEnLote: productoEncontrado.stockTotal, fechaCaducidad: DateTime(2099));
      }

      setState(() {
        final indiceExistente = _carrito.indexWhere((linea) => linea.producto.id == productoEncontrado.id && linea.loteSeleccionado.loteId == loteParaVender.loteId);
        if (indiceExistente >= 0) {
          _incrementarCantidad(indiceExistente);
        } else {
          _carrito.add(LineaVenta(producto: productoEncontrado, loteSeleccionado: loteParaVender));
        }
        _recalcularTotales();
      });
      _codigoController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red));
    }
    _codigoFocusNode.requestFocus();
  }

  void _incrementarCantidad(int index) {
    setState(() {
      int cantActual = int.tryParse(_carrito[index].cantidadController.text) ?? 1;
      _carrito[index].cantidadController.text = (cantActual + 1).toString();
      _recalcularTotales();
    });
  }

  void _decrementarCantidad(int index) {
    setState(() {
      int cantActual = int.tryParse(_carrito[index].cantidadController.text) ?? 1;
      if (cantActual > 1) {
        _carrito[index].cantidadController.text = (cantActual - 1).toString();
      } else {
        _eliminarDelCarrito(index);
      }
      _recalcularTotales();
    });
  }

  void _eliminarDelCarrito(int index) {
    setState(() {
      _carrito[index].dispose();
      _carrito.removeAt(index);
      _recalcularTotales();
      if (_filaSeleccionada == index) {
        _filaSeleccionada = null;
      } else if (_filaSeleccionada != null && _filaSeleccionada! > index) {
        _filaSeleccionada = _filaSeleccionada! - 1;
      }
    });
  }

  void _recalcularTotales() {
    double subtotalTemp = 0.0;
    double ivaTemp = 0.0;
    for (var linea in _carrito) {
      final descuentoPorc = double.tryParse(linea.descuentoController.text) ?? 0.0;
      final precioOriginalLinea = linea.producto.precio * linea.cantidad;
      final montoDescuento = precioOriginalLinea * (descuentoPorc / 100);
      final precioTotalLinea = precioOriginalLinea - montoDescuento;
      if (linea.producto.llevaIva == true) {
        double precioBase = precioTotalLinea / 1.16;
        subtotalTemp += precioBase;
        ivaTemp += precioTotalLinea - precioBase;
      } else {
        subtotalTemp += precioTotalLinea;
      }
    }
    setState(() {
      _subtotal = subtotalTemp;
      _iva = ivaTemp;
      _total = subtotalTemp + ivaTemp;
    });
    _notificarCambioEnCarrito();
  }
  
  void _resetearPantalla() {
    setState(() {
      for (var linea in _carrito) {
        linea.dispose();
      }
      _carrito.clear();
      _recalcularTotales();
      _clienteController.text = 'Cliente Mostrador';
      _observacionesController.clear();
      _generarNuevoFolio();
      _filaSeleccionada = null;
    });
  }

  void _onCancelarVenta() {
    if (_carrito.isEmpty) return;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Confirmar Cancelación de Venta'),
              content: const Text('¿Estás seguro de que deseas limpiar todo el carrito?'),
              actions: [
                TextButton(child: const Text('NO'), onPressed: () => Navigator.of(context).pop()),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('SÍ, CANCELAR VENTA'),
                    onPressed: () {
                      _resetearPantalla();
                      Navigator.of(context).pop();
                    })
              ],
            ));
  }

  Future<void> _onCobrar() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El carrito está vacío'), backgroundColor: Colors.orange));
      return;
    }
    
    Map<String, dynamic>? datosReceta;
    final bool requiereReceta = _carrito.any((linea) => linea.producto.esControlado);

    if (requiereReceta) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 10), Text('Venta con Receta')]),
          content: const Text('Esta venta contiene productos controlados y requiere datos de receta médica para continuar.'),
          actions: [
            TextButton(onPressed: ()=>Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: ()=>Navigator.of(ctx).pop(true), child: const Text('Continuar'))
          ]
        ));
      
      if(continuar == null || !continuar) return;

      datosReceta = await _mostrarDialogoReceta();
      if (datosReceta == null) return;
    }
    
    final formaDePago = await _mostrarDialogoDePagoFinal();
    if (formaDePago != null) {
      _finalizarVenta(formaDePago, datosReceta: datosReceta);
    }
  }

  Future<Map<String, dynamic>?> _mostrarDialogoReceta() async {
    final formKeyReceta = GlobalKey<FormState>();
    Medico? medicoSeleccionado;
    final folioRecetaController = TextEditingController();

    return showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Datos de la Receta Médica'),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Nuevo Médico'),
                onPressed: () {
                  // Simplemente navegamos a la pantalla. El usuario tendrá que reabrir este diálogo.
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const AgregarMedicoScreen()));
                },
              )
            ],
          ),
          content: Form(
            key: formKeyReceta,
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('medicos').orderBy('apellidoPaterno').get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final medicos = snapshot.data!.docs.map((doc) => Medico.fromFirestore(doc)).toList();
                      return DropdownButtonFormField<Medico>(
                        hint: const Text('Seleccionar Médico'),
                        items: medicos.map((Medico medico) {
                          return DropdownMenuItem<Medico>(value: medico, child: Text('${medico.nombre} ${medico.apellidoPaterno}'));
                        }).toList(),
                        onChanged: (Medico? data) => medicoSeleccionado = data,
                        validator: (value) => value == null ? 'Campo requerido' : null,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        isExpanded: true,
                      );
                    }
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: folioRecetaController,
                    decoration: const InputDecoration(labelText: 'Folio de la Receta', border: OutlineInputBorder()),
                    validator: (value) => (value == null || value.isEmpty) ? 'Campo requerido' : null,
                  )
                ],
              ),
            ),
          ),
          actions: [
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(null)),
            FilledButton(
              child: const Text('Aceptar y Continuar'),
              onPressed: () {
                if (formKeyReceta.currentState!.validate()) {
                  Navigator.of(context).pop({
                    'medicoId': medicoSeleccionado!.id,
                    'medicoNombre': '${medicoSeleccionado!.nombre} ${medicoSeleccionado!.apellidoPaterno} ${medicoSeleccionado!.apellidoMaterno}',
                    'recetaFolio': folioRecetaController.text,
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _mostrarDialogoDePagoFinal() async {
    final montoRecibidoController = TextEditingController();
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        double cambio = 0.0;
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Finalizar Venta'),
              content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('TOTAL A PAGAR', style: Theme.of(context).textTheme.titleMedium),
                Text('\$${_total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(controller: montoRecibidoController, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto Recibido', prefixText: '\$ ', border: OutlineInputBorder()), onChanged: (value) {final recibido = double.tryParse(value) ?? 0.0; setStateInDialog(() {cambio = recibido - _total;});}),
                const SizedBox(height: 16),
                Text('Cambio a devolver:', style: Theme.of(context).textTheme.titleMedium),
                Text('\$${cambio < 0 ? '0.00' : cambio.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.green.shade700))
              ])),
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding: const EdgeInsets.all(16),
              actions: <Widget>[
                TextButton(child: const Text('CANCELAR'), onPressed: () => Navigator.of(context).pop(null)),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(icon: const Icon(Icons.credit_card), label: const Text('TARJETA'), style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () => Navigator.of(context).pop('Tarjeta'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(icon: const Icon(Icons.money), label: const Text('EFECTIVO'), style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () => Navigator.of(context).pop('Efectivo'))),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _finalizarVenta(String formaDePago, {Map<String, dynamic>? datosReceta}) async {
    if (_carrito.isEmpty) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    final batch = FirebaseFirestore.instance.batch();
    final ventaRef = FirebaseFirestore.instance.collection('ventas').doc();
    final List<ItemVenta> itemsDeVenta = _carrito.map((linea) {
      final descuentoPorc = double.tryParse(linea.descuentoController.text) ?? 0.0;
      final importe = (linea.producto.precio * linea.cantidad) * (1 - descuentoPorc / 100);
      return ItemVenta(productoId: linea.producto.id, productoNombre: linea.producto.nombre, cantidad: linea.cantidad, precioVenta: linea.producto.precio, loteVendido: linea.loteSeleccionado.loteId, descuento: descuentoPorc, importe: importe);
    }).toList();
    final nuevaVenta = Venta(
        id: ventaRef.id, folio: _folioVenta, fecha: DateTime.now(), empleadoNombre: 'Vendedor Principal', clienteNombre: _clienteController.text.trim(),
        subtotal: _subtotal, iva: _iva, total: _total, formaDePago: formaDePago, estado: 'Completada',
        observaciones: _observacionesController.text.trim(), items: itemsDeVenta,
        medicoId: datosReceta?['medicoId'], medicoNombre: datosReceta?['medicoNombre'], recetaFolio: datosReceta?['recetaFolio']);
    batch.set(ventaRef, nuevaVenta.toMap());
    for (var linea in _carrito) {
      final productoRef = FirebaseFirestore.instance.collection('productos').doc(linea.producto.id);
      batch.update(productoRef, {'stockTotal': FieldValue.increment(-linea.cantidad)});
      if (linea.producto.requiereControlLote) {
        final lotesActualizados = List<Map<String, dynamic>>.from(linea.producto.lotes.map((l) => l.toMap()));
        final indiceLote = lotesActualizados.indexWhere((l) => l['loteId'] == linea.loteSeleccionado.loteId);
        if (indiceLote != -1) {
          lotesActualizados[indiceLote]['stockEnLote'] = (lotesActualizados[indiceLote]['stockEnLote'] as int) - linea.cantidad;
          batch.update(productoRef, {'lotes': lotesActualizados});
        }
      }
    }
    try {
      await batch.commit();
      if(mounted) Navigator.of(context).pop(); 
      _resetearPantalla();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta guardada con éxito'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar la venta: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _onBorrarSeleccionado() {
    if (_filaSeleccionada != null && _filaSeleccionada! < _carrito.length) {
      _eliminarDelCarrito(_filaSeleccionada!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, seleccione un producto de la lista para borrar.'), backgroundColor: Colors.orange));
    }
  }

  void _onCambiarCantidad() {
    if (_filaSeleccionada != null && _filaSeleccionada! < _carrito.length) {
      _mostrarDialogoCantidad(_filaSeleccionada!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, seleccione un producto para cambiar la cantidad.'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _mostrarDialogoCantidad(int index) async {
    final linea = _carrito[index];
    final cantidadController = TextEditingController(text: linea.cantidadController.text);
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Cambiar Cantidad de\n${linea.producto.nombre}', style: const TextStyle(fontSize: 16)),
          content: TextField(controller: cantidadController, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nueva Cantidad')),
          actions: [
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
            FilledButton(
              child: const Text('Aceptar'),
              onPressed: () {
                setState(() { linea.cantidadController.text = cantidadController.text; _recalcularTotales(); });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _abrirBuscadorDeProductos() async {
    final Producto? productoSeleccionado = await showSearch<Producto?>(context: context, delegate: ProductSearchDelegate(catalogo: _catalogoCompleto));
    if (productoSeleccionado != null) { _agregarProductoAlCarrito(productoSeleccionado.codigoBarras); }
    _codigoFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          _buildInfoVenta(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: _codigoController, focusNode: _codigoFocusNode, autofocus: true, decoration: const InputDecoration(hintText: 'Escanear o digitar código y presionar Enter...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code_scanner)), onSubmitted: (value) => _agregarProductoAlCarrito(value))),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.search), iconSize: 32, tooltip: 'Buscar producto por nombre', onPressed: () => _abrirBuscadorDeProductos()),
            ],
          ),
          const SizedBox(height: 8),
          _buildTableHeader(),
          Expanded(
            child: _carrito.isEmpty
                ? const Center(child: Text('El carrito está vacío', style: TextStyle(fontSize: 18, color: Colors.grey)))
                : ListView.builder(
                    itemCount: _carrito.length,
                    itemBuilder: (context, index) { return _buildTableRow(_carrito[index], index); },
                  ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const boldStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(color: Colors.grey.shade200, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(children: [
        const Expanded(flex: 3, child: Text('Cant.', style: boldStyle, textAlign: TextAlign.center)),
        const Expanded(flex: 5, child: Text('Descripción', style: boldStyle)),
        const Expanded(flex: 3, child: Text('Código', style: boldStyle)),
        const Expanded(flex: 4, child: Text('Sustancia', style: boldStyle)),
        const Expanded(flex: 2, child: Text('Lote', style: boldStyle)),
        const Expanded(flex: 2, child: Text('Cad.', style: boldStyle)),
        const Expanded(flex: 2, child: Text('Disp.', style: boldStyle, textAlign: TextAlign.center)),
        const Expanded(flex: 3, child: Text('Precio', style: boldStyle, textAlign: TextAlign.right)),
        const Expanded(flex: 3, child: Text('Desc. %', style: boldStyle, textAlign: TextAlign.center)),
        const Expanded(flex: 3, child: Text('Importe', style: boldStyle, textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _buildTableRow(LineaVenta linea, int index) {
    final producto = linea.producto; final lote = linea.loteSeleccionado;
    final descuentoPorc = double.tryParse(linea.descuentoController.text) ?? 0.0;
    final importe = (producto.precio * linea.cantidad) * (1 - descuentoPorc / 100);
    final stockDisponible = lote.stockEnLote - linea.cantidad;
    Color stockColor = producto.stockTotal > producto.stockMinimo ? Colors.black : Colors.red.shade700;
    
    return Dismissible(
      key: UniqueKey(),
      onDismissed: (direction) {
        _eliminarDelCarrito(index);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${linea.producto.nombre} eliminado'), backgroundColor: Colors.red));
      },
      background: Container(color: Colors.red, alignment: Alignment.centerLeft, child: const Padding(padding: EdgeInsets.all(16.0), child: Icon(Icons.delete, color: Colors.white))),
      child: Material(
        color: _filaSeleccionada == index ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _filaSeleccionada = index),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: () => _decrementarCantidad(index)),
                  SizedBox(width: 40, child: TextField(controller: linea.cantidadController, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: stockColor), keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none), onChanged: (v) => _recalcularTotales())),
                  IconButton(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline, size: 18), onPressed: () => _incrementarCantidad(index)),
                ])),
                Expanded(flex: 5, child: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text(producto.codigoBarras, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                Expanded(flex: 4, child: Text(producto.sustanciaActiva, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                Expanded(flex: 2, child: Text(lote.loteId)),
                Expanded(flex: 2, child: Text(DateFormat('MM/yy').format(lote.fechaCaducidad))),
                Expanded(flex: 2, child: Text(stockDisponible.toString(), textAlign: TextAlign.center, style: TextStyle(color: stockDisponible >= 0 ? Colors.blueGrey : Colors.red, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('\$${producto.precio.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                Expanded(flex: 3, child: SizedBox(height: 35, child: TextField(controller: linea.descuentoController, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: '%', border: InputBorder.none), onChanged: (v) => _recalcularTotales()))),
                Expanded(flex: 3, child: Text('\$${importe.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.right)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Card(margin: const EdgeInsets.only(top: 8.0), elevation: 4, child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 20, 8), child: Row(
      children: [
        TextButton.icon(icon: const Icon(Icons.edit_note), label: const Text('Cantidad'), onPressed: _onCambiarCantidad),
        const SizedBox(width: 16),
        TextButton.icon(icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text('Borrar Prod.'), onPressed: _onBorrarSeleccionado),
        const Spacer(),
        SizedBox(width: 200, child: TextField(controller: _observacionesController, decoration: const InputDecoration(labelText: 'Observaciones'))),
        const SizedBox(width: 24),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [const Text('Subtotal:'), const SizedBox(width: 10), SizedBox(width: 120, child: Text('\$${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16), textAlign: TextAlign.right))]),
          Row(children: [const Text('IVA Desglosado:'), const SizedBox(width: 10), SizedBox(width: 120, child: Text('\$${_iva.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16), textAlign: TextAlign.right))]),
          const Divider(),
          Row(children: [const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)), const SizedBox(width: 10), SizedBox(width: 120, child: Text('\$${_total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor), textAlign: TextAlign.right))]),
        ]),
        const SizedBox(width: 24),
        TextButton.icon(onPressed: _onCancelarVenta, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancelar Venta'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
        const SizedBox(width: 10),
        SizedBox(height: 80, width: 180, child: ElevatedButton.icon(icon: const Icon(Icons.monetization_on, size: 28), label: const Text('COBRAR'), onPressed: _onCobrar, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
      ],
    )));
  }

  Widget _buildInfoVenta() {
    return Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [
      Text('Folio: $_folioVenta', style: const TextStyle(fontWeight: FontWeight.bold)),
      const Spacer(),
      Text('Empleado: Vendedor Principal'),
      const Spacer(),
      Text(DateFormat('dd/MM/yyyy, hh:mm:ss a').format(DateTime.now())),
    ])));
  }
}