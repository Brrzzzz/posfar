import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_farmacia_v2/models/producto.dart';
import 'package:pos_farmacia_v2/screens/agregar_producto_screen.dart';

// Enum para definir los criterios de búsqueda de forma clara
enum CriterioBusquedaProductos { nombre, codigo, sustancia }

class GestionProductosScreen extends StatefulWidget {
  const GestionProductosScreen({super.key});
  @override
  State<GestionProductosScreen> createState() => _GestionProductosScreenState();
}

class _GestionProductosScreenState extends State<GestionProductosScreen> {
  final _searchController = TextEditingController();
  CriterioBusquedaProductos _criterio = CriterioBusquedaProductos.nombre;
  int? _sortColumnIndex;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    // Esto hace que la lista se filtre cada vez que el usuario escribe
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _borrarProducto(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('productos').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el producto: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _navegarAEditarProducto(Producto producto) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgregarProductoScreen(producto: producto)),
    );
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por ${_criterio.name}...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Producto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AgregarProductoScreen()));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<CriterioBusquedaProductos>(
            segments: const [
              ButtonSegment(value: CriterioBusquedaProductos.nombre, label: Text('Por Nombre'), icon: Icon(Icons.title)),
              ButtonSegment(value: CriterioBusquedaProductos.codigo, label: Text('Por Código'), icon: Icon(Icons.qr_code)),
              ButtonSegment(value: CriterioBusquedaProductos.sustancia, label: Text('Por Sustancia'), icon: Icon(Icons.science_outlined)),
            ],
            selected: {_criterio},
            onSelectionChanged: (newSelection) {
              setState(() {
                _criterio = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('productos').snapshots(),
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) return const Center(child: Text('Algo salió mal.'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  
                  final allProducts = snapshot.data?.docs ?? [];
                  var filteredProducts = allProducts.where((doc) {
                    if (_searchController.text.isEmpty) {
                      return true;
                    }
                    final data = doc.data() as Map<String, dynamic>;
                    final input = _searchController.text.toLowerCase();
                    switch (_criterio) {
                      case CriterioBusquedaProductos.nombre:
                        return (data['nombre'] as String? ?? '').toLowerCase().contains(input);
                      case CriterioBusquedaProductos.codigo:
                        return (data['codigoBarras'] as String? ?? '').toLowerCase().contains(input);
                      case CriterioBusquedaProductos.sustancia:
                        return (data['sustanciaActiva'] as String? ?? '').toLowerCase().contains(input);
                    }
                  }).toList();

                  if (_sortColumnIndex != null) {
                    filteredProducts.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      dynamic aValue, bValue;
                      switch (_sortColumnIndex) {
                        case 0: aValue = aData['codigoBarras'] ?? ''; bValue = bData['codigoBarras'] ?? ''; break;
                        case 1: aValue = aData['nombre'] ?? ''; bValue = bData['nombre'] ?? ''; break;
                        case 2: aValue = aData['sustanciaActiva'] ?? ''; bValue = bData['sustanciaActiva'] ?? ''; break;
                        case 3: aValue = aData['stockTotal'] ?? 0; bValue = bData['stockTotal'] ?? 0; break;
                        case 4: aValue = aData['precio'] ?? 0.0; bValue = bData['precio'] ?? 0.0; break;
                        default: return 0;
                      }
                      final comparison = Comparable.compare(aValue, bValue);
                      return _isAscending ? comparison : -comparison;
                    });
                  }

                  if (filteredProducts.isEmpty) return const Center(child: Text('No se encontraron productos.'));

                  return SingleChildScrollView(
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _isAscending,
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                      columns: [
                        DataColumn(label: const Text('Código'), onSort: (index, asc) => _onSort(index, asc)),
                        DataColumn(label: const Text('Nombre'), onSort: (index, asc) => _onSort(index, asc)),
                        DataColumn(label: const Text('Sustancia'), onSort: (index, asc) => _onSort(index, asc)),
                        DataColumn(label: const Text('Stock'), numeric: true, onSort: (index, asc) => _onSort(index, asc)),
                        DataColumn(label: const Text('Precio'), numeric: true, onSort: (index, asc) => _onSort(index, asc)),
                        const DataColumn(label: Text('Acciones')),
                      ],
                      rows: filteredProducts.map((DocumentSnapshot document) {
                        final producto = Producto.fromFirestore(document);
                        return DataRow(
                          cells: [
                            DataCell(Text(producto.codigoBarras)),
                            DataCell(Text(producto.nombre)),
                            DataCell(Text(producto.sustanciaActiva)),
                            DataCell(Text(producto.stockTotal.toString())),
                            DataCell(Text('\$${producto.precio.toStringAsFixed(2)}')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: Icon(Icons.edit, color: Colors.blue.shade700), onPressed: () => _navegarAEditarProducto(producto)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                                  showDialog(context: context, builder: (context) => AlertDialog(
                                    title: const Text('Confirmar Eliminación'),
                                    content: Text('¿Estás seguro de que deseas eliminar "${producto.nombre}"?'),
                                    actions: [
                                      TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
                                      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar'),
                                        onPressed: () { _borrarProducto(producto.id); Navigator.of(context).pop(); },
                                      ),
                                    ],
                                  ));
                                }),
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
    );
  }
}