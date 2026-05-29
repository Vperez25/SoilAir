import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:soilair/services/conexion_wifi.dart';
import 'package:soilair/services/json_reader_wifi.dart';
import 'package:soilair/services/wifi_nativo_service.dart';
import 'package:soilair/theme/app_light_theme.dart';

class ConexionBody extends StatefulWidget {
  const ConexionBody({super.key});
  @override
  State<ConexionBody> createState() => _ConexionBodyState();
}

class _ConexionBodyState extends State<ConexionBody> {
  List<WiFiAccessPoint> _nodos = [];
  bool _escaneando = false;

  String? _ssidActivo;
  int _pasoActual = -1;
  bool _sincronizoOk = false;
  int _archivosSync = 0;
  String? _mensajeError;

  static const _pasos = [
    'Conectando a la red…',
    'Listando archivos del nodo…',
    'Descargando mediciones…',
    'Guardando en base de datos…',
  ];

  final _wifiNativo = WifiNativoService();

  @override
  void initState() {
    super.initState();
    _escanear();
  }

  @override
  void dispose() {
    _wifiNativo.desconectar();
    super.dispose();
  }

  // ── Escaneo ─────────────────────────────────────────────────

  Future<void> _escanear() async {
    setState(() { _escaneando = true; _mensajeError = null; });

    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (can == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
    } else {
      setState(() { _escaneando = false; _mensajeError = _textoPermiso(can); });
      return;
    }

    final resultados = await WiFiScan.instance.getScannedResults();
    setState(() {
      // Filtrar cualquier red SOILAIR_* sin importar el sufijo
      _nodos = resultados
          .where((ap) => ap.ssid.toUpperCase().startsWith('SOILAIR_'))
          .toList()
        ..sort((a, b) => b.level.compareTo(a.level));
      _escaneando = false;
    });
  }

  String _textoPermiso(CanStartScan r) {
    switch (r) {
      case CanStartScan.noLocationPermissionDenied:
      case CanStartScan.noLocationPermissionRequired:
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        return 'Activa el permiso de ubicación:\nAjustes → Aplicaciones → SoilAir → Permisos → Ubicación';
      case CanStartScan.noLocationServiceDisabled:
        return 'Activa la ubicación del dispositivo para detectar redes WiFi.';
      default:
        return 'No se puede escanear en este momento.';
    }
  }

  // ── Sincronización ──────────────────────────────────────────

  Future<void> _sincronizar(WiFiAccessPoint nodo) async {
    setState(() {
      _ssidActivo = nodo.ssid;
      _pasoActual = 0;
      _sincronizoOk = false;
      _archivosSync = 0;
      _mensajeError = null;
    });

    // Paso 0: conectar al ESP32
    try {
      final redActual = await _wifiNativo.redActual();
      if (redActual != nodo.ssid) {
        await _wifiNativo.conectar(ssid: nodo.ssid);
      }
    } on WifiException catch (e) {
      _fallar(e.mensaje);
      return;
    }

    // Pasos 1-3: descargar y guardar
    _avanzar(1);
    final resultado = await ConexionWiFi().descargarTodosYEliminar((jsonStr) async {
      _avanzar(2);
      await JsonReaderWiFi().importJsonFromString(jsonStr);
      _avanzar(3);
    });

    await _wifiNativo.desconectar();

    setState(() {
      _pasoActual = -1;
      _sincronizoOk = resultado.exito;
      _archivosSync = resultado.archivosSincronizados;
      if (!resultado.exito) _mensajeError = resultado.mensaje;
    });
  }

  void _avanzar(int paso) { if (mounted) setState(() => _pasoActual = paso); }
  void _fallar(String m) { if (mounted) setState(() { _pasoActual = -1; _sincronizoOk = false; _mensajeError = m; }); }
  void _resetear() => setState(() { _ssidActivo = null; _pasoActual = -1; _sincronizoOk = false; _mensajeError = null; });

  // ── Helpers ─────────────────────────────────────────────────

  String _nombreNodo(String ssid) => ssid.replaceFirst(RegExp(r'SOILAIR_', caseSensitive: false), '');

  String _labelSenal(int dBm) {
    if (dBm >= -50) return 'Señal excelente';
    if (dBm >= -65) return 'Señal buena';
    if (dBm >= -75) return 'Señal débil';
    return 'Señal muy débil';
  }

