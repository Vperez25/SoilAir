import 'package:flutter/material.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/main.dart';
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
  List<Map<String, dynamic>> sensoresSecundarios = [];
  Map<String, List<Map<String, dynamic>>> secundariosPorPrimario = {};
  bool loading = true;
  List<Map<String, dynamic>> _cultivos = [];
  Map<String, dynamic>? _configuracion;
  Map<String, String?> _nombresSensores = {};

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    setState(() => loading = true);
    secundariosPorPrimario = {};
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

    // --------- Cultivos y configuración ---------
    _cultivos = await db.getCultivos();
    final config = await db.getConfiguracion();
    _configuracion = config;
    Map<String, dynamic>? cultivoGlobal;
    if (config != null && config['cultivo_id'] != null) {
      cultivoGlobal = await db.getCultivoById(config['cultivo_id'] as int);
    }

    // --------- Sensores primarios (auto-detectados) ---------
    final ids = await db.getTodosSensoresPrimarios();
    final primarios = <Map<String, dynamic>>[];

    for (var row in ids) {
      final id = row['id'] as String;
      final medicion = await dbInstance.rawQuery(
          'SELECT * FROM sensores_primarios WHERE id = ? ORDER BY timestamp DESC LIMIT 1',
          [id]);

      if (medicion.isNotEmpty) {
        primarios.add({
          'id': id,
          'nombre': _nombresSensores[id] ?? _nombreSensor(id, s),
          'datos': medicion.first,
          'cultivo': cultivoGlobal,
        });
      }
    }
    sensoresPrimarios = primarios;

    // --------- Sensores secundarios (auto-detectados) ---------
    final secIds = await db.getTodosSensoresSecundarios();
    final secundarios = <Map<String, dynamic>>[];

    for (var row in secIds) {
      final secId = row['id'] as String;
      final primarioId =
          row['sensor_primario_id'] as String? ?? _deducirPrimario(secId);

      final medicion = await dbInstance.rawQuery(
          'SELECT * FROM sensores_secundarios WHERE id = ? ORDER BY timestamp DESC LIMIT 1',
          [secId]);

      if (medicion.isNotEmpty) {
        final secData = {
          'nombre': secId,
          'datos': medicion.first,
          'cultivo': cultivoGlobal,
          'primario_id': primarioId,
        };
        secundarios.add(secData);
        if (primarioId != null) {
          secundariosPorPrimario
              .putIfAbsent(primarioId, () => [])
              .add(secData);
        }
      }
    }
    sensoresSecundarios = secundarios;

    setState(() => loading = false);
  }

  String _cultivoNombre(AppStrings s) {
    if (_configuracion == null) return s.sinCultivo;
    final cultivoId = _configuracion!['cultivo_id'];
    final cultivoNombre = _configuracion!['cultivo_nombre'] as String?;
    if (cultivoId == null && cultivoNombre == null) return s.sinCultivo;
    if (cultivoId == null) return cultivoNombre!;
    final c = _cultivos.firstWhere(
        (c) => c['id'] == cultivoId, orElse: () => <String, dynamic>{});
    return c['nombre'] as String? ?? s.sinCultivo;
  }

  Future<void> _cambiarCultivo(AppStrings s) async {
    final cultivoActualId = _configuracion?['cultivo_id'] as int?;
    final sinCultivo = _configuracion == null ||
        (_configuracion!['cultivo_id'] == null &&
            _configuracion!['cultivo_nombre'] == null);
    final esOtro = _configuracion != null &&
        cultivoActualId == null &&
        _configuracion!['cultivo_nombre'] == 'Otro';

    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.seleccionarCultivo),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              final db2 = await db.database;
              await db2.delete('configuracion', where: 'id = ?', whereArgs: [1]);
              if (ctx.mounted) Navigator.pop(ctx);
              cargarDatos();
            },
            child: Row(children: [
              Icon(sinCultivo ? Icons.check_circle : Icons.circle_outlined,
                  color: sinCultivo
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  size: 18),
              const SizedBox(width: 10),
              Text(s.sinCultivo),
            ]),
          ),
          const Divider(height: 1),
          ..._cultivos.map((c) {
            final sel = c['id'] == cultivoActualId;
            return SimpleDialogOption(
              onPressed: () async {
                await db.setConfiguracion(
                    cultivoId: c['id'] as int, cultivoNombre: null);
                if (ctx.mounted) Navigator.pop(ctx);
                cargarDatos();
              },
              child: Row(children: [
                Icon(sel ? Icons.check_circle : Icons.circle_outlined,
                    color: sel
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                    size: 18),
                const SizedBox(width: 10),
                Text(c['nombre'] as String),
              ]),
            );
          }),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () async {
              await db.setConfiguracion(cultivoId: null, cultivoNombre: 'Otro');
              if (ctx.mounted) Navigator.pop(ctx);
              cargarDatos();
            },
            child: Row(children: [
              Icon(esOtro ? Icons.check_circle : Icons.circle_outlined,
                  color: esOtro
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  size: 18),
              const SizedBox(width: 10),
              Text(s.otro),
            ]),
          ),
        ],
      ),
    );
  }

  String _nombreSensor(String id, AppStrings s) {
    if (id.startsWith('p')) {
      final n = id.substring(1);
      return n == '1' ? s.sensorPrincipal : s.sensorN(int.tryParse(n) ?? 0);
    }
    return id;
  }

  String? _deducirPrimario(String secId) {
    if (!secId.startsWith('s')) return null;
    final n = int.tryParse(secId.substring(1));
    if (n == null) return null;
    return 'p${((n - 1) ~/ 2) + 1}';
  }

  List<Widget> buildSensorCards(
      Map<String, dynamic> sensorData, List<String> keys, AppStrings s) {
    final datos = sensorData['datos'] as Map<String, dynamic>;
    final cultivo = sensorData['cultivo'] as Map<String, dynamic>?;

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

    return DefaultTabController(
      length: 1,
      child: BaseScaffold(
        title: s.navDashboard,
        body: Column(
          children: [
            TabBar(
              tabs: [Tab(text: s.ultimaMedicion)],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              indicatorColor: Theme.of(context).primaryColor,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Tarjeta de cultivo ──────────
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.eco,
                              color: AppLightTheme.botonPrincipal),
                          title: Text(_cultivoNombre(s),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(s.cultivoMonitoreado,
                              style: const TextStyle(fontSize: 12)),
                          trailing: TextButton(
                            onPressed: () => _cambiarCultivo(s),
                            child: Text(s.cambiar),
                          ),
                        ),
                      ),
                      if (ambiente.isNotEmpty) ...[
                        Text(s.condicionesAmbientales,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: ambiente.entries.map((e) {
                              final parts = e.value.split(' ');
                              return SensorCard(
                                title: e.key,
                                value: parts[0],
                                unit:
                                    parts.length > 1 ? parts[1] : '',
                                color: Colors.blueGrey,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Sensores primarios + secundarios
                      ...sensoresPrimarios.map((primario) {
                        final secundarios =
                            secundariosPorPrimario[primario['id']] ??
                                [];
                        return ExpansionTile(
                          title: Text(
                            primario['nombre'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: buildSensorCards(primario, [
                                'temperatura',
                                'humedad',
                                'ph',
                                'ec',
                                'radiacion',
                                'n',
                                'p',
                                'k'
                              ], s),
                            ),
                            const SizedBox(height: 10),
                            ...secundarios.map((sec) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(sec['nombre'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 10),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: buildSensorCards(
                                          sec,
                                          ['temperatura', 'humedad', 'ec'],
                                          s,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
