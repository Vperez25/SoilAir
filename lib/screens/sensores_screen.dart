import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/main.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/services/conexion_wifi.dart';
import 'package:soilair/services/json_reader_wifi.dart';
import 'package:soilair/services/wifi_nativo_service.dart';
import 'package:soilair/theme/app_light_theme.dart';
import 'package:soilair/widgets/base_scaffold.dart';

class SensoresScreen extends StatefulWidget {
  const SensoresScreen({super.key});
  @override
  State<SensoresScreen> createState() => _SensoresScreenState();
}

class _SensoresScreenState extends State<SensoresScreen> {
  final _db = DatabaseHelper();
  final _wifiNativo = WifiNativoService();

  List<Map<String, dynamic>> _sensores = [];
  List<Map<String, dynamic>> _cultivos = [];
  Set<String> _nodosPropiedad = {};

  List<WiFiAccessPoint> _nodos = [];
  bool _escaneando = false;
  String? _mensajeError;

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

  // ── Carga ─────────────────────────────────────────────────────

  Future<void> _cargar() async {
    final sensores = await _db.getSensoresPrimarioConConfig();
    final cultivos = await _db.getCultivos();
    final propietario = await _db.getNodosPropietario();
    setState(() {
      _sensores = sensores;
      _cultivos = cultivos;
      _nodosPropiedad = Set.from(propietario);
    });
  }

  // ── WiFi scan ─────────────────────────────────────────────────

  Future<void> _escanear() async {
    setState(() { _escaneando = true; _mensajeError = null; });

    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (can != CanStartScan.yes) {
      final s = AppStrings.of(appLanguage.value);
      setState(() { _escaneando = false; _mensajeError = _textoPermiso(can, s); });
      return;
    }
    await WiFiScan.instance.startScan();
    final resultados = await WiFiScan.instance.getScannedResults();
    setState(() {
      _nodos = resultados
          .where((ap) => ap.ssid.toUpperCase().startsWith('SOILAIR_'))
          .toList()
        ..sort((a, b) => b.level.compareTo(a.level));
      _escaneando = false;
    });
  }

  String _textoPermiso(CanStartScan r, AppStrings s) {
    switch (r) {
      case CanStartScan.noLocationPermissionDenied:
      case CanStartScan.noLocationPermissionRequired:
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        return s.permisoUbicacion;
      case CanStartScan.noLocationServiceDisabled:
        return s.ubicacionDesactivada;
      default:
        return s.noSePuedeEscanear;
    }
  }

  // ── Sincronización ────────────────────────────────────────────

  Future<void> _sincronizar(WiFiAccessPoint nodo) async {
    final idsAntes = _sensores.map((sen) => sen['id'] as String).toSet();
    final deviceToken = await _db.getDeviceToken();
    final esPropietario = _nodosPropiedad.contains(nodo.ssid);

    final resultado = await showDialog<_SyncResultado>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SyncDialog(
        nodo: nodo,
        wifiNativo: _wifiNativo,
        deviceToken: deviceToken,
        esPropietarioPrevio: esPropietario,
      ),
    );

