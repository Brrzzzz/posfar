import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pos_farmacia_v2/screens/agregar_medico_screen.dart';
import 'package:pos_farmacia_v2/screens/agregar_producto_screen.dart';
import 'package:pos_farmacia_v2/screens/caja_screen.dart';
import 'package:pos_farmacia_v2/screens/dashboard_screen.dart';
import 'package:pos_farmacia_v2/screens/gestion_medicos_screen.dart';
import 'package:pos_farmacia_v2/screens/gestion_productos_screen.dart';
import 'package:pos_farmacia_v2/screens/gestion_recetas_screen.dart';
import 'package:pos_farmacia_v2/screens/historial_ventas_screen.dart';
import 'package:pos_farmacia_v2/screens/ingresar_compra_screen.dart';
import 'package:pos_farmacia_v2/screens/pos_screen.dart';
import 'package:pos_farmacia_v2/screens/reporte_caducidades_screen.dart';
import 'package:pos_farmacia_v2/screens/reporte_inventario_screen.dart';
import 'package:pos_farmacia_v2/screens/verificador_precios_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WindowListener {
  int _selectedIndex = 0;
  
  final GlobalKey<DashboardScreenState> _dashboardScreenKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<PosScreenState> _posScreenKey = GlobalKey<PosScreenState>();
  final GlobalKey<CajaScreenState> _cajaScreenKey = GlobalKey<CajaScreenState>();

  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Lista de pantallas en el orden correcto y completo
    _screens = [
      DashboardScreen(key: _dashboardScreenKey),      // 0
      PosScreen(key: _posScreenKey),                  // 1
      const IngresarCompraScreen(),                  // 2
      const GestionProductosScreen(),                  // 3
      const GestionMedicosScreen(),                    // 4
      const HistorialVentasScreen(),                 // 5
      const GestionRecetasScreen(),                  // 6
      CajaScreen(key: _cajaScreenKey),               // 7
      const ReporteInventarioScreen(),                 // 8
      const ReporteCaducidadesScreen(),              // 9
      const VerificadorPreciosScreen(),              // 10
    ];
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    _mostrarDialogoDeSalida(context);
  }

  // Lista de títulos sincronizada con la lista de pantallas
  static const List<String> _screenTitles = [
    'Dashboard Principal', 'Punto de Venta', 'Ingresar Compra',
    'Gestión de Productos', 'Gestión de Médicos', 'Historial de Ventas',
    'Gestión de Recetas', 'Corte de Caja', 'Reporte de Inventario',
    'Reporte de Caducidades', 'Verificador de Precios',
  ];

  void _onItemTapped(int index) {
    // El índice 11 es el botón de Salir
    if (index == 11) { 
      _mostrarDialogoDeSalida(context);
      return;
    }

    // Bloqueo del POS (índice 1)
    if (_selectedIndex == 1 && (_posScreenKey.currentState?.isCartNotEmpty ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Finalice o cancele la venta actual para poder salir.'), backgroundColor: Colors.orange));
      return;
    }
    
    // Refresco de pantallas con los índices correctos
    if (index == 0) { _dashboardScreenKey.currentState?.cargarDatosDashboard(); }
    if (index == 7) { _cajaScreenKey.currentState?.calcularCorteDeCaja(); }
    
    setState(() { _selectedIndex = index; });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          extended: true,
          leading: const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Icon(Icons.local_pharmacy, size: 40, color: Colors.deepPurple)),
          // Lista completa y ordenada de botones
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
            NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('Vender')),
            NavigationRailDestination(icon: Icon(Icons.add_shopping_cart), label: Text('Compras')),
            NavigationRailDestination(icon: Icon(Icons.inventory), label: Text('Productos')),
            NavigationRailDestination(icon: Icon(Icons.medical_services), label: Text('Médicos')),
            NavigationRailDestination(icon: Icon(Icons.history), label: Text('Historial')),
            NavigationRailDestination(icon: Icon(Icons.receipt_long), label: Text('Recetas')),
            NavigationRailDestination(icon: Icon(Icons.calculate), label: Text('Caja')),
            NavigationRailDestination(icon: Icon(Icons.assessment), label: Text('Inventario')),
            NavigationRailDestination(icon: Icon(Icons.warning), label: Text('Caducidades')),
            NavigationRailDestination(icon: Icon(Icons.qr_code_scanner), label: Text('Verificador')),
            NavigationRailDestination(icon: Icon(Icons.exit_to_app), label: Text('Salir')),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: Scaffold(
            appBar: AppBar(title: Text(_screenTitles[_selectedIndex])),
            body: IndexedStack(index: _selectedIndex, children: _screens),
            floatingActionButton: _buildFloatingActionButton(),
          ),
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    // Gestión de Productos ahora está en el índice 3
    if (_selectedIndex == 3) { 
      return FloatingActionButton(
        heroTag: 'fab_productos',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AgregarProductoScreen())),
        tooltip: 'Añadir Nuevo Producto',
        child: const Icon(Icons.add),
      );
    }
    // Gestión de Médicos ahora está en el índice 4
    if (_selectedIndex == 4) { 
      return FloatingActionButton(
        heroTag: 'fab_medicos',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AgregarMedicoScreen())),
        tooltip: 'Añadir Nuevo Médico',
        child: const Icon(Icons.add),
      );
    }
    return null;
  }
}

void _mostrarDialogoDeSalida(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirmar Salida'),
        content: const Text('¿Estás seguro de que deseas cerrar la aplicación?'),
        actions: <Widget>[
          TextButton(child: const Text('No'), onPressed: () => Navigator.of(context).pop()),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, Salir'),
            onPressed: () async { await windowManager.destroy(); },
          ),
        ],
      );
    },
  );
}