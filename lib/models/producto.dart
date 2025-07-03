import 'package:cloud_firestore/cloud_firestore.dart';

class Producto {
  String id;
  String nombre;
  String sustanciaActiva;
  String codigoBarras;
  double costo;
  double precio;
  bool llevaIva;
  int stockTotal;
  int stockMinimo;
  bool requiereControlLote;
  DetallesAdicionales detallesAdicionales;
  List<Lote> lotes;
  
  // --- NUEVO CAMPO AÑADIDO ---
  bool esControlado;

  Producto({
    required this.id,
    required this.nombre,
    required this.sustanciaActiva,
    required this.codigoBarras,
    required this.costo,
    required this.precio,
    required this.llevaIva,
    required this.stockTotal,
    required this.stockMinimo,
    required this.requiereControlLote,
    required this.detallesAdicionales,
    required this.lotes,
    this.esControlado = false, // Valor por defecto
  });

  factory Producto.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Producto(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      sustanciaActiva: data['sustanciaActiva'] ?? '',
      codigoBarras: data['codigoBarras'] ?? '',
      costo: (data['costo'] as num?)?.toDouble() ?? 0.0,
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      llevaIva: data['llevaIva'] ?? false,
      stockTotal: data['stockTotal'] ?? 0,
      stockMinimo: data['stockMinimo'] ?? 0,
      requiereControlLote: data['requiereControlLote'] ?? true,
      detallesAdicionales: DetallesAdicionales.fromMap(data['detallesAdicionales'] ?? {}),
      lotes: (data['lotes'] as List<dynamic>?)
              ?.map((loteData) => Lote.fromMap(loteData))
              .toList() ??
          [],
      // Leemos el nuevo campo desde Firebase, si no existe, por defecto es 'false'
      esControlado: data['esControlado'] ?? false,
    );
  }
}

class DetallesAdicionales {
  String laboratorio;
  String tipoDeProducto;
  String proveedor;

  DetallesAdicionales({ required this.laboratorio, required this.tipoDeProducto, required this.proveedor });

  factory DetallesAdicionales.fromMap(Map<String, dynamic> map) {
    return DetallesAdicionales(
      laboratorio: map['laboratorio'] ?? '',
      tipoDeProducto: map['tipoDeProducto'] ?? '',
      proveedor: map['proveedor'] ?? '',
    );
  }
  
  Map<String, dynamic> toMap() => {
    'laboratorio': laboratorio,
    'tipoDeProducto': tipoDeProducto,
    'proveedor': proveedor,
  };
}

class Lote {
  String loteId;
  int stockEnLote;
  DateTime fechaCaducidad;
  
  Lote({ required this.loteId, required this.stockEnLote, required this.fechaCaducidad });

  factory Lote.fromMap(Map<String, dynamic> map) {
    return Lote(
      loteId: map['loteId'] ?? '',
      stockEnLote: map['stockEnLote'] ?? 0,
      fechaCaducidad: (map['fechaCaducidad'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  Map<String, dynamic> toMap() => {
    'loteId': loteId,
    'stockEnLote': stockEnLote,
    'fechaCaducidad': Timestamp.fromDate(fechaCaducidad),
  };
}