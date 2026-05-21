import 'dart:convert';
import 'package:soilair/services/database.dart';

class JsonReaderWiFi {
  Future<void> importJsonFromString(String jsonString) async {
    final db = DatabaseHelper();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final int timestamp = data['timestamp'] as int;

    double _parse(dynamic v) {
      if (v == null) return 0.0;
      return double.parse(double.parse(v.toString()).toStringAsFixed(2));
    }

    // Ambiente (usa replace — solo guardamos el último por timestamp)
    if (data['ambiente'] != null) {
      await db.addSensorAmbiental({
        'timestamp': timestamp,
        'temperatura': _parse(data['ambiente']['temperatura']),
        'humedad': _parse(data['ambiente']['humedad']),
      });
    }

    // Primarios: INSERT sin replace → acumula historial
    if (data['primarios'] != null) {
      for (final s in data['primarios'] as List) {
        await db.insertSensorPrimario({
          'id': s['id'],
          'timestamp': timestamp,
          'n': _parse(s['n']),
          'p': _parse(s['p']),
          'k': _parse(s['k']),
          'ph': _parse(s['ph']),
          'humedad': _parse(s['humedad']),
          'ec': _parse(s['ec']),
          'temperatura': _parse(s['temperatura']),
          'radiacion': _parse(s['radiacion']),
        });
        // Registrar en admin_sensores la primera vez que aparece
        await db.addSensorIfNotExists({
          'id': s['id'],
          'nombre': null,
          'cultivo_asignado': null,
        });
      }
    }

    // Secundarios: INSERT sin replace → acumula historial
    if (data['secundarios'] != null) {
      for (final s in data['secundarios'] as List) {
        await db.insertSensorSecundario({
          'id': s['id'],
          'timestamp': timestamp,
          'ec': _parse(s['ec']),
          'humedad': _parse(s['humedad']),
          'temperatura': _parse(s['temperatura']),
          // sensor_primario_id se asigna desde la pantalla de configuración
        });
      }
    }
  }
}
