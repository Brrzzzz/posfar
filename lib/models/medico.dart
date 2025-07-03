// Archivo actualizado: lib/models/medico.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Medico {
  String? id;
  final String codigo;
  final DateTime fechaAlta;
  final String nombre;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String especialidad;
  final String cedulaProfesional;
  final String direccion;
  final String pais;
  final String estado;
  final String ciudad;
  final String codigoPostal;
  final String rfc;
  final String telefono;
  final String email;

  // Constructor
  Medico({
    this.id,
    required this.codigo,
    required this.fechaAlta,
    required this.nombre,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.especialidad,
    required this.cedulaProfesional,
    required this.direccion,
    required this.pais,
    required this.estado,
    required this.ciudad,
    required this.codigoPostal,
    required this.rfc,
    required this.telefono,
    required this.email,
  });

  // --- ¡NUEVO! "Traductor" para leer desde Firebase ---
  factory Medico.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Medico(
      id: doc.id,
      codigo: data['codigo'] ?? '',
      fechaAlta: (data['fechaAlta'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nombre: data['nombre'] ?? '',
      apellidoPaterno: data['apellidoPaterno'] ?? '',
      apellidoMaterno: data['apellidoMaterno'] ?? '',
      especialidad: data['especialidad'] ?? '',
      cedulaProfesional: data['cedulaProfesional'] ?? '',
      direccion: data['direccion'] ?? '',
      pais: data['pais'] ?? '',
      estado: data['estado'] ?? '',
      ciudad: data['ciudad'] ?? '',
      codigoPostal: data['codigoPostal'] ?? '',
      rfc: data['rfc'] ?? '',
      telefono: data['telefono'] ?? '',
      email: data['email'] ?? '',
    );
  }


  // "Traductor" para guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'fechaAlta': Timestamp.fromDate(fechaAlta),
      'nombre': nombre,
      'apellidoPaterno': apellidoPaterno,
      'apellidoMaterno': apellidoMaterno,
      'especialidad': especialidad,
      'cedulaProfesional': cedulaProfesional,
      'direccion': direccion,
      'pais': pais,
      'estado': estado,
      'ciudad': ciudad,
      'codigoPostal': codigoPostal,
      'rfc': rfc,
      'telefono': telefono,
      'email': email,
    };
  }
}