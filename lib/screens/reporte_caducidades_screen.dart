import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pos_farmacia_v2/models/producto.dart';

class ReporteCaducidadesScreen extends StatefulWidget {
  const ReporteCaducidadesScreen({super.key});

  @override
  State<ReporteCaducidadesScreen> createState() =>
      _ReporteCaducidadesScreenState();
}

class LoteConProducto {
  final String nombreProducto;
  final Lote lote;
  LoteConProducto({required this.nombreProducto, required this.lote});
}

class _ReporteCaducidadesScreenState extends State<ReporteCaducidadesScreen> {
  late Future<List<Producto>> _futureProductos;
  int _filtroSeleccionado = 30;

  @override
  void initState() {
    super.initState();
    _futureProductos = _cargarInventario();
  }

  Future<List<Producto>> _cargarInventario() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('productos').get();
    return snapshot.docs.map((doc) => Producto.fromFirestore(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // La pantalla ya no devuelve un Scaffold, solo el contenido
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SegmentedButton<int>(
            style: SegmentedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 30, label: Text('1 Mes')),
              ButtonSegment<int>(value: 90, label: Text('3 Meses')),
              ButtonSegment<int>(value: 180, label: Text('6 Meses')),
              ButtonSegment<int>(value: -1, label: Text('Todos')),
            ],
            selected: {_filtroSeleccionado},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _filtroSeleccionado = newSelection.first;
              });
            },
          ),
        ),
        const Divider(),
        Expanded(
          child: FutureBuilder<List<Producto>>(
            future: _futureProductos,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No hay productos.'));
              
              final ahora = DateTime.now();
              final List<LoteConProducto> lotesPorCaducar = [];
              
              for (var producto in snapshot.data!) {
                if(producto.requiereControlLote) {
                  for (var lote in producto.lotes) {
                    bool incluirLote = false;
                    if (_filtroSeleccionado == -1) {
                      if (lote.fechaCaducidad.isAfter(ahora)) incluirLote = true;
                    } else {
                      final fechaLimite = ahora.add(Duration(days: _filtroSeleccionado));
                      if (lote.fechaCaducidad.isBefore(fechaLimite) && lote.fechaCaducidad.isAfter(ahora)) incluirLote = true;
                    }
                    if (incluirLote) {
                      lotesPorCaducar.add(LoteConProducto(nombreProducto: producto.nombre, lote: lote));
                    }
                  }
                }
              }
              
              lotesPorCaducar.sort((a, b) => a.lote.fechaCaducidad.compareTo(b.lote.fechaCaducidad));

              if (lotesPorCaducar.isEmpty) return Center(child: Text(_filtroSeleccionado == -1 ? 'No hay productos con caducidad futura.' : 'No hay productos por caducar en este periodo.'));
              
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Caducidad', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Días Restantes', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('Producto')),
                    DataColumn(label: Text('Lote')),
                    DataColumn(label: Text('Cantidad'), numeric: true),
                  ],
                  rows: lotesPorCaducar.map((item) {
                    final diasRestantes = item.lote.fechaCaducidad.difference(ahora).inDays;
                    return DataRow(
                      color: MaterialStateProperty.resolveWith<Color?>((states) {
                        if (diasRestantes < 30) return Colors.red.shade100;
                        if (diasRestantes < 90) return Colors.orange.shade100;
                        return null;
                      }),
                      cells: [
                        DataCell(Text(DateFormat('dd/MM/yyyy').format(item.lote.fechaCaducidad))),
                        DataCell(Text(diasRestantes.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(item.nombreProducto)),
                        DataCell(Text(item.lote.loteId)),
                        DataCell(Text(item.lote.stockEnLote.toString())),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}