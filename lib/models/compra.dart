// Archivo: lib/models/compra.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Compra {
  String? id;
  final String proveedor;
  final String facturaNro;
  final DateTime fecha;
  final double totalCompra;
  final List<ItemCompra> items;

  Compra({
    this.id,
    required this.proveedor,
    required this.facturaNro,
    required this.fecha,
    required this.totalCompra,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'proveedor': proveedor,
      'facturaNro': facturaNro,
      'fecha': Timestamp.fromDate(fecha),
      'totalCompra': totalCompra,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
}

class ItemCompra {
  final String productoId;
  final String productoNombre;
  final int cantidad;
  final double costo; // El costo al que se compró

  ItemCompra({
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.costo,
  });

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'productoNombre': productoNombre,
      'cantidad': cantidad,
      'costo': costo,
    };
  }
}