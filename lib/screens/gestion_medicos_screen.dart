import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_farmacia_v2/models/medico.dart';
import 'package:pos_farmacia_v2/screens/agregar_medico_screen.dart';

class GestionMedicosScreen extends StatefulWidget {
  const GestionMedicosScreen({super.key});

  @override
  State<GestionMedicosScreen> createState() => _GestionMedicosScreenState();
}

class _GestionMedicosScreenState extends State<GestionMedicosScreen> {
  final Stream<QuerySnapshot> _medicosStream =
      FirebaseFirestore.instance.collection('medicos').orderBy('apellidoPaterno').snapshots();

  Future<void> _borrarMedico(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('medicos').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Médico eliminado con éxito'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar médico: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _navegarAEditarMedico(Medico medico) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgregarMedicoScreen(medico: medico)),
    ).then((_) {
      // Opcional: refrescar la lista si es necesario, aunque StreamBuilder lo hace automático
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catálogo de Médicos', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _medicosStream,
                  builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.hasError) return const Center(child: Text('Algo salió mal.'));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay médicos registrados.'));

                    return SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                        columns: const [
                          DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Nombre Completo', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Especialidad', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Cédula', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Teléfono', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: snapshot.data!.docs.map((DocumentSnapshot document) {
                          final medico = Medico.fromFirestore(document);
                          final nombreCompleto = '${medico.nombre} ${medico.apellidoPaterno} ${medico.apellidoMaterno}';
                          return DataRow(
                            cells: [
                              DataCell(Text(medico.codigo)),
                              DataCell(Text(nombreCompleto)),
                              DataCell(Text(medico.especialidad)),
                              DataCell(Text(medico.cedulaProfesional)),
                              DataCell(Text(medico.telefono)),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue.shade700),
                                    tooltip: 'Editar Médico',
                                    onPressed: () => _navegarAEditarMedico(medico),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Eliminar Médico',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Confirmar Eliminación'),
                                            content: Text('¿Estás seguro de que deseas eliminar al Dr./Dra. $nombreCompleto?'),
                                            actions: <Widget>[
                                              TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
                                              FilledButton(
                                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                child: const Text('Eliminar'),
                                                onPressed: () {
                                                  _borrarMedico(medico.id!);
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, //
        icon: const Icon(Icons.add),
        label: const Text('Añadir Médico'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AgregarMedicoScreen()),
          );
        },
      ),
    );
  }
}