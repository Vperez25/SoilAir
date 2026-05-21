import 'package:flutter/material.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/widgets/base_scaffold.dart';
import 'package:soilair/widgets/side_menu.dart';

class AdminSensorsScreen extends StatefulWidget {
  const AdminSensorsScreen({super.key});

  @override
  State<AdminSensorsScreen> createState() => _AdminSensorsScreenState();
}

class _AdminSensorsScreenState extends State<AdminSensorsScreen> {
  final db = DatabaseHelper();

  List<Map<String, dynamic>> sensoresPrimarios = [];
  List<Map<String, dynamic>> sensoresSecundarios = [];
  List<Map<String, dynamic>> sensoresSinConfig = [];
  List<Map<String, dynamic>> cultivos = [];

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    sensoresPrimarios = await db.getSensoresConNombre();
    sensoresSecundarios = await db.getSensoresSecundariosConPrimario();
    sensoresSinConfig = await db.getSensoresSinConfig();
    cultivos = await db.getCultivos();
    setState(() {});
  }

  Future<void> mostrarDialogoConfigPrimario({
    required String id,
    String? nombreActual,
    int? cultivoActual,
  }) async {
    final TextEditingController nombreController =
        TextEditingController(text: nombreActual ?? '');
    String? cultivoSeleccionado = cultivoActual?.toString();
    List<Map<String, dynamic>> cultivosFiltrados = List.from(cultivos);
    final TextEditingController filtroController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Configurar sensor primario'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nombre del sensor
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 10),

                    // Filtro de cultivos
                    TextField(
                      controller: filtroController,
                      decoration:
                          const InputDecoration(labelText: 'Buscar cultivo'),
                      onChanged: (value) {
                        setStateDialog(() {
                          cultivosFiltrados = cultivos
                              .where((c) => c['nombre']
                                  .toString()
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Lista de cultivos filtrados

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: cultivosFiltrados.map((cultivo) {
                            return GestureDetector(
                              onTap: () {
                                setStateDialog(() {
                                  cultivoSeleccionado =
                                      cultivo['id'].toString();
                                });
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Transform.scale(
                                    scale:
                                        1, // Reduce el tamaño del Radio sin afectar el texto
                                    child: Radio<String>(
                                      value: cultivo['id'].toString(),
                                      groupValue: cultivoSeleccionado,
                                      onChanged: (value) {
                                        setStateDialog(() {
                                          cultivoSeleccionado = value;
                                        });
                                      },
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      cultivo['nombre'],
                                      style: const TextStyle(
                                          fontSize: 14), // letra igual
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text('Guardar'),
                  onPressed: () async {
                    await db.updateSensorConfig(
                      id: id,
                      nombre: nombreController.text.trim().isEmpty
                          ? null
                          : nombreController.text.trim(),
                      cultivoAsignado: int.tryParse(cultivoSeleccionado ?? ''),
                    );
                    Navigator.pop(context);
                    await cargarDatos();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> mostrarDialogoEnlaceSecundario(
      {required String id, required String? actualPrimario}) async {
    String? seleccionado = actualPrimario;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enlazar sensor secundario'),
          content: DropdownButtonFormField<String>(
            value: seleccionado,
            items: sensoresPrimarios.map((sensor) {
              return DropdownMenuItem(
                value: sensor['id'] as String,
                child: Text(sensor['nombre'] ?? sensor['id']),
              );
            }).toList(),
            onChanged: (value) => seleccionado = value,
            decoration: const InputDecoration(labelText: 'Sensor primario'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Guardar'),
              onPressed: () async {
                if (seleccionado != null) {
                  await db.updateSensorSecundarioConfig(
                    id: id,
                    sensorPrimarioId: seleccionado!,
                  );
                  Navigator.pop(context);
                  await cargarDatos();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> agregarSensorPrimario() async {
    if (sensoresSinConfig.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sensores sin configurar')),
      );
      return;
    }

    final sensor = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return SimpleDialog(
          title: const Text('Seleccionar sensor sin configurar'),
          children: sensoresSinConfig.map((s) {
            return SimpleDialogOption(
              child: Text(s['id']),
              onPressed: () => Navigator.pop(context, s),
            );
          }).toList(),
        );
      },
    );

    if (sensor != null) {
      await mostrarDialogoConfigPrimario(id: sensor['id']);
    }
  }

  Future<void> agregarSensorSecundario() async {
    final todosSecundarios =
        await db.database.then((db) => db.query('sensores_secundarios'));
    final sinEnlace =
        todosSecundarios.where((s) => s['sensor_primario_id'] == null).toList();

    if (sinEnlace.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay sensores secundarios sin enlazar')),
      );
      return;
    }

    final sensor = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return SimpleDialog(
          title: const Text('Seleccionar sensor secundario'),
          children: sinEnlace.map((s) {
            return SimpleDialogOption(
              child: Text(s['id'].toString()),
              onPressed: () => Navigator.pop(context, s),
            );
          }).toList(),
        );
      },
    );

    if (sensor != null) {
      await mostrarDialogoEnlaceSecundario(
          id: sensor['id'], actualPrimario: null);
    }
  }

  // Reemplaza todo el método build() por este nuevo
  @override
  Widget build(BuildContext context) {
    final hayPrimariosSinConfig = sensoresSinConfig.isNotEmpty;
    final haySecundariosSinEnlace =
        sensoresSecundarios.any((s) => s['sensor_primario_id'] == null);

    return BaseScaffold(
      title: 'Administrar Sensores',
      drawer: MySideMenuWidget(scaffoldContext: context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sensores Primarios:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                if (hayPrimariosSinConfig)
                  ElevatedButton.icon(
                    onPressed: () => agregarSensorPrimario(),
                    icon: const Icon(Icons.add, size: 18),
                    label:
                        const Text('Agregar', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
            ...sensoresPrimarios.map((sensor) {
              // Buscar el nombre del cultivo asignado
              String cultivoNombre = '';
              if (sensor['cultivo_asignado'] != null) {
                final cultivo = cultivos.firstWhere(
                  (c) => c['id'] == sensor['cultivo_asignado'],
                  orElse: () => {'nombre': 'Desconocido'},
                );
                cultivoNombre = cultivo['nombre'];
              }

              return ListTile(
                title: Text(
                  sensor['nombre'] ?? sensor['id'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, // ← aquí el nombre en negrita
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${sensor['id']}'),
                    if (cultivoNombre.isNotEmpty)
                      Text('Cultivo: $cultivoNombre'),
                  ],
                ),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                  onPressed: () => mostrarDialogoConfigPrimario(
                    id: sensor['id'] as String,
                    nombreActual: sensor['nombre'],
                    cultivoActual: sensor['cultivo_asignado'],
                  ),
                ),
              );
            }),

            if (hayPrimariosSinConfig) ...[
              const SizedBox(height: 8),
              const Text('Sin configurar:',
                  style: TextStyle(fontStyle: FontStyle.italic)),
              ...sensoresSinConfig.map((sensor) => ListTile(
                    title: Text(sensor['id']),
                    subtitle: const Text('Sensor sin nombre ni cultivo'),
                    onTap: () => mostrarDialogoConfigPrimario(id: sensor['id']),
                  )),
            ],

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sensores Secundarios:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                if (haySecundariosSinEnlace)
                  ElevatedButton.icon(
                    onPressed: () => agregarSensorSecundario(),
                    icon: const Icon(Icons.add, size: 18),
                    label:
                        const Text('Agregar', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
            // Mostrar solo sensores secundarios que tengan primario asignado
            ...sensoresSecundarios
                .where((s) => s['sensor_primario_id'] != null)
                .map((sensor) {
              final nombrePrimario = sensor['primario_nombre'] ??
                  sensor['sensor_primario_id'] ??
                  'No asignado';
              return ListTile(
                title: Text('$nombrePrimario'),
                subtitle: Text('ID: ${sensor['sec_id']}'),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                  onPressed: () => mostrarDialogoEnlaceSecundario(
                    id: sensor['sec_id'],
                    actualPrimario: sensor['sensor_primario_id'],
                  ),
                ),
              );
            }),
            if (haySecundariosSinEnlace) ...[
              const SizedBox(height: 8),
              const Text('Sin enlazar:',
                  style: TextStyle(fontStyle: FontStyle.italic)),
              ...sensoresSecundarios
                  .where((s) => s['sensor_primario_id'] == null)
                  .map((sensor) => ListTile(
                        title: Text(sensor['sec_id']),
                        subtitle: const Text('Sensor sin primario asignado'),
                        onTap: () => mostrarDialogoEnlaceSecundario(
                            id: sensor['sec_id'], actualPrimario: null),
                      )),
            ],
          ],
        ),
      ),
    );
  }
}
