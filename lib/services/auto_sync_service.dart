import 'dart:async';
import 'package:soilair/services/conexion_wifi.dart';
import 'package:soilair/services/data_events.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/services/json_reader_wifi.dart';
import 'package:soilair/services/wifi_nativo_service.dart';

class AutoSyncService {
  final _wifiNativo = WifiNativoService();
  Timer? _timer;
  bool _sincronizando = false;

  void start() {
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _sync());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sync() async {
    if (_sincronizando) return;
    _sincronizando = true;
    try {
      // 1) Si YA estás en la red de un nodo, úsala directamente.
      final yaEnRed = await _wifiNativo.estaEnRedSoilair();
      if (yaEnRed) {
        final ssid = await _wifiNativo.redActual();
        await _descargar(ssid);
        return;
      }

      // 2) Si NO, intenta conectarte a un nodo conocido en segundo plano.
      final db = DatabaseHelper();
      final ssids = await db.getSsidsConocidos();
      if (ssids.isEmpty) return; // todavía no hay nodos vinculados

      for (final ssid in ssids) {
        try {
          await _wifiNativo.conectar(ssid: ssid); // conexión efímera
          await _descargar(ssid);
          await _wifiNativo.desconectar();         // devuelve el WiFi normal
          break; // con sincronizar uno basta por ciclo
        } catch (_) {
          await _wifiNativo.desconectar();
          // ese nodo no está en rango, intenta el siguiente
        }
      }
    } catch (_) {
      // silencioso — los fallos de fondo no son fatales
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _descargar(String? ssid) async {
    final resultado = await ConexionWiFi().descargarTodosYEliminar(
      (jsonStr) => JsonReaderWiFi(ssid: ssid).importJsonFromString(jsonStr),
    );
    if (resultado.exito && resultado.archivosSincronizados > 0) {
      DataEvents.instance.notificarDatosNuevos();
    }
  }
}
