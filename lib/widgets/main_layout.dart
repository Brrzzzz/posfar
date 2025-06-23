import 'package:flutter/material.dart';
import 'package:pos_farmacia_v2/screens/agregar_producto_screen.dart';
import 'package:pos_farmacia_v2/screens/dashboard_screen.dart';
import 'package:pos_farmacia_v2/screens/gestion_productos_screen.dart';
import 'package:pos_farmacia_v2/screens/historial_ventas_screen.dart';
import 'package:pos_farmacia_v2/screens/ingresar_compra_screen.dart';
import 'package:pos_farmacia_v2/screens/pos_screen.dart';
import 'package:pos_farmacia_v2/screens/reporte_caducidades_screen.dart';
import 'package:pos_farmacia_v2/screens/reporte_inventario_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  // Creamos la lista de pantallas una sola vez
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      IngresarCompraScreen(), // Pantalla de Compras
      GestionProductosScreen(),
      PosScreen(onCartStateChanged: (isDirty) {
        // La lógica de bloqueo del menú va aquí, si la necesitamos en el futuro
      }),
      HistorialVentasScreen(),
      ReporteInventarioScreen(),
      ReporteCaducidadesScreen(),
    ];
  }

  // Lista de títulos correspondiente a cada pantalla
  static const List<String> _screenTitles = [
    'Dashboard Principal',
    'Ingresar Compra',
    'Gestión de Productos',
    'Punto de Venta',
    'Historial de Ventas',
    'Reporte de Inventario',
    'Reporte de Caducidades',
  ];

  @override
  Widget build(BuildContext context) {
    // Usamos un Scaffold como base para tener una estructura de app
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      // El cuerpo es la fila que divide la pantalla
      body: Row(
        children: [
          // Menú de navegación a la izquierda
          NavigationRail(
            selectedIndex: _selectedIndex,
            extended: true,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Icon(Icons.local_pharmacy, size: 40, color: Colors.deepPurple),
            ),
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.add_shopping_cart), label: Text('Compras')),
              NavigationRailDestination(icon: Icon(Icons.inventory), label: Text('Productos')),
              NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('Vender')),
              NavigationRailDestination(icon: Icon(Icons.history), label: Text('Historial')),
              NavigationRailDestination(icon: Icon(Icons.assessment), label: Text('Inventario')),
              NavigationRailDestination(icon: Icon(Icons.warning), label: Text('Caducidades')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Contenido principal a la derecha
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }
}