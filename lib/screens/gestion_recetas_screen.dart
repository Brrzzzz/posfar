// Archivo: lib/screens/gestion_recetas_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GestionRecetasScreen extends StatefulWidget {
  const GestionRecetasScreen({super.key});

  @override
  State<GestionRecetasScreen> createState() => _GestionRecetasScreenState();
}

class _GestionRecetasScreenState extends State<GestionRecetasScreen> {
  // Este stream busca en la colección 'ventas' y filtra para traer solo
  // los documentos que tienen un folio de receta y los ordena por fecha.
  final Stream<QuerySnapshot> _recetasStream = FirebaseFirestore.instance
      .collection('ventas')
      .where('recetaFolio', isNotEqualTo: null)
      .orderBy('recetaFolio')
      .orderBy('fecha', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Historial de Recetas Surtidas', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: StreamBuilder<QuerySnapshot>(
                stream: _recetasStream,
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) {
                    // Si hay un error, es muy probable que sea por un índice faltante en Firestore.
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error al cargar los datos. Es muy probable que necesites crear un índice en Firestore.\n\nBusca en la "DEBUG CONSOLE" un enlace que empieza con "https://console.firebase.google.com/..." para crearlo automáticamente.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No se han registrado ventas con receta.'));
                  }

                  return SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                      columns: const [
                        DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Folio Venta', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Folio Receta', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Médico', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Productos Controlados', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: snapshot.data!.docs.map((DocumentSnapshot document) {
                        final data = document.data()! as Map<String, dynamic>;
                        final fecha = (data['fecha'] as Timestamp).toDate();
                        
                        // Extraemos los nombres de los productos vendidos en esta receta
                        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
                        final productosVendidos = items.map((item) => item['productoNombre'].toString()).join(', ');

                        return DataRow(
                          cells: [
                            DataCell(Text(DateFormat('dd/MM/yyyy').format(fecha))),
                            DataCell(Text(data['folio'] ?? '')),
                            DataCell(Text(data['recetaFolio'] ?? '')),
                            DataCell(Text(data['medicoNombre'] ?? '')),
                            DataCell(Text(productosVendidos)),
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
    );
  }
}