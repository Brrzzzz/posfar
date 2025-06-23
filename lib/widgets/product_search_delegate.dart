import 'package:flutter/material.dart';
import 'package:pos_farmacia_v2/models/producto.dart';

// Definimos un tipo para el criterio de búsqueda
enum CriterioBusqueda { nombre, sustancia }

class ProductSearchDelegate extends SearchDelegate<Producto?> {
  final List<Producto> catalogo;
  // Guardamos el criterio de búsqueda actual
  CriterioBusqueda _criterio = CriterioBusqueda.nombre;

  ProductSearchDelegate({required this.catalogo});

  @override
  String get searchFieldLabel => 'Buscar producto...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [ IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '') ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  // Usamos buildResults para mostrar la misma interfaz que las sugerencias
  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Lógica de filtrado
    final List<Producto> sugerencias = catalogo.where((producto) {
      if (query.isEmpty) return false; // No mostramos nada si la búsqueda está vacía
      final input = query.toLowerCase();
      if (_criterio == CriterioBusqueda.nombre) {
        return producto.nombre.toLowerCase().contains(input);
      } else {
        return producto.sustanciaActiva.toLowerCase().contains(input);
      }
    }).toList();

    // La interfaz ahora tiene los filtros y la tabla
    return Column(
      children: [
        // --- NUEVO: BOTONES PARA FILTRAR ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SegmentedButton<CriterioBusqueda>(
            segments: const <ButtonSegment<CriterioBusqueda>>[
              ButtonSegment<CriterioBusqueda>(value: CriterioBusqueda.nombre, label: Text('Por Nombre Comercial')),
              ButtonSegment<CriterioBusqueda>(value: CriterioBusqueda.sustancia, label: Text('Por Sustancia Activa')),
            ],
            selected: {_criterio},
            onSelectionChanged: (Set<CriterioBusqueda> newSelection) {
              // setState no existe aquí, pero al llamar a showSuggestions se redibuja
              _criterio = newSelection.first;
              showSuggestions(context); // Forzamos a que la UI se actualice con el nuevo criterio
            },
          ),
        ),
        const Divider(),
        // --- NUEVO: CABECERA DE LA TABLA ---
        _buildTableHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: sugerencias.length,
            itemBuilder: (context, index) {
              final producto = sugerencias[index];
              // Devolvemos cada fila de la tabla
              return _buildTableRow(context, producto);
            },
          ),
        ),
      ],
    );
  }

  // --- WIDGET PARA LA CABECERA DE LA TABLA ---
  Widget _buildTableHeader() {
    const boldStyle = TextStyle(fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(color: Colors.grey.shade100, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: const Row(children: [
        Expanded(flex: 3, child: Text('Código', style: boldStyle)),
        Expanded(flex: 5, child: Text('Nombre Comercial', style: boldStyle)),
        Expanded(flex: 4, child: Text('Sustancia Activa', style: boldStyle)),
        Expanded(flex: 2, child: Text('Precio', style: boldStyle, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('Existencia', style: boldStyle, textAlign: TextAlign.center)),
      ]),
    );
  }
  
  // --- WIDGET PARA CADA FILA DE RESULTADO ---
  Widget _buildTableRow(BuildContext context, Producto producto) {
    return InkWell(
      onTap: () {
        close(context, producto); // Al hacer clic, cerramos y devolvemos el producto
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(producto.codigoBarras, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 5, child: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(flex: 4, child: Text(producto.sustanciaActiva, style: const TextStyle(color: Colors.grey))),
            Expanded(flex: 2, child: Text('\$${producto.precio.toStringAsFixed(2)}', textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text(producto.stockTotal.toString(), textAlign: TextAlign.center, style: TextStyle(color: producto.stockTotal > 0 ? Colors.green.shade800 : Colors.red, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}