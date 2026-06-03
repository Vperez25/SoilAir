import 'dart:async';
import 'package:soilair/services/conexion_wifi.dart';
import 'package:soilair/services/data_events.dart';
import 'package:soilair/services/json_reader_wifi.dart';
import 'package:soilair/services/wifi_nativo_service.dart';

class AutoSyncService {
  final _wifiNativo = WifiNativoService();
  Timer? _timer;
  bool _sincronizando = false;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _sync());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sync() async {
    if (_sincronizando) return;
    final enRed = await _wifiNativo.estaEnRedSoilair();
    if (!enRed) return;
    _sincronizando = true;
    try {
      final ssid = await _wifiNativo.redActual();
      final resultado = await ConexionWiFi().descargarTodosYEliminar(
        (jsonStr) => JsonReaderWiFi(ssid: ssid).importJsonFromString(jsonStr),
      );
      if (resultado.exito && resultado.archivosSincronizados > 0) {
        DataEvents.instance.notificarDatosNuevos();
      }
    } catch (_) {
      // silent — background sync failures are non-fatal
    } finally {
      _sincronizando = false;
    }
  }
}