    if (resultado?.claimNuevo == true) {
      await _db.marcarNodoPropietario(nodo.ssid);
      _nodosPropiedad.add(nodo.ssid);
    }
    if (resultado?.resetFisicoDetectado == true) {
      await _db.liberarNodoPropietario(nodo.ssid);
      _nodosPropiedad.remove(nodo.ssid);
      if (mounted) {
        final s = AppStrings.of(appLanguage.value);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.resetFisicoSnackbar(_nombreNodo(nodo.ssid))),
          backgroundColor: Colors.orange,
        ));
      }
    }

    await _cargar();

    if (!mounted) return;
    final nuevos = _sensores
        .where((sen) => !idsAntes.contains(sen['id']) && sen['nombre'] == null)
        .toList();
    for (final sen in nuevos) {
      if (!mounted) break;
      await _abrirConfig(sen['id'] as String);
    }
  }

  // ── Liberar nodo desde la lista de detectados ─────────────────

  Future<void> _liberarNodo(WiFiAccessPoint nodo) async {
    final s = AppStrings.of(appLanguage.value);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.liberarNodo),
        content: Text(s.liberarNodoContenido(_nombreNodo(nodo.ssid))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancelar),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.liberar),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final deviceToken = await _db.getDeviceToken();
    final liberado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LiberarDialog(
        ssid: nodo.ssid,
        wifiNativo: _wifiNativo,
        deviceToken: deviceToken,
      ),
    );

    if (liberado == true) {
      await _db.liberarNodoPropietario(nodo.ssid);
      setState(() => _nodosPropiedad.remove(nodo.ssid));
    }
  }

  // ── Configuración de sensor ───────────────────────────────────

  Future<void> _abrirConfig(String sensorId) async {
    final sensor = _sensores.firstWhere((sen) => sen['id'] == sensorId,
        orElse: () => <String, dynamic>{});
    final nombresOcupados = await _db.getNombresExcepto(sensorId);

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ConfigSensorDialog(
        sensorId: sensorId,
        nombreActual: sensor['nombre'] as String?,
        cultivoActualId: sensor['cultivo_asignado'] as int?,
        cultivos: _cultivos,
        nombresOcupados: nombresOcupados,
      ),
    );

    if (result != null) {
      await _db.configurarSensor(
        sensorId: sensorId,
        nombre: result['nombre'] as String,
        cultivoId: result['cultivoId'] as int?,
      );
      await _cargar();
    }
  }

  // ── Desincronizar sensor ──────────────────────────────────────

  Future<void> _confirmarDesincronizar(String sensorId, String nombre) async {
    final s = AppStrings.of(appLanguage.value);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.desincronizarSensor),
        content: Text(s.desincronizarContenido(nombre)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancelar),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.desincronizarSensor),
          ),
        ],
      ),
    );
    if (ok == true) {
      // If this is the last sensor from its node, release the ESP32 claim
      // so a future re-sync (even after reinstall) is not rejected.
      final ssid = await _db.getSsidDeSensor(sensorId);
      if (ssid != null && _nodosPropiedad.contains(ssid) && mounted) {
        final esUltimo = await _db.esUltimoSensorDeNodo(sensorId);
        if (esUltimo) {
          final deviceToken = await _db.getDeviceToken();
          if (mounted) {
            await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _LiberarDialog(
                ssid: ssid,
                wifiNativo: _wifiNativo,
                deviceToken: deviceToken,
              ),
            );
          }
        }
      }
      await _db.desincronizarSensor(sensorId);
      await _db.liberarNodoPropietarioPorSensor(sensorId);
      await _cargar();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _nombreNodo(String ssid) =>
      ssid.replaceFirst(RegExp(r'SOILAIR_', caseSensitive: false), '');

  String _labelSenal(int dBm, AppStrings s) {
    if (dBm >= -50) return s.senalExcelente;
    if (dBm >= -65) return s.senalBuena;
    if (dBm >= -75) return s.senalDebil;
    return s.senalMuyDebil;
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

  String _formatFecha(int? ts, AppStrings s) {
    if (ts == null) return s.sinLecturas;
    final fecha = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) return s.haceUnMomento;
    if (diff.inMinutes < 60) return s.haceMins(diff.inMinutes);
    if (diff.inHours < 24) return s.haceHoras(diff.inHours);
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);
    final nodosVisibles = _nodos
        .where((n) => !_nodosPropiedad.contains(n.ssid))
        .toList();

    return BaseScaffold(
      title: s.navSensores,
      body: RefreshIndicator(
        onRefresh: () async { await _cargar(); await _escanear(); },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ══════ SECCIÓN 1: Sensores conectados ═══════════════
            _tituloSeccion(Icons.sensors, s.sensoresConectados),
            const SizedBox(height: 8),

            if (_sensores.isEmpty)
              _tarjetaVacia(
                icono: Icons.sensors_off,
                texto: s.sinSensoresRegistrados,
                sub: s.sincronizaDesdeAbajo,
              )
            else
              ..._sensores.map((sen) {
                final configurado = sen['nombre'] != null;
                return configurado
                    ? _tarjetaConfigurado(sen, s)
                    : _tarjetaNoConfigurado(sen, s);
              }),

            const SizedBox(height: 24),

            // ══════ SECCIÓN 2: Nodos detectados ══════════════════
            _tituloSeccion(Icons.wifi_find, s.nodosDetectados),
            const SizedBox(height: 8),
            _bannerEscaneo(nodosVisibles.length, s),

            if (_mensajeError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_mensajeError!,
                    style: const TextStyle(color: Colors.orange, fontSize: 13)),
              ),

            if (_escaneando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (nodosVisibles.isEmpty)
              _tarjetaVacia(
                icono: Icons.wifi_off,
                texto: s.noEncontradosNodos,
                sub: s.asegurateNodos,
              )
            else
              ...nodosVisibles.map((n) => _tarjetaNodo(n, s)),

            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.puedesConectar,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────

  Widget _tituloSeccion(IconData icono, String titulo) => Row(children: [
    Icon(icono, size: 18, color: AppLightTheme.botonPrincipal),
    const SizedBox(width: 8),
    Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  ]);

  Widget _tarjetaVacia({required IconData icono, required String texto, required String sub}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        Icon(icono, size: 44, color: onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 10),
        Text(texto,
            style: TextStyle(color: onSurface.withValues(alpha: 0.55), fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.45))),
      ]),
    );
  }

  Widget _tarjetaConfigurado(Map<String, dynamic> sen, AppStrings s) {
    final id = sen['id'] as String;
    final nombre = sen['nombre'] as String;
    final cultivoNombre = sen['cultivo_nombre'] as String?;
    final ts = sen['ultimo_timestamp'] as int?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppLightTheme.divisor),
      ),
      child: ListTile(
        onLongPress: () => _confirmarDesincronizar(id, nombre),
        leading: CircleAvatar(
          backgroundColor: AppLightTheme.botonPrincipal.withValues(alpha: 0.1),
          child: const Icon(Icons.sensors, color: AppLightTheme.botonPrincipal, size: 20),
        ),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cultivoNombre != null)
              Text(cultivoNombre, style: const TextStyle(fontSize: 12)),
            Text(_formatFecha(ts, s),
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.link_off, color: Colors.orange),
              tooltip: s.desincronizarSensor,
              onPressed: () => _confirmarDesincronizar(id, nombre),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppLightTheme.botonPrincipal),
              tooltip: s.editar,
              onPressed: () => _abrirConfig(id),
            ),
          ],
        ),
        isThreeLine: cultivoNombre != null,
      ),
    );
  }

  Widget _tarjetaNoConfigurado(Map<String, dynamic> sen, AppStrings s) {
    final id = sen['id'] as String;
    final ts = sen['ultimo_timestamp'] as int?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: ListTile(
        onTap: () => _abrirConfig(id),
        onLongPress: () => _confirmarDesincronizar(id, id),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          child: Icon(Icons.sensors_off, color: Colors.orange.shade700, size: 20),
        ),
        title: Text(s.noConfigurado,
            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.orange)),
        subtitle: Text(_formatFecha(ts, s),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        trailing: Icon(Icons.chevron_right, color: Colors.orange.shade300),
      ),
    );
  }

  Widget _bannerEscaneo(int count, AppStrings s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      if (_escaneando) ...[
        const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text(s.buscandoRedes, style: const TextStyle(fontSize: 13)),
      ] else ...[
        Text(
          s.nodosEncontrados(count),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _escanear,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(s.escanear),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    ]),
  );

  Widget _tarjetaNodo(WiFiAccessPoint nodo, AppStrings s) {
    final esMio = _nodosPropiedad.contains(nodo.ssid);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppLightTheme.botonPrincipal.withValues(alpha: 0.1),
          child: const Icon(Icons.sensors, color: AppLightTheme.botonPrincipal),
        ),
        title: Row(children: [
          Text(_nombreNodo(nodo.ssid),
              style: const TextStyle(fontWeight: FontWeight.w500)),
          if (esMio) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: s.vinculadoDispositivo,
              child: Icon(Icons.lock, size: 14, color: AppLightTheme.botonPrincipal.withValues(alpha: 0.7)),
            ),
          ],
        ]),
        subtitle: Row(children: [
          Icon(_iconoSenal(nodo.level), size: 14, color: _colorSenal(nodo.level)),
          const SizedBox(width: 4),
          Text(_labelSenal(nodo.level, s), style: const TextStyle(fontSize: 12)),
        ]),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (esMio)
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'liberar') _liberarNodo(nodo);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'liberar',
                    child: Row(children: [
                      const Icon(Icons.lock_open, size: 18, color: Colors.orange),
                      const SizedBox(width: 10),
                      Text(s.liberarNodo),
                    ]),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => _sincronizar(nodo),
              style: FilledButton.styleFrom(
                  backgroundColor: AppLightTheme.botonPrincipal,
                  visualDensity: VisualDensity.compact),
              child: Text(s.sincronizar),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Resultado del diálogo de sincronización
// ══════════════════════════════════════════════════════════════

class _SyncResultado {
  final bool claimNuevo;
  final bool resetFisicoDetectado;
  const _SyncResultado({this.claimNuevo = false, this.resetFisicoDetectado = false});
}

// ══════════════════════════════════════════════════════════════
//  DIÁLOGO: Configurar sensor
// ══════════════════════════════════════════════════════════════

class _ConfigSensorDialog extends StatefulWidget {
  final String sensorId;
  final String? nombreActual;
  final int? cultivoActualId;
  final List<Map<String, dynamic>> cultivos;
  final List<String> nombresOcupados;

  const _ConfigSensorDialog({
    required this.sensorId,
    required this.nombreActual,
    required this.cultivoActualId,
    required this.cultivos,
    required this.nombresOcupados,
  });

  @override
  State<_ConfigSensorDialog> createState() => _ConfigSensorDialogState();
}

class _ConfigSensorDialogState extends State<_ConfigSensorDialog> {
  int? _cultivoId;
  late TextEditingController _nombreCtrl;
  String? _errorNombre;

  @override
  void initState() {
    super.initState();
    _cultivoId = widget.cultivoActualId;
    _nombreCtrl = TextEditingController(
      text: widget.nombreActual ?? _generarNombre(_cultivoId),
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  String _generarNombre(int? cultivoId) {
    final sinNombre = AppStrings.of(appLanguage.value).sinNombre;
    if (cultivoId == null) return sinNombre;
    final c = widget.cultivos.firstWhere(
      (c) => c['id'] == cultivoId,
      orElse: () => <String, dynamic>{},
    );
    final base = c['nombre'] as String? ?? sinNombre;
    if (!widget.nombresOcupados.contains(base)) return base;
    int i = 2;
    while (widget.nombresOcupados.contains('$base $i')) i++;
    return '$base $i';
  }

  void _onCultivoChanged(int? cultivoId) {
    setState(() {
      _cultivoId = cultivoId;
      _errorNombre = null;
    });
    _nombreCtrl.text = _generarNombre(cultivoId);
  }

  void _guardar() {
    final s = AppStrings.of(appLanguage.value);
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _errorNombre = s.nombreVacio);
      return;
    }
    if (widget.nombresOcupados.contains(nombre)) {
      setState(() => _errorNombre = s.nombreExiste);
      return;
    }
    Navigator.pop(context, {'nombre': nombre, 'cultivoId': _cultivoId});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);
    return AlertDialog(
      title: Text(s.configurarSensor),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int?>(
              value: _cultivoId,
              decoration: InputDecoration(
                labelText: s.cultivoLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              isExpanded: true,
              items: [
                ...widget.cultivos.map((c) => DropdownMenuItem<int?>(
                  value: c['id'] as int,
                  child: Text(c['nombre'] as String),
                )),
                DropdownMenuItem<int?>(value: null, child: Text(s.otro)),
              ],
              onChanged: _onCultivoChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: s.nombreSensor,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                errorText: _errorNombre,
              ),
              onChanged: (_) {
                if (_errorNombre != null) setState(() => _errorNombre = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancelar),
        ),
        FilledButton(
          onPressed: _guardar,
          style: FilledButton.styleFrom(backgroundColor: AppLightTheme.botonPrincipal),
          child: Text(s.guardar),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DIÁLOGO: Sincronización (con verificación de propiedad)
// ══════════════════════════════════════════════════════════════

class _SyncDialog extends StatefulWidget {
  final WiFiAccessPoint nodo;
  final WifiNativoService wifiNativo;
  final String deviceToken;
  final bool esPropietarioPrevio;

  const _SyncDialog({
    required this.nodo,
    required this.wifiNativo,
    required this.deviceToken,
    required this.esPropietarioPrevio,
  });

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  int _pasoActual = 0;
  bool _completado = false;
  bool _conError = false;
  String? _mensajeError;
  int _archivos = 0;
  bool _claimNuevo = false;
  bool _esperandoReset = false;

  @override
  void initState() {
    super.initState();
    _sincronizar();
  }

  String _nombreNodo(String ssid) =>
      ssid.replaceFirst(RegExp(r'SOILAIR_', caseSensitive: false), '');

  void _avanzar(int paso) {
    if (mounted) setState(() => _pasoActual = paso);
  }

  Future<void> _sincronizar() async {
    // === PASO 0: Conectar WiFi ===
    try {
      final redActual = await widget.wifiNativo.redActual();
      if (redActual != widget.nodo.ssid) {
        await widget.wifiNativo.conectar(ssid: widget.nodo.ssid);
      }
    } on WifiException catch (e) {
      if (mounted) setState(() { _conError = true; _mensajeError = e.mensaje; _completado = true; });
      return;
    }

    // === PASO 1: Verificar propiedad ===
    _avanzar(1);
    final wifi = ConexionWiFi();
    try {
      final claimInfo = await wifi.getClaim();
      final bool isClaimed = claimInfo['claimed'] as bool? ?? false;

      if (!isClaimed && widget.esPropietarioPrevio) {
        await widget.wifiNativo.desconectar();
        if (mounted) setState(() { _esperandoReset = true; });
        return;
      }

      final ok = await wifi.setClaim(widget.deviceToken);
      if (!ok) {
        await widget.wifiNativo.desconectar();
        if (mounted) setState(() {
          _conError = true;
          _mensajeError = AppStrings.of(appLanguage.value).nodoBloqueado;
          _completado = true;
        });
        return;
      }
      if (!isClaimed) _claimNuevo = true;
    } catch (_) {
      // Firmware sin soporte de claim: continuar sin restricción
    }

    await _continuarDescarga(wifi);
  }

  Future<void> _continuarDescarga(ConexionWiFi wifi) async {
    // === PASOS 2-4: Descargar e importar ===
    _avanzar(2);
    final resultado = await wifi.descargarTodosYEliminar((jsonStr) async {
      _avanzar(3);
      await JsonReaderWiFi(ssid: widget.nodo.ssid).importJsonFromString(jsonStr);
      _avanzar(4);
    });

    await widget.wifiNativo.desconectar();

    if (mounted) {
      setState(() {
        _completado = true;
        _archivos = resultado.archivosSincronizados;
        if (!resultado.exito) { _conError = true; _mensajeError = resultado.mensaje; }
      });
    }
  }

  Future<void> _reclamarYContinuar() async {
    if (mounted) setState(() { _esperandoReset = false; _pasoActual = 0; });

    try {
      await widget.wifiNativo.conectar(ssid: widget.nodo.ssid);
    } on WifiException catch (e) {
      if (mounted) setState(() { _conError = true; _mensajeError = e.mensaje; _completado = true; });
      return;
    }

    _avanzar(1);
    final wifi = ConexionWiFi();
    try {
      final ok = await wifi.setClaim(widget.deviceToken);
      if (!ok) {
        await widget.wifiNativo.desconectar();
        if (mounted) setState(() {
          _conError = true;
          _mensajeError = AppStrings.of(appLanguage.value).reclamarFallo;
          _completado = true;
        });
        return;
      }
      _claimNuevo = true;
    } catch (_) {}

    await _continuarDescarga(wifi);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);
    final pasos = [
      s.pasoConectando,
      s.pasoVerificando,
      s.pasoListando,
      s.pasoDescargando,
      s.pasoGuardando,
    ];

    return AlertDialog(
      title: Text(_nombreNodo(widget.nodo.ssid)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...pasos.asMap().entries.map((e) => _filaPaso(e.key, e.value)),
          if (_esperandoReset) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.resetFisicoMensaje,
                    style: const TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ]),
            ),
          ],
          if (_completado && !_conError) ...[
            const SizedBox(height: 16),
            Text(
              s.archivosImportados(_archivos),
              style: const TextStyle(
                  color: AppLightTheme.botonPrincipal,
                  fontWeight: FontWeight.w500),
            ),
          ],
          if (_completado && _conError) ...[
            const SizedBox(height: 16),
            Text(_mensajeError ?? 'Error',
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: _esperandoReset
          ? [
              TextButton(
                onPressed: () => Navigator.pop(
                    context, const _SyncResultado(resetFisicoDetectado: true)),
                child: Text(s.cancelar),
              ),
              FilledButton(
                onPressed: _reclamarYContinuar,
                style: FilledButton.styleFrom(
                    backgroundColor: AppLightTheme.botonPrincipal),
                child: Text(s.reclamarDeNuevo),
              ),
            ]
          : _completado
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(
                        context, _SyncResultado(claimNuevo: _claimNuevo)),
                    child: Text(s.cerrar),
                  ),
                ]
              : null,
    );
  }

