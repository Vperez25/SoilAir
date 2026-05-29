import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:soilair/services/database.dart';

class JsonReader {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtiene o crea el directorio local jsondata
  Future<Directory> _getLocalJsonDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final jsonDir = Directory('${directory.path}/jsondata');
    if (!await jsonDir.exists()) {
      await jsonDir.create(recursive: true);
    }
    return jsonDir;
  }

  /// Lee y procesa todos los archivos JSON en jsondata/
  /// Inserta/actualiza los datos en la base de datos y elimina los archivos
  Future<void> importJsonDataAndClean() async {
    final dir = await _getLocalJsonDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));

    for (final file in files) {
      try {
        final content = await file.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(content);

        // Procesar datos de ambiente
        if (jsonData.containsKey('ambiente') && jsonData['ambiente'] is Map<String, dynamic>) {
          final ambiente = jsonData['ambiente'] as Map<String, dynamic>;
          final sensorAmbiental = <String, dynamic>{
            'timestamp': jsonData['timestamp'],
            'temperatura': ambiente['temperatura'],
            'humedad': ambiente['humedad'],
          };
          await _dbHelper.addSensorAmbiental(sensorAmbiental);
        }

        // Procesar sensores primarios
        if (jsonData.containsKey('primarios') && jsonData['primarios'] is List) {
          final List primarios = jsonData['primarios'];
          for (final dynamic sensor in primarios) {
            if (sensor is Map<String, dynamic>) {
              // Insertar en sensores_primarios con los atributos correctos
              final sensorPrimarioMap = <String, dynamic>{
                'id': sensor['id'],
                'timestamp': jsonData['timestamp'],
                'n': sensor['n']?.toDouble(),
                'p': sensor['p']?.toDouble(),
                'k': sensor['k']?.toDouble(),
                'ph': sensor['ph']?.toDouble(),
                'humedad': sensor['humedad']?.toDouble(),
                'ec': sensor['ec']?.toDouble(),
                'temperatura': sensor['temperatura']?.toDouble(),
                'radiacion': sensor['radiacion']?.toDouble(),
              };
              await _dbHelper.insertOrUpdateSensorPrimario(sensorPrimarioMap);

              // Insertar en admin_sensores solo si no existe
              await _dbHelper.addSensorIfNotExists({
                'id': sensor['id'],
                'nombre': null,
                'cultivo_asignado': null,
              });
            }
          }
        }

        // Procesar sensores secundarios
        // Procesar sensores secundarios
        if (jsonData.containsKey('secundarios') && jsonData['secundarios'] is List) {
          final List secundarios = jsonData['secundarios'];
          for (final dynamic sensor in secundarios) {
            if (sensor is Map<String, dynamic>) {
              // Consultar el sensor secundario actual para preservar sensor_primario_id
              final existentes = await _dbHelper.database.then((db) => db.query(
                    'sensores_secundarios',
                    where: 'id = ?',
                    whereArgs: [sensor['id']],
                    limit: 1,
                  ));
              String? sensorPrimarioIdExistente;
              if (existentes.isNotEmpty) {
                sensorPrimarioIdExistente = existentes.first['sensor_primario_id'] as String?;
              }

              final sensorMap = <String, dynamic>{
                'id': sensor['id'],
                'timestamp': jsonData['timestamp'],
                'ec': sensor['ec']?.toDouble(),
                'humedad': sensor['humedad']?.toDouble(),
                'temperatura': sensor['temperatura']?.toDouble(),
                if (sensorPrimarioIdExistente != null) 'sensor_primario_id': sensorPrimarioIdExistente,
              };
              await _dbHelper.insertOrUpdateSensorSecundario(sensorMap);
            }
          }
        }


        // Si todo bien, elimina el archivo
        await file.delete();
      } catch (e) {
        print('Error al procesar ${file.path}: $e');
        // No eliminar el archivo para que se pueda revisar/reintentar después
      }
    }
  }
}
