import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_farmacia_v2/models/producto.dart';
import 'package:pos_farmacia_v2/screens/agregar_producto_screen.dart';

class GestionProductosScreen extends StatefulWidget {
  const GestionProductosScreen({super.key});
  @override
  State<GestionProductosScreen> createState() => _GestionProductosScreenState();
}

class _GestionProductosScreenState extends State<GestionProductosScreen> {
  final Stream<QuerySnapshot> _productosStream =
      FirebaseFirestore.instance.collection('productos').orderBy('nombre').snapshots();

  Future<void> _borrarProducto(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('productos').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // La pantalla ahora solo devuelve el contenido (el StreamBuilder con la lista)
    return StreamBuilder<QuerySnapshot>(
      stream: _productosStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Algo salió mal.'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay productos. Añade uno con el botón "+".'));
        
        return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final document = snapshot.data!.docs[index];
              final producto = Producto.fromFirestore(document);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Precio: \$${producto.precio.toStringAsFixed(2)} - Stock: ${producto.stockTotal}'),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue.shade700),
                          tooltip: 'Editar',
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => AgregarProductoScreen(producto: producto),
                            ));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Confirmar Eliminación'),
                                  content: Text('¿Estás seguro de que deseas eliminar "${producto.nombre}"?'),
                                  actions: <Widget>[
                                    TextButton(child: const Text('CANCELAR'), onPressed: () => Navigator.of(context).pop()),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('ELIMINAR'),
                                      onPressed: () {
                                        _borrarProducto(document.id);
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
            });
      },
    );
  }
}