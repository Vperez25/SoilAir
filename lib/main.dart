import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/services/auto_sync_service.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/services/plants_reader.dart';
import 'package:soilair/services/tutorial_service.dart';
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

  final _keyDashboard   = GlobalKey();
  final _keyHistorial   = GlobalKey();
  final _keySensores    = GlobalKey();
  final _keySugerencias = GlobalKey();
  final _keyAjustes     = GlobalKey();

  bool _tutorialPendiente = false;
  bool _tutorialIniciado  = false;

  AutoSyncService? _autoSync;

  @override
  void initState() {
    super.initState();
    appLanguage.addListener(_rebuild);
    _verificarTutorial();
    _autoSync = AutoSyncService();
    _autoSync!.start();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _autoSync?.stop();
    appLanguage.removeListener(_rebuild);
    super.dispose();
  }

  Future<void> _verificarTutorial() async {
    final debe = await TutorialService.debeEjecutar(TutorialService.nav);
    if (debe && mounted) setState(() => _tutorialPendiente = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);

    return ShowCaseWidget(
      onFinish: () {
        TutorialService.marcarVisto(TutorialService.nav);
        if (mounted) setState(() => _selectedIndex = 2);
      },
      builder: (ctx) {
        if (_tutorialPendiente && !_tutorialIniciado) {
          _tutorialIniciado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ShowCaseWidget.of(ctx).startShowCase([
                _keyDashboard,
                _keyHistorial,
                _keySensores,
                _keySugerencias,
                _keyAjustes,
              ]);
            }
          });
        }

        final screens = [
          DashboardScreen(),
          HistorialScreen(),
          SensoresScreen(),
          SugerenciasScreen(),
          ConfiguracionScreen(),
        ];

        return Scaffold(
          body: screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (i) => setState(() => _selectedIndex = i),
            items: [
              BottomNavigationBarItem(
                icon: Showcase(
                  key: _keyDashboard,
                  title: s.tutorialNavDashboardTitulo,
                  description: s.tutorialNavDashboardDesc,
                  tooltipBackgroundColor: AppLightTheme.botonPrincipal,
                  textColor: Colors.white,
                  targetPadding: const EdgeInsets.all(24),
                  targetBorderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.dashboard),
                ),
                label: s.navDashboard,
              ),
              BottomNavigationBarItem(
                icon: Showcase(
                  key: _keyHistorial,
                  title: s.tutorialNavHistorialTitulo,
                  description: s.tutorialNavHistorialDesc,
                  tooltipBackgroundColor: AppLightTheme.botonPrincipal,
                  textColor: Colors.white,
                  targetPadding: const EdgeInsets.all(24),
                  targetBorderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.show_chart),
                ),
                label: s.navHistorial,
              ),
              BottomNavigationBarItem(
                icon: Showcase(
                  key: _keySensores,
                  title: s.tutorialNavSensoresTitulo,
                  description: s.tutorialNavSensoresDesc,
                  tooltipBackgroundColor: AppLightTheme.botonPrincipal,
                  textColor: Colors.white,
                  targetPadding: const EdgeInsets.all(24),
                  targetBorderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.sensors),
                ),
                label: s.navSensores,
              ),
              BottomNavigationBarItem(
                icon: Showcase(
                  key: _keySugerencias,
                  title: s.tutorialNavSugerenciasTitulo,
                  description: s.tutorialNavSugerenciasDesc,
                  tooltipBackgroundColor: AppLightTheme.botonPrincipal,
                  textColor: Colors.white,
                  targetPadding: const EdgeInsets.all(24),
                  targetBorderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.lightbulb),
                ),
                label: s.navSugerencias,
              ),
              BottomNavigationBarItem(
                icon: Showcase(
                  key: _keyAjustes,
                  title: s.tutorialNavAjustesTitulo,
                  description: s.tutorialNavAjustesDesc,
                  tooltipBackgroundColor: AppLightTheme.botonPrincipal,
                  textColor: Colors.white,
                  targetPadding: const EdgeInsets.all(24),
                  targetBorderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.settings),
                ),
                label: s.navAjustes,
              ),
            ],
          ),
        );
      },
    );
  }
}