  IconData _iconoSenal(int dBm) {
    if (dBm >= -50) return Icons.signal_wifi_4_bar;
    if (dBm >= -65) return Icons.network_wifi_3_bar;
    if (dBm >= -75) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  Color _colorSenal(int dBm) {
    if (dBm >= -65) return AppLightTheme.botonPrincipal;
    if (dBm >= -75) return Colors.orange;
    return Colors.red;
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) =>
      _ssidActivo != null ? _vistaSync() : _vistaEscaneo();

  // ── Vista escaneo ───────────────────────────────────────────

  Widget _vistaEscaneo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _bannerEscaneo(),
      if (_mensajeError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(_mensajeError!, style: const TextStyle(color: Colors.orange, fontSize: 13)),
        ),
      Expanded(
        child: _escaneando
            ? const Center(child: CircularProgressIndicator())
            : _nodos.isEmpty ? _sinNodos() : _listaNodos(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Text(
          'Puedes conectarte a cualquier nodo para obtener datos de toda la red.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );

  Widget _bannerEscaneo() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(children: [
      if (_escaneando) ...[
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        const Text('Buscando redes SOILAIR…', style: TextStyle(fontSize: 13)),
      ] else ...[
        Text(
          _nodos.isEmpty ? 'No se encontraron nodos'
              : '${_nodos.length} nodo${_nodos.length != 1 ? 's' : ''} encontrado${_nodos.length != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _escanear,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Escanear'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    ]),
  );

  Widget _sinNodos() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off, size: 52, color: Colors.grey.shade400),
      const SizedBox(height: 12),
      const Text('No se encontraron nodos SoilAir', style: TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Text(
        'Asegúrate de que los ESP32 estén encendidos\ny cerca del dispositivo.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _escanear, icon: const Icon(Icons.refresh), label: const Text('Escanear de nuevo')),
    ]),
  );

  Widget _listaNodos() => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    itemCount: _nodos.length,
    itemBuilder: (_, i) => Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppLightTheme.botonPrincipal.withOpacity(0.1),
          child: const Icon(Icons.sensors, color: AppLightTheme.botonPrincipal),
        ),
        title: Text(_nombreNodo(_nodos[i].ssid), style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Row(children: [
          Icon(_iconoSenal(_nodos[i].level), size: 14, color: _colorSenal(_nodos[i].level)),
          const SizedBox(width: 4),
          Text(_labelSenal(_nodos[i].level), style: const TextStyle(fontSize: 12)),
        ]),
        trailing: FilledButton(
          onPressed: () => _sincronizar(_nodos[i]),
          style: FilledButton.styleFrom(backgroundColor: AppLightTheme.botonPrincipal, visualDensity: VisualDensity.compact),
          child: const Text('Sincronizar'),
        ),
      ),
    ),
  );

  // ── Vista sincronización ────────────────────────────────────

  Widget _vistaSync() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(onPressed: _pasoActual >= 0 ? null : _resetear, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 4),
        Text(_nombreNodo(_ssidActivo!), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 24),
      ..._pasos.asMap().entries.map((e) => _filaPaso(e.key, e.value)),
      const SizedBox(height: 32),
      if (_pasoActual == -1 && (_sincronizoOk || _mensajeError != null)) _tarjetaResultado(),
    ]),
  );

  Widget _filaPaso(int indice, String texto) {
    final completado = _pasoActual > indice || (_pasoActual == -1 && _sincronizoOk);
    final activo = _pasoActual == indice;
    final pendiente = !completado && !activo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 28, height: 28,
          child: activo
              ? const CircularProgressIndicator(strokeWidth: 2.5)
              : completado
                  ? const Icon(Icons.check_circle, color: AppLightTheme.botonPrincipal)
                  : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400)),
        const SizedBox(width: 12),
        Text(texto, style: TextStyle(
          fontSize: 15,
          color: pendiente ? Colors.grey.shade400 : null,
          fontWeight: activo ? FontWeight.w500 : FontWeight.normal,
        )),
      ]),
    );
  }

  Widget _tarjetaResultado() {
    if (_sincronizoOk) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppLightTheme.botonPrincipal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppLightTheme.botonPrincipal.withOpacity(0.3)),
        ),
        child: Column(children: [
          const Icon(Icons.check_circle_outline, size: 40, color: AppLightTheme.botonPrincipal),
          const SizedBox(height: 10),
          const Text('¡Sincronización completa!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppLightTheme.botonPrincipal)),
          const SizedBox(height: 4),
          Text('$_archivosSync archivo${_archivosSync != 1 ? 's' : ''} importado${_archivosSync != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _resetear, child: const Text('Conectar a otro nodo')),
        ]),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('No se pudo sincronizar', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
        ]),
        const SizedBox(height: 8),
        Text(_mensajeError ?? '', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 14),
        Row(children: [
          OutlinedButton(onPressed: _resetear, child: const Text('Volver')),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              final nodo = _nodos.firstWhere((n) => n.ssid == _ssidActivo, orElse: () => _nodos.first);
              _sincronizar(nodo);
            },
            child: const Text('Reintentar'),
          ),
        ]),
      ]),
    );
  }
}
