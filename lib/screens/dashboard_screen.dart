import 'package:flutter/material.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/main.dart';
import 'package:soilair/services/data_events.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/theme/app_light_theme.dart';
import 'package:soilair/widgets/sensor_card.dart';
import 'package:soilair/widgets/base_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final db = DatabaseHelper();

  Map<String, String> ambiente = {};
  List<Map<String, dynamic>> sensoresPrimarios = [];
  bool loading = true;
  Map<String, String?> _nombresSensores = {};

  @override
  void initState() {
    super.initState();
    cargarDatos();
    DataEvents.instance.version.addListener(_recargar);
  }

  void _recargar() { if (mounted) cargarDatos(); }

  @override
  void dispose() {
    DataEvents.instance.version.removeListener(_recargar);
    super.dispose();
  }

  Future<void> cargarDatos() async {
    if (!mounted) return;
    setState(() => loading = true);
    final dbInstance = await db.database;
    final s = AppStrings.of(appLanguage.value);

    // --------- Datos ambientales ---------
    final amb = await dbInstance.rawQuery(
        'SELECT * FROM sensores_ambientales ORDER BY timestamp DESC LIMIT 1');
    if (amb.isNotEmpty) {
      ambiente = {
        s.tempAire:    '${amb[0]['temperatura']} °C',
        s.humedadAire: '${amb[0]['humedad']} %',
      };
    }

    // --------- Nombres configurados de sensores ---------
    _nombresSensores = await db.getNombresSensores();

    // --------- Sensores primarios — cultivo por sensor ---------
    final ids = await db.getTodosSensoresPrimarios();
    final primarios = <Map<String, dynamic>>[];

    for (var row in ids) {
      final id = row['id'] as String;
      final medicion = await dbInstance.rawQuery(
          'SELECT * FROM sensores_primarios WHERE id = ? ORDER BY timestamp DESC LIMIT 1',
          [id]);

      if (medicion.isNotEmpty) {
        final cultivoSensor = await db.getRangosCultivoAsignado(id);
        primarios.add({
          'id': id,
          'nombre': _nombresSensores[id] ?? _nombreSensor(id, s),
          'datos': medicion.first,
          'cultivo': cultivoSensor,
        });
      }
    }
    sensoresPrimarios = primarios;

    if (!mounted) return;
    setState(() => loading = false);
  }

  String _formatTiempo(int? ts, AppStrings s) {
    if (ts == null) return s.sinLecturas;
    final fecha = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) return s.haceUnMomento;
    if (diff.inMinutes < 60) return s.haceMins(diff.inMinutes);
    if (diff.inHours < 24) return s.haceHoras(diff.inHours);
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  bool _esDesconectado(Map<String, dynamic> datos) {
    final ts = datos['timestamp'] as int?;
    if (ts == null) return true;
    return DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts * 1000)).inHours >= 24;
  }

  String _nombreSensor(String id, AppStrings s) {
    if (id.startsWith('p')) {
      final n = id.substring(1);
      return n == '1' ? s.sensorPrincipal : s.sensorN(int.tryParse(n) ?? 0);
    }
    return id;
  }

  List<Widget> buildSensorCards(
      Map<String, dynamic> sensorData, List<String> keys, AppStrings s,
      {bool desconectado = false}) {
    final datos = sensorData['datos'] as Map<String, dynamic>;
    final cultivo = desconectado ? null : sensorData['cultivo'] as Map<String, dynamic>?;

    return keys.map((key) {
      final title = _getLabel(key, s);
      final unit = _getUnit(key);
      final value = datos[key]?.toString() ?? '—';
      final double? val = double.tryParse(value);
      return SensorCard(
        title: title,
        value: val != null ? val.toStringAsFixed(2) : '—',
        unit: unit,
        paramKey: key,
        cultivo: cultivo,
      );
    }).toList();
  }

  String _getLabel(String key, AppStrings s) {
    switch (key) {
      case 'temperatura': return s.tempSuelo;
      case 'humedad':     return s.humedadSuelo;
      case 'ph':          return 'pH';
      case 'ec':          return s.conductividad;
      case 'n':           return s.nitrogeno;
      case 'p':           return s.fosforo;
      case 'k':           return s.potasio;
      case 'radiacion':   return s.radiacionSolar;
      default:            return key;
    }
  }

  String _getUnit(String key) {
    switch (key) {
      case 'temperatura': return '°C';
      case 'humedad':     return '%';
      case 'ph':          return '';
      case 'ec':          return 'mS/cm';
      case 'n':
      case 'p':
      case 'k':           return 'mg/kg';
      case 'radiacion':   return 'lux';
      default:            return '~';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);

    if (loading) {
      return BaseScaffold(
        title: s.navDashboard,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (sensoresPrimarios.isEmpty) {
      return BaseScaffold(
        title: s.navDashboard,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppLightTheme.botonPrincipal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco,
                      size: 44, color: AppLightTheme.botonPrincipal),
                ),
                const SizedBox(height: 20),
                Text(s.bienvenidoTitulo,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(s.bienvenidoDesc,
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sensors,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 6),
                    Text(s.navSensores,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BaseScaffold(
      title: s.navDashboard,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (ambiente.isNotEmpty) ...[
            Text(s.condicionesAmbientales,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ambiente.entries.map((e) {
                  final parts = e.value.split(' ');
                  return SensorCard(
                    title: e.key,
                    value: parts[0],
                    unit: parts.length > 1 ? parts[1] : '',
                    color: Colors.blueGrey,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Sensores primarios
          ...sensoresPrimarios.map((primario) {
            final datos        = primario['datos'] as Map<String, dynamic>;
            final ts           = datos['timestamp'] as int?;
            final desconectado = _esDesconectado(datos);

            return ExpansionTile(
              initiallyExpanded: true,
              title: Text(
                primario['nombre'] as String,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                _formatTiempo(ts, s),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: buildSensorCards(
                      primario,
                      ['temperatura', 'humedad', 'ph', 'ec', 'radiacion', 'n', 'p', 'k'],
                      s,
                      desconectado: desconectado,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
