import 'package:cloud_firestore/cloud_firestore.dart';

// La clase LineaVenta define cómo manejamos los productos en el carrito de la pantalla del POS.
// La movemos aquí para tener todos los modelos relacionados con ventas en un solo lugar.
class LineaVenta {
  final dynamic producto; // Usamos dynamic para evitar dependencias circulares complejas por ahora
  int cantidad;
  LineaVenta({required this.producto, this.cantidad = 1});
}

// La clase Venta define la estructura del documento que se guarda en la colección "ventas"
class Venta {
  String? id;
  final String folio;
  final DateTime fecha;
  final String empleadoNombre;
  final String clienteNombre;
  final double subtotal;
  final double iva;
  final double total;
  final String formaDePago;
  final String estado;
  final String observaciones;
  final List<ItemVenta> items;

  Venta({
    this.id,
    required this.folio,
    required this.fecha,
    required this.empleadoNombre,
    required this.clienteNombre,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.formaDePago,
    required this.estado,
    required this.observaciones,
    required this.items,
  });

  // Convierte el objeto Venta a un formato que Firebase puede guardar
  Map<String, dynamic> toMap() {
    return {
      'folio': folio,
      'fecha': Timestamp.fromDate(fecha),
      'empleadoNombre': empleadoNombre,
      'clienteNombre': clienteNombre,
      'subtotal': subtotal,
      'iva': iva,
      'total': total,
      'formaDePago': formaDePago,
      'estado': estado,
      'observaciones': observaciones,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
}

// La clase ItemVenta define la estructura de cada producto dentro de una venta guardada
class ItemVenta {
  final String productoId;
  final String productoNombre;
  final int cantidad;
  final double precioVenta;
  final String loteVendido;

  ItemVenta({
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioVenta,
    required this.loteVendido, required double importe, required double descuento,
  });

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'productoNombre': productoNombre,
      'cantidad': cantidad,
      'precioVenta': precioVenta,
      'loteVendido': loteVendido,
    };
  }
}