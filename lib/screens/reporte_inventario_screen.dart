import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_farmacia_v2/models/producto.dart';

class ReporteInventarioScreen extends StatefulWidget {
  const ReporteInventarioScreen({super.key});

  @override
  State<ReporteInventarioScreen> createState() => _ReporteInventarioScreenState();
}

class _ReporteInventarioScreenState extends State<ReporteInventarioScreen> {
  late Future<List<Producto>> _futureProductos;

  @override
  void initState() {
    super.initState();
    _futureProductos = _cargarInventario();
  }

  Future<List<Producto>> _cargarInventario() async {
    final snapshot = await FirebaseFirestore.instance.collection('productos').orderBy('nombre').get();
    return snapshot.docs.map((doc) => Producto.fromFirestore(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // La pantalla ya no devuelve un Scaffold, solo el contenido que se mostrará
    return FutureBuilder<List<Producto>>(
      future: _futureProductos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar el inventario: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay productos en el inventario.'));
        }

        final productos = snapshot.data!;
        
        final int totalUnidades = productos.fold(0, (sum, item) => sum + item.stockTotal);
        final double valorTotalCosto = productos.fold(0, (sum, item) => sum + (item.costo * item.stockTotal));

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(10.0),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildResumen('Total de Unidades', totalUnidades.toString()),
                      _buildResumen('Valor Inventario (Costo)', '\$${valorTotalCosto.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Stock Actual'), numeric: true),
                      DataColumn(label: Text('Costo Unit.'), numeric: true),
                      DataColumn(label: Text('Valor Total'), numeric: true),
                    ],
                    rows: productos.map((producto) => DataRow(
                      cells: [
                        DataCell(Text(producto.nombre)),
                        DataCell(Text(producto.stockTotal.toString())),
                        DataCell(Text('\$${producto.costo.toStringAsFixed(2)}')),
                        DataCell(Text('\$${(producto.costo * producto.stockTotal).toStringAsFixed(2)}')),
                      ],
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResumen(String titulo, String valor) {
    return Column(
      children: [
        Text(titulo, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}