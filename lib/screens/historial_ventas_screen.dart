import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistorialVentasScreen extends StatefulWidget {
  const HistorialVentasScreen({super.key});

  @override
  State<HistorialVentasScreen> createState() => _HistorialVentasScreenState();
}

class _HistorialVentasScreenState extends State<HistorialVentasScreen> {
  final Stream<QuerySnapshot> _ventasStream = FirebaseFirestore.instance
      .collection('ventas')
      .orderBy('fecha', descending: true)
      .limit(100)
      .snapshots();

  Future<void> _cancelarVenta(String ventaId) async {
    final ventaRef = FirebaseFirestore.instance.collection('ventas').doc(ventaId);
    try {
      final ventaSnapshot = await ventaRef.get();
      if (!ventaSnapshot.exists) throw Exception("¡La venta no existe!");
      
      final ventaData = ventaSnapshot.data()! as Map<String, dynamic>;
      if (ventaData['estado'] == 'Cancelada') {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta venta ya fue cancelada.'), backgroundColor: Colors.orange));
        return;
      }
      
      final batch = FirebaseFirestore.instance.batch();
      batch.update(ventaRef, {'estado': 'Cancelada'});
      
      final List<dynamic> items = ventaData['items'];
      for (final item in items) {
        if (item['productoId'] != null && item['cantidad'] != null) {
          final productoRef = FirebaseFirestore.instance.collection('productos').doc(item['productoId']);
          batch.update(productoRef, {'stockTotal': FieldValue.increment(item['cantidad'])});
        }
      }
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta cancelada con éxito.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar la venta: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    // La pantalla devuelve solo el StreamBuilder con la lista.
    // MainLayout se encarga del título y el menú.
    return StreamBuilder<QuerySnapshot>(
      stream: _ventasStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Algo salió mal.'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No se han realizado ventas.'));
        
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data()! as Map<String, dynamic>;
            final fecha = (data['fecha'] as Timestamp).toDate();
            final bool isCancelada = data['estado'] == 'Cancelada';
            final Color colorEstado = isCancelada ? Colors.red : Colors.green;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: colorEstado, child: Icon(isCancelada ? Icons.cancel : Icons.check_circle, color: Colors.white)),
                title: Text(data['folio'] ?? 'Folio no disponible', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('dd/MM/yyyy, hh:mm a').format(fecha)),
                trailing: SizedBox(
                  width: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('\$${(data['total'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(data['estado'] ?? 'Completada', style: TextStyle(color: colorEstado, fontSize: 12)),
                      ]),
                      const SizedBox(width: 8),
                      if (!isCancelada)
                        IconButton(
                          icon: const Icon(Icons.cancel_presentation_sharp, color: Colors.red),
                          tooltip: 'Cancelar Venta',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Confirmar Cancelación'),
                                  content: Text('¿Estás seguro de que deseas cancelar la venta con folio "${data['folio']}"?'),
                                  actions: <Widget>[
                                    TextButton(child: const Text('NO'), onPressed: () => Navigator.of(context).pop()),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('SÍ, CANCELAR'),
                                      onPressed: () {
                                        _cancelarVenta(doc.id);
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
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}