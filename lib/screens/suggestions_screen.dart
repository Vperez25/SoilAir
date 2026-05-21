import 'package:flutter/material.dart';
import 'package:soilair/widgets/base_scaffold.dart';
import 'package:soilair/widgets/side_menu.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/services/recommendations.dart';

class SugerenciasScreen extends StatefulWidget {
  const SugerenciasScreen({super.key});

  @override
  State<SugerenciasScreen> createState() => _SugerenciasScreenState();
}

class _SugerenciasScreenState extends State<SugerenciasScreen> {
  final dbHelper = DatabaseHelper();
  List<Sugerencia> sugerencias = [];

  final Map<String, String> nombresAmigables = {
    'n': 'Nitrógeno',
    'p': 'Fósforo',
    'k': 'Potasio',
    'ph': 'pH',
    'ec': 'Conductividad',
    'humedad': 'Humedad',
    'temp': 'Temperatura',
    'lux': 'Luz Solar',
    'viento': 'Vel. Viento',
  };

  @override
  void initState() {
    super.initState();
    cargarSugerencias();
  }

  Future<void> cargarSugerencias() async {
    final data = await dbHelper.getUltimaMedicionCompleta();
    if (data == null) return;

    final sensores = data['primarios'] as List<dynamic>;
    List<Sugerencia> todas = [];

    for (var sensor in sensores) {
      final rangos = await dbHelper.getRangosCultivoAsignado(sensor['id']);
      if (rangos != null) {
        todas.addAll(EvaluadorSugerencias.evaluarSensor(
          sensor: sensor,
          rangos: rangos,
        ));
      }
    }

    setState(() {
      sugerencias = todas;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Sugerencias',
      drawer: MySideMenuWidget(scaffoldContext: context),
      body: sugerencias.isEmpty
          ? Center(child: Text('No hay sugerencias disponibles.'))
          : ListView.builder(
              itemCount: sugerencias.length,
              itemBuilder: (context, index) {
                final sug = sugerencias[index];
                final nombreParametro =
                    nombresAmigables[sug.parametro] ?? sug.parametro;

                return Card(
                  color: _colorPorNivel(sug.nivel),
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('${sug.sensorNombre} - $nombreParametro'),
                    subtitle: Text(sug.mensaje),
                    trailing: Text('${sug.valor?.toStringAsFixed(2)}'),
                  ),
                );
              },
            ),
    );
  }

  Color _colorPorNivel(String nivel) {
    switch (nivel) {
      case 'crítico':
        return Colors.red.shade100;
      case 'bajo':
        return Colors.yellow.shade100;
      case 'alto':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}
