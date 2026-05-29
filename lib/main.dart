import 'package:flutter/material.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/services/plants_reader.dart';
import 'package:soilair/screens/dashboard_screen.dart';
import 'package:soilair/screens/sensores_screen.dart';
import 'package:soilair/screens/suggestions_screen.dart';
import 'package:soilair/screens/historial_screen.dart';
import 'package:soilair/screens/configuracion_screen.dart';
import 'theme/app_light_theme.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<String>    appLanguage  = ValueNotifier('es');

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (_, mode, __) => ValueListenableBuilder<String>(
        valueListenable: appLanguage,
        builder: (_, __, ___) => MaterialApp(
          title: 'SoilAir',
          theme: AppLightTheme.themeData,
          darkTheme: AppLightTheme.darkThemeData,
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          home: const MainNavigation(),
        ),
      ),
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

  static const List<Widget> _screens = [
    DashboardScreen(),
    HistorialScreen(),
    SensoresScreen(),
    SugerenciasScreen(),
    ConfiguracionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard),  label: s.navDashboard),
          BottomNavigationBarItem(icon: const Icon(Icons.show_chart), label: s.navHistorial),
          BottomNavigationBarItem(icon: const Icon(Icons.sensors),    label: s.navSensores),
          BottomNavigationBarItem(icon: const Icon(Icons.lightbulb),  label: s.navSugerencias),
          BottomNavigationBarItem(icon: const Icon(Icons.settings),   label: s.navAjustes),
        ],
      ),
    );
  }
}
