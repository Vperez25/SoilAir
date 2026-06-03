import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:soilair/services/conexion_wifi.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/services/wifi_nativo_service.dart';
import 'package:soilair/theme/app_light_theme.dart';

class ConexionBody extends StatefulWidget {
  const ConexionBody({super.key});
  @override
  State<ConexionBody> createState() => _ConexionBodyState();
}

class _ConexionBodyState extends State<ConexionBody> {
  List<WiFiAccessPoint> _nodos = [];
  Set<String> _nodosMios = {};
  bool _escaneando = false;
  String? _mensajeError;

  final _wifiNativo = WifiNativoService();
  final _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _cargar();
    _escanear();
  }

  @override
  void dispose() {
    _wifiNativo.desconectar();
    super.dispose();
  }

  Future<void> _cargar() async {
    final propietario = await _db.getNodosPropietario();
    if (mounted) setState(() => _nodosMios = Set.from(propietario));
  }

  Future<void> _escanear() async {
    setState(() { _escaneando = true; _mensajeError = null; });
    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (can == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
      final resultados = await WiFiScan.instance.getScannedResults();
      if (mounted) {
        setState(() {
          _nodos = resultados
              .where((ap) => ap.ssid.toUpperCase().startsWith('SOILAIR_'))
              .toList()
            ..sort((a, b) => b.level.compareTo(a.level));
          _escaneando = false;
        });
      }
    } else {
      if (mounted) setState(() { _escaneando = false; _mensajeError = _textoPermiso(can); });
    }
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

  Future<void> _asociar(WiFiAccessPoint nodo) async {
    final token = await _db.getDeviceToken();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AsociarDialog(
        nodo: nodo,
        wifiNativo: _wifiNativo,
        deviceToken: token,
        db: _db,
      ),
    );
    if (result == true) {
      await _db.marcarNodoPropietario(nodo.ssid);
      if (mounted) setState(() => _nodosMios.add(nodo.ssid));
    }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) _escanear();
  }

  Future<void> _deasociar(WiFiAccessPoint nodo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deasociar módulo'),
        content: Text('¿Seguro que quieres deasociar "${_nombreNodo(nodo.ssid)}"?\n\nEl historial de datos se conserva.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deasociar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final token = await _db.getDeviceToken();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeasociarDialog(
        ssid: nodo.ssid,
        wifiNativo: _wifiNativo,
        deviceToken: token,
        db: _db,
      ),
    );
    if (result == true) {
      if (mounted) setState(() => _nodosMios.remove(nodo.ssid));
    }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) _escanear();
  }

  String _nombreNodo(String ssid) =>
      ssid.replaceFirst(RegExp(r'SOILAIR_', caseSensitive: false), '');

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

  @override
  Widget build(BuildContext context) => Column(
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
            : _nodos.isEmpty
                ? _sinNodos()
                : _listaNodos(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Text(
          'Asocia un módulo para empezar a recibir sus lecturas automáticamente.',
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
        const Text('Buscando módulos SOILAIR…', style: TextStyle(fontSize: 13)),
      ] else ...[
        Text(
          _nodos.isEmpty
              ? 'No se encontraron módulos'
              : '${_nodos.length} módulo${_nodos.length != 1 ? 's' : ''} encontrado${_nodos.length != 1 ? 's' : ''}',
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
      const Text('No se encontraron módulos SoilAir', style: TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Text(
        'Asegúrate de que los ESP32 estén encendidos\ny cerca del dispositivo.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _escanear,
        icon: const Icon(Icons.refresh),
        label: const Text('Escanear de nuevo'),
      ),
    ]),
  );

  Widget _listaNodos() => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    itemCount: _nodos.length,
    itemBuilder: (_, i) {
      final nodo = _nodos[i];
      final esMio = _nodosMios.contains(nodo.ssid);
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: esMio
                ? AppLightTheme.botonPrincipal.withOpacity(0.15)
                : Colors.grey.shade100,
            child: Icon(
              Icons.sensors,
              color: esMio ? AppLightTheme.botonPrincipal : Colors.grey.shade500,
            ),
          ),
          title: Row(children: [
            Text(_nombreNodo(nodo.ssid), style: const TextStyle(fontWeight: FontWeight.w500)),
            if (esMio) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppLightTheme.botonPrincipal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Asociado',
                  style: TextStyle(fontSize: 10, color: AppLightTheme.botonPrincipal, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ]),
          subtitle: Row(children: [
            Icon(_iconoSenal(nodo.level), size: 14, color: _colorSenal(nodo.level)),
            const SizedBox(width: 4),
            Text(_labelSenal(nodo.level), style: const TextStyle(fontSize: 12)),
          ]),
          trailing: esMio
              ? OutlinedButton(
                  onPressed: () => _deasociar(nodo),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Deasociar'),
                )
              : FilledButton(
                  onPressed: () => _asociar(nodo),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppLightTheme.botonPrincipal,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Asociar'),
                ),
        ),
      );
    },
  );
}

