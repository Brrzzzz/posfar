import 'package:cloud_firestore/cloud_firestore.dart';

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

  // --- NUEVOS CAMPOS PARA RECETAS ---
  final String? medicoId;
  final String? medicoNombre;
  final String? recetaFolio;


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
    this.medicoId,
    this.medicoNombre,
    this.recetaFolio,
  });

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
      // --- AÑADIMOS LOS NUEVOS CAMPOS AL MAPA ---
      'medicoId': medicoId,
      'medicoNombre': medicoNombre,
      'recetaFolio': recetaFolio,
    };
  }
}

class ItemVenta {
  final String productoId;
  final String productoNombre;
  final int cantidad;
  final double precioVenta;
  final String loteVendido;
  final double descuento;
  final double importe;

  ItemVenta({
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioVenta,
    required this.loteVendido,
    required this.descuento,
    required this.importe,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId, 'productoNombre': productoNombre, 'cantidad': cantidad,
      'precioVenta': precioVenta, 'loteVendido': loteVendido, 'descuento': descuento, 'importe': importe,
    };
  }
}