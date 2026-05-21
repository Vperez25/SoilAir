import 'package:flutter/material.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/services/plants_reader.dart';
import 'package:soilair/screens/dashboard_screen.dart';
import 'package:soilair/screens/admin_sensors_screen.dart';
import 'package:soilair/screens/suggestions_screen.dart';
import 'package:soilair/screens/conexion_screen.dart';
import 'package:soilair/screens/historial_screen.dart';
import 'theme/app_light_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = DatabaseHelper();
  await db.database;

  final importer = PlantImporter();
  await importer.importarDesdeAssets();

  runApp(const SoilAirApp());
}

class SoilAirApp extends StatelessWidget {
  const SoilAirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoilAir',
      theme: AppLightTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HistorialScreen(),
    AdminSensorsScreen(),
    SugerenciasScreen(),
    ConexionScreen(),
  ];

  final List<BottomNavigationBarItem> _items = const [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard),  label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Historial'),
    BottomNavigationBarItem(icon: Icon(Icons.sensors),    label: 'Sensores'),
    BottomNavigationBarItem(icon: Icon(Icons.lightbulb),  label: 'Sugerencias'),
    BottomNavigationBarItem(icon: Icon(Icons.wifi),       label: 'Conectar'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: _items,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