// ══════════════════════════════════════════════════════════════
//  DIÁLOGO: Asociar módulo
// ══════════════════════════════════════════════════════════════

class _AsociarDialog extends StatefulWidget {
  final WiFiAccessPoint nodo;
  final WifiNativoService wifiNativo;
  final String deviceToken;
  final DatabaseHelper db;

  const _AsociarDialog({
    required this.nodo,
    required this.wifiNativo,
    required this.deviceToken,
    required this.db,
  });

  @override
  State<_AsociarDialog> createState() => _AsociarDialogState();
}

class _AsociarDialogState extends State<_AsociarDialog> {
  int _paso = 0;
  bool _completado = false;
  bool _exito = false;
  String? _error;

  static const _pasos = [
    'Conectando al módulo…',
    'Verificando disponibilidad…',
    'Registrando sensores…',
    'Configurando hora…',
    'Vinculando…',
  ];

  String get _nombreNodo =>
      widget.nodo.ssid.replaceFirst(RegExp(r'SOILAIR_', caseSensitive: false), '');

  @override
  void initState() {
    super.initState();
    _asociar();
  }

  void _avanzar(int paso) {
    if (mounted) setState(() => _paso = paso);
  }

  void _fallar(String msg) {
    widget.wifiNativo.desconectar();
    if (mounted) setState(() { _completado = true; _exito = false; _error = msg; });
  }

