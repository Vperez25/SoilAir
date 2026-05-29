import 'package:flutter/services.dart';

/// Servicio para conectar/desconectar redes WiFi SoilAir usando
/// WifiNetworkSpecifier (Android 10+) a través de un platform channel.
class WifiNativoService {
  static const _channel = MethodChannel('com.soilair/wifi');

  /// Conecta a [ssid] con [password].
  /// Lanza [WifiException] si falla o el dispositivo es Android < 10.
  Future<void> conectar({
    required String ssid,
    String password = 'soilair1',
  }) async {
    try {
      await _channel.invokeMethod<String>('conectarWifi', {
        'ssid': ssid,
        'password': password,
      });
    } on PlatformException catch (e) {
      throw WifiException._fromPlatform(e);
    }
  }

  /// Libera el callback de red y desvincula el proceso.
  /// Llamar siempre al terminar la sincronización.
  Future<void> desconectar() async {
    try {
      await _channel.invokeMethod<void>('desconectarWifi');
    } on PlatformException {
      // ignorar errores al desconectar
    }
  }

  /// Devuelve el SSID de la red WiFi activa, o null si no hay.
  Future<String?> redActual() async {
    try {
      return await _channel.invokeMethod<String>('redActual');
    } on PlatformException {
      return null;
    }
  }

  /// True si el dispositivo ya está conectado a un nodo SoilAir.
  Future<bool> estaEnRedSoilair() async {
    final ssid = await redActual();
    return ssid != null && ssid.startsWith('SOILAIR_');
  }
}

class WifiException implements Exception {
  final String codigo;
  final String mensaje;

  const WifiException({required this.codigo, required this.mensaje});

  factory WifiException._fromPlatform(PlatformException e) {
    const mensajes = {
      'NO_SOPORTADO':
          'Tu dispositivo necesita Android 10 o superior para conectarse '
          'automáticamente. Conéctate manualmente a la red SOILAIR_* desde '
          'Ajustes → WiFi.',
      'TIMEOUT':
          'No se encontró el nodo. Asegúrate de que el ESP32 esté encendido '
          'y que estés dentro del rango.',
      'NO_DISPONIBLE':
          'La red no está disponible. Intenta de nuevo en unos segundos.',
    };
    return WifiException(
      codigo: e.code,
      mensaje: mensajes[e.code] ?? e.message ?? 'Error desconocido.',
    );
  }

  @override
  String toString() => 'WifiException[$codigo]: $mensaje';
}
