import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_farmacia_v2/models/medico.dart';

class AgregarMedicoScreen extends StatefulWidget {
  final Medico? medico;
  const AgregarMedicoScreen({super.key, this.medico});

  @override
  State<AgregarMedicoScreen> createState() => _AgregarMedicoScreenState();
}

class _AgregarMedicoScreenState extends State<AgregarMedicoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _especialidadController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _direccionController = TextEditingController();
  final _paisController = TextEditingController();
  final _estadoController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _cpController = TextEditingController();
  final _rfcController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  bool get _isEditing => widget.medico != null;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final m = widget.medico!;
      _nombreController.text = m.nombre;
      _apellidoPaternoController.text = m.apellidoPaterno;
      _apellidoMaternoController.text = m.apellidoMaterno;
      _especialidadController.text = m.especialidad;
      _cedulaController.text = m.cedulaProfesional;
      _direccionController.text = m.direccion;
      _paisController.text = m.pais;
      _estadoController.text = m.estado;
      _ciudadController.text = m.ciudad;
      _cpController.text = m.codigoPostal;
      _rfcController.text = m.rfc;
      _telefonoController.text = m.telefono;
      _emailController.text = m.email;
    } else {
      _paisController.text = 'México';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _especialidadController.dispose();
    _cedulaController.dispose();
    _direccionController.dispose();
    _paisController.dispose();
    _estadoController.dispose();
    _ciudadController.dispose();
    _cpController.dispose();
    _rfcController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _guardarMedico() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; });

    final medicosCollection = FirebaseFirestore.instance.collection('medicos');
    
    try {
      if (_isEditing) {
        final medicoActualizado = {
          'nombre': _nombreController.text.trim(),
          'apellidoPaterno': _apellidoPaternoController.text.trim(),
          'apellidoMaterno': _apellidoMaternoController.text.trim(),
          'especialidad': _especialidadController.text.trim(),
          'cedulaProfesional': _cedulaController.text.trim(),
          'direccion': _direccionController.text.trim(),
          'pais': _paisController.text.trim(),
          'estado': _estadoController.text.trim(),
          'ciudad': _ciudadController.text.trim(),
          'codigoPostal': _cpController.text.trim(),
          'rfc': _rfcController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'email': _emailController.text.trim(),
        };
        await medicosCollection.doc(widget.medico!.id).update(medicoActualizado);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Médico actualizado con éxito.'), backgroundColor: Colors.green));
      
      } else {
        final querySnapshot = await medicosCollection.orderBy('codigo', descending: true).limit(1).get();
        int nuevoNumero = 1;
        if (querySnapshot.docs.isNotEmpty) {
          final ultimoCodigo = querySnapshot.docs.first.data()['codigo'] as String;
          final ultimoNumero = int.tryParse(ultimoCodigo.split('-').last) ?? 0;
          nuevoNumero = ultimoNumero + 1;
        }
        final nuevoCodigo = 'MED-${nuevoNumero.toString().padLeft(6, '0')}';
        
        final nuevoMedico = Medico(
          codigo: nuevoCodigo,
          fechaAlta: DateTime.now(),
          nombre: _nombreController.text.trim(),
          apellidoPaterno: _apellidoPaternoController.text.trim(),
          apellidoMaterno: _apellidoMaternoController.text.trim(),
          especialidad: _especialidadController.text.trim(),
          cedulaProfesional: _cedulaController.text.trim(),
          direccion: _direccionController.text.trim(),
          pais: _paisController.text.trim(),
          estado: _estadoController.text.trim(),
          ciudad: _ciudadController.text.trim(),
          codigoPostal: _cpController.text.trim(),
          rfc: _rfcController.text.trim(),
          telefono: _telefonoController.text.trim(),
          email: _emailController.text.trim(),
        );
        await medicosCollection.add(nuevoMedico.toMap());
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Médico guardado con éxito. Código: $nuevoCodigo'), backgroundColor: Colors.green));
      }

      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Médico (${widget.medico!.codigo})' : 'Registrar Nuevo Médico'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Información Personal y Profesional', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: TextFormField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre(s)', prefixIcon: Icon(Icons.person_outline)))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _apellidoPaternoController, decoration: const InputDecoration(labelText: 'Apellido Paterno'))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _apellidoMaternoController, decoration: const InputDecoration(labelText: 'Apellido Materno'))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: TextFormField(controller: _especialidadController, decoration: const InputDecoration(labelText: 'Especialidad', prefixIcon: Icon(Icons.star_outline)))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _cedulaController, decoration: const InputDecoration(labelText: 'Cédula Profesional', prefixIcon: Icon(Icons.badge_outlined)))),
                        ],
                      ),
                      const Divider(height: 40),
                      Text('Información de Contacto y Fiscal', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                       Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: TextFormField(controller: _telefonoController, decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone)),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress)),
                        ],
                      ),
                       const SizedBox(height: 16),
                      TextFormField(controller: _rfcController, decoration: const InputDecoration(labelText: 'RFC', prefixIcon: Icon(Icons.business_outlined))),
                      const Divider(height: 40),
                      Text('Dirección', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      TextFormField(controller: _direccionController, decoration: const InputDecoration(labelText: 'Dirección (Calle y Número)', prefixIcon: Icon(Icons.signpost_outlined))),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: TextFormField(controller: _paisController, decoration: const InputDecoration(labelText: 'País', prefixIcon: Icon(Icons.public_outlined)))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _estadoController, decoration: const InputDecoration(labelText: 'Estado', prefixIcon: Icon(Icons.map_outlined)))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: TextFormField(controller: _ciudadController, decoration: const InputDecoration(labelText: 'Ciudad / Municipio', prefixIcon: Icon(Icons.location_city_outlined)))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _cpController, decoration: const InputDecoration(labelText: 'Código Postal', prefixIcon: Icon(Icons.local_post_office_outlined)), keyboardType: TextInputType.number)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _isSaving ? Container() : const Icon(Icons.save),
                label: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('GUARDAR MÉDICO'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                onPressed: _isSaving ? null : _guardarMedico,
              ),
            ),
          ),
        ],
      ),
    );
  }
}