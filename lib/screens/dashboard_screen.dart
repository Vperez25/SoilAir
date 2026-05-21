import 'package:flutter/material.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/widgets/sensor_card.dart';
import 'package:soilair/widgets/base_scaffold.dart';
import 'package:soilair/widgets/side_menu.dart';

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

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    setState(() => loading = true);
    final dbInstance = await db.database;

    // --------- Datos ambientales ---------
    final amb = await dbInstance.rawQuery(
        'SELECT * FROM sensores_ambientales ORDER BY timestamp DESC LIMIT 1');
    if (amb.isNotEmpty) {
      ambiente = {
        'Temp. aire': '${amb[0]['temperatura']} °C',
        'Humedad aire': '${amb[0]['humedad']} %',
      };
    }

    // --------- Sensores primarios ---------
    final primariosRaw = await db.getSensoresConNombre();
    final primarios = <Map<String, dynamic>>[];

    for (var s in primariosRaw) {
      final id = s['id'];
      final cultivoId = s['cultivo_asignado'];

      final medicion = await dbInstance.rawQuery(
          'SELECT * FROM sensores_primarios WHERE id = ? ORDER BY timestamp DESC LIMIT 1',
          [id]);

      if (medicion.isNotEmpty && cultivoId != null) {
        final cultivo = (await dbInstance
                .query('cultivos', where: 'id = ?', whereArgs: [cultivoId]))
            .first;

        primarios.add({
          'id': id,
          'nombre': s['nombre'],
          'datos': medicion.first,
          'cultivo': cultivo,
        });
      }
    }
    sensoresPrimarios = primarios;

    // --------- Sensores secundarios ---------
    final secundariosRaw = await db.getSensoresSecundariosConPrimario();
    final secundarios = <Map<String, dynamic>>[];

    for (var s in secundariosRaw) {
      final secId = s['sec_id'];
      final primarioNombre = s['primario_nombre'];
      final primarioId = s['sensor_primario_id'];

      final medicion = await dbInstance.rawQuery(
          'SELECT * FROM sensores_secundarios WHERE id = ? ORDER BY timestamp DESC LIMIT 1',
          [secId]);

      if (medicion.isNotEmpty && primarioId != null) {
        final primario = await dbInstance
            .query('admin_sensores', where: 'id = ?', whereArgs: [primarioId]);
        if (primario.isNotEmpty) {
          final cultivoId = primario.first['cultivo_asignado'];
          if (cultivoId != null) {
            final cultivo = (await dbInstance
                    .query('cultivos', where: 'id = ?', whereArgs: [cultivoId]))
                .first;

            final secData = {
              'nombre': primarioNombre != null
                  ? '$primarioNombre --- $secId'
                  : '$primarioId + $secId',
              'datos': medicion.first,
              'cultivo': cultivo,
              'primario_id': primarioId,
            };

            secundarios.add(secData);

            // Agrupar por primario
            secundariosPorPrimario
                .putIfAbsent(primarioId, () => [])
                .add(secData);
          }
        }
      }
    }
    sensoresSecundarios = secundarios;

    setState(() => loading = false);
  }

  List<Widget> buildSensorCards(
      Map<String, dynamic> sensorData, List<String> keys) {
    final datos = sensorData['datos'] as Map<String, dynamic>;
    final cultivo = sensorData['cultivo'] as Map<String, dynamic>;

    return keys.map((key) {
      final title = _getLabel(key);
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

  String _getLabel(String key) {
    switch (key) {
      case 'temperatura':
        return 'Temp. del suelo';
      case 'humedad':
        return 'Humedad suelo';
      case 'ph':
        return 'pH';
      case 'ec':
        return 'Conductividad';
      case 'n':
        return 'Nitrógeno';
      case 'p':
        return 'Fósforo';
      case 'k':
        return 'Potasio';
      case 'radiacion':
        return 'Radiación solar';
      default:
        return key;
    }
  }

  String _getUnit(String key) {
    switch (key) {
      case 'temperatura':
        return '°C';
      case 'humedad':
        return '%';
      case 'ph':
        return '';
      case 'ec':
        return 'mS/cm';
      case 'n':
      case 'p':
      case 'k':
        return 'mg/kg';
      case 'radiacion':
        return 'lux';
      default:
        return '~';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      // ← CREA UN CONTEXTO DEL NIVEL CORRECTO
      builder: (rootContext) {
        if (loading) {
          return BaseScaffold(
            title: 'Dashboard',
            drawer: MySideMenuWidget(
              scaffoldContext: rootContext, // ← AHORA SÍ ES VÁLIDO
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return DefaultTabController(
          length: 1,
          child: BaseScaffold(
            title: 'Dashboard',
            drawer: MySideMenuWidget(
              scaffoldContext: rootContext, // ← EL MISMO rootContext
            ),
            body: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: 'Última medición'),
                  ],
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Condiciones ambientales',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          Container(
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

                          // Sensores primarios + secundarios
                          ...sensoresPrimarios.map((primario) {
                            final secundarios =
                                secundariosPorPrimario[primario['id']] ?? [];

                            return ExpansionTile(
                              title: Text(
                                primario['nombre'],
                                style: Theme.of(context).textTheme.titleMedium,
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
                                  ]),
                                ),
                                const SizedBox(height: 10),
                                ...secundarios.map((sec) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(sec['nombre'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: buildSensorCards(
                                              sec,
                                              ['temperatura', 'humedad', 'ec'],
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
      },
    );
  }
}