  Future<void> _asociar() async {
    // Paso 0: Conectar
    try {
      final red = await widget.wifiNativo.redActual();
      if (red != widget.nodo.ssid) {
        await widget.wifiNativo.conectar(ssid: widget.nodo.ssid);
      }
    } on WifiException catch (e) {
      _fallar(e.mensaje);
      return;
    }

    final wifi = ConexionWiFi();

    // Paso 1: Verificar claim
    _avanzar(1);
    Map<String, dynamic> claimInfo;
    try {
      claimInfo = await wifi.getClaim();
    } catch (_) {
      _fallar('Error verificando disponibilidad del módulo.');
      return;
    }
    final claimed = claimInfo['claimed'] as bool? ?? false;

    // Paso 2: Obtener sensores via /status
    _avanzar(2);
    Map<String, dynamic> status;
    try {
      status = await wifi.getStatus();
    } catch (_) {
      _fallar('Error obteniendo estado del módulo.');
      return;
    }
    final nodos = (status['nodos'] as List? ?? []);
    for (final n in nodos) {
      final sensorId = 'p${n['id']}';
      await widget.db.addSensorIfNotExists({
        'id': sensorId,
        'nombre': null,
        'cultivo_asignado': null,
        'ssid': widget.nodo.ssid,
      });
    }

    // Paso 3: Sincronizar hora
    _avanzar(3);
    try {
      await wifi.setTime();
    } catch (_) {
      // non-fatal: el nodo sigue con millis() si no hay /settime
    }

    // Paso 4: Reclamar
    _avanzar(4);
    bool ok;
    try {
      ok = await wifi.setClaim(widget.deviceToken);
    } catch (_) {
      ok = false;
    }

    await widget.wifiNativo.desconectar();

    if (!ok && claimed) {
      if (mounted) setState(() { _completado = true; _exito = false; _error = 'Este módulo está asociado a otro dispositivo.'; });
      return;
    }

    if (mounted) setState(() { _completado = true; _exito = true; });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Asociar $_nombreNodo'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._pasos.asMap().entries.map((e) => _filaPaso(e.key, e.value)),
        if (_completado && _exito) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.check_circle_outline, color: AppLightTheme.botonPrincipal, size: 20),
            const SizedBox(width: 8),
            const Text('Módulo asociado correctamente',
                style: TextStyle(color: AppLightTheme.botonPrincipal, fontWeight: FontWeight.w500)),
          ]),
        ],
        if (_completado && !_exito) ...[
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_error ?? 'Error desconocido.', style: const TextStyle(color: Colors.red, fontSize: 13))),
          ]),
        ],
      ],
    ),
    actions: _completado
        ? [
            TextButton(
              onPressed: () => Navigator.pop(context, _exito),
              child: const Text('Cerrar'),
            ),
          ]
        : null,
  );

  Widget _filaPaso(int indice, String texto) {
    final completado = _paso > indice || (_completado && _exito);
    final activo = _paso == indice && !_completado;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 24,
          height: 24,
          child: activo
              ? const CircularProgressIndicator(strokeWidth: 2.5)
              : completado
                  ? const Icon(Icons.check_circle, color: AppLightTheme.botonPrincipal, size: 22)
                  : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            color: (!activo && !completado) ? Colors.grey.shade400 : null,
            fontWeight: activo ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DIÁLOGO: Deasociar módulo
// ══════════════════════════════════════════════════════════════

class _DeasociarDialog extends StatefulWidget {
  final String ssid;
  final WifiNativoService wifiNativo;
  final String deviceToken;
  final DatabaseHelper db;

  const _DeasociarDialog({
    required this.ssid,
    required this.wifiNativo,
    required this.deviceToken,
    required this.db,
  });

  @override
  State<_DeasociarDialog> createState() => _DeasociarDialogState();
}

class _DeasociarDialogState extends State<_DeasociarDialog> {
  int _paso = 0;
  bool _completado = false;
  bool _exito = false;
  String? _error;

  static const _pasos = [
    'Conectando al módulo…',
    'Desvinculando…',
    'Actualizando datos locales…',
  ];

  String get _nombreNodo =>
      widget.ssid.replaceFirst(RegExp(r'SOILAIR_', caseSensitive: false), '');

  @override
  void initState() {
    super.initState();
    _deasociar();
  }

  void _avanzar(int paso) {
    if (mounted) setState(() => _paso = paso);
  }

  Future<void> _deasociar() async {
    // Paso 0: Conectar (no fatal si falla — limpiamos local de todas formas)
    try {
      final red = await widget.wifiNativo.redActual();
      if (red != widget.ssid) {
        await widget.wifiNativo.conectar(ssid: widget.ssid);
      }
    } on WifiException catch (_) {
      // continuar con limpieza local
    }

    // Paso 1: DELETE /claim
    _avanzar(1);
    try {
      await ConexionWiFi().deleteClaim(widget.deviceToken);
    } catch (_) {
      // non-fatal: si el nodo no responde, el claim se eliminará en el próximo reset físico
    }
    await widget.wifiNativo.desconectar();

    // Paso 2: Limpiar datos locales
    _avanzar(2);
    await widget.db.ocultarSensoresDeSsid(widget.ssid);
    await widget.db.liberarNodoPropietario(widget.ssid);

    if (mounted) setState(() { _completado = true; _exito = true; });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Deasociar $_nombreNodo'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._pasos.asMap().entries.map((e) => _filaPaso(e.key, e.value)),
        if (_completado) ...[
          const SizedBox(height: 16),
          Row(children: [
            Icon(
              _exito ? Icons.lock_open : Icons.error_outline,
              color: _exito ? AppLightTheme.botonPrincipal : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _exito ? 'Módulo desasociado correctamente.' : (_error ?? 'Error desconocido.'),
                style: TextStyle(
                  color: _exito ? AppLightTheme.botonPrincipal : Colors.red,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ]),
        ],
      ],
    ),
    actions: _completado
        ? [
            TextButton(
              onPressed: () => Navigator.pop(context, _exito),
              child: const Text('Cerrar'),
            ),
          ]
        : null,
  );

  Widget _filaPaso(int indice, String texto) {
    final completado = _paso > indice || (_completado && _exito);
    final activo = _paso == indice && !_completado;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 24,
          height: 24,
          child: activo
              ? const CircularProgressIndicator(strokeWidth: 2.5)
              : completado
                  ? const Icon(Icons.check_circle, color: AppLightTheme.botonPrincipal, size: 22)
                  : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            color: (!activo && !completado) ? Colors.grey.shade400 : null,
            fontWeight: activo ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ]),
    );
  }
}
