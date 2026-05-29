import 'dart:convert';
import 'package:soilair/services/database.dart';

class JsonReaderWiFi {
  final String? ssid;
  JsonReaderWiFi({this.ssid});

  Future<void> importJsonFromString(String jsonString) async {
    final db = DatabaseHelper();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    // ESP32 uses millis()/1000 (seconds since boot), not a real Unix timestamp.
    // We replace it with the phone's current time so date filters work correctly.
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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
          if (ssid != null) 'ssid': ssid,
        });
      }
    }

    // Secundarios: INSERT sin replace → acumula historial
    // sensor_primario_id se deduce por convención: s1,s2→p1 | s3,s4→p2 | …
    if (data['secundarios'] != null) {
      for (final s in data['secundarios'] as List) {
        final secId = s['id'] as String;
        String? primarioId;
        if (secId.startsWith('s')) {
          final n = int.tryParse(secId.substring(1));
          if (n != null) primarioId = 'p${((n - 1) ~/ 2) + 1}';
        }
        await db.insertSensorSecundario({
          'id': secId,
          'timestamp': timestamp,
          'ec': _parse(s['ec']),
          'humedad': _parse(s['humedad']),
          'temperatura': _parse(s['temperatura']),
          if (primarioId != null) 'sensor_primario_id': primarioId,
        });
      }
    }
  }
}