  Widget _filaPaso(int indice, String texto) {
    final completado = _pasoActual > indice || (_completado && !_conError);
    final activo = _pasoActual == indice && !_completado && !_esperandoReset;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 24,
          height: 24,
          child: activo
              ? const CircularProgressIndicator(strokeWidth: 2.5)
              : completado
                  ? const Icon(Icons.check_circle,
                      color: AppLightTheme.botonPrincipal, size: 22)
                  : Icon(Icons.radio_button_unchecked,
                      color: Colors.grey.shade300, size: 22),
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
//  DIÁLOGO: Liberar propiedad de un nodo
// ══════════════════════════════════════════════════════════════

class _LiberarDialog extends StatefulWidget {
  final String ssid;
  final WifiNativoService wifiNativo;
  final String deviceToken;

  const _LiberarDialog({
    required this.ssid,
    required this.wifiNativo,
    required this.deviceToken,
  });

  @override
  State<_LiberarDialog> createState() => _LiberarDialogState();
}

class _LiberarDialogState extends State<_LiberarDialog> {
  bool _conectando = true;
  bool _completado = false;
  bool _exito = false;
  String? _error;

  String _nombreNodo(String ssid) =>
      ssid.replaceFirst(RegExp(r'SOILAIR_', caseSensitive: false), '');

  @override
  void initState() {
    super.initState();
    _liberar();
  }

  Future<void> _liberar() async {
    try {
      final redActual = await widget.wifiNativo.redActual();
      if (redActual != widget.ssid) {
        await widget.wifiNativo.conectar(ssid: widget.ssid);
      }
      if (mounted) setState(() => _conectando = false);

      final ok = await ConexionWiFi().deleteClaim(widget.deviceToken);
      await widget.wifiNativo.desconectar();

      if (mounted) {
        final s = AppStrings.of(appLanguage.value);
        setState(() {
          _exito = ok;
          _error = ok ? null : s.nodoRechazado;
          _completado = true;
        });
      }
    } on WifiException catch (e) {
      if (mounted) setState(() { _error = e.mensaje; _completado = true; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _completado = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);
    return AlertDialog(
      title: Text('${s.liberar} ${_nombreNodo(widget.ssid)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_completado) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(_conectando ? s.conectandoNodo : s.enviandoSolicitud),
          ] else if (_exito) ...[
            const Icon(Icons.lock_open, color: AppLightTheme.botonPrincipal, size: 44),
            const SizedBox(height: 10),
            Text(
              s.nodeLiberadoOk,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 44),
            const SizedBox(height: 10),
            Text(_error ?? 'Error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: _completado
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context, _exito),
                child: Text(s.cerrar),
              ),
            ]
          : null,
    );
  }
}
