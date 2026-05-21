import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/theme/app_light_theme.dart';
import 'package:soilair/widgets/base_scaffold.dart';

// ── Modelos ────────────────────────────────────────────────────

class _Variable {
  final String campo;
  final String etiqueta;
  final String unidad;
  final Color color;
  const _Variable({required this.campo, required this.etiqueta, required this.unidad, required this.color});
}

class _SensorOpcion {
  final String id;
  final String nombre;
  final bool esPrimario;
  const _SensorOpcion({required this.id, required this.nombre, required this.esPrimario});
}

// ── Pantalla ───────────────────────────────────────────────────

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _db = DatabaseHelper();

  List<_SensorOpcion> _sensores = [];
  _SensorOpcion? _sensorSel;
  _Variable? _varSel;

  static const _varsPrimario = [
    _Variable(campo: 'humedad',     etiqueta: 'Humedad suelo', unidad: '%',     color: Color(0xFF378ADD)),
    _Variable(campo: 'temperatura', etiqueta: 'Temp. suelo',   unidad: '°C',    color: Color(0xFFD85A30)),
    _Variable(campo: 'ph',          etiqueta: 'pH',             unidad: '',      color: Color(0xFF7F77DD)),
    _Variable(campo: 'ec',          etiqueta: 'Conductividad',  unidad: 'mS/cm', color: Color(0xFF639922)),
    _Variable(campo: 'n',           etiqueta: 'Nitrógeno',      unidad: 'mg/kg', color: Color(0xFF1D9E75)),
    _Variable(campo: 'p',           etiqueta: 'Fósforo',        unidad: 'mg/kg', color: Color(0xFFBA7517)),
    _Variable(campo: 'k',           etiqueta: 'Potasio',        unidad: 'mg/kg', color: Color(0xFFD4537E)),
    _Variable(campo: 'radiacion',   etiqueta: 'Radiación',      unidad: 'lux',   color: Color(0xFFEF9F27)),
  ];

  static const _varsSecundario = [
    _Variable(campo: 'humedad',     etiqueta: 'Humedad',       unidad: '%',     color: Color(0xFF378ADD)),
    _Variable(campo: 'temperatura', etiqueta: 'Temperatura',   unidad: '°C',    color: Color(0xFFD85A30)),
    _Variable(campo: 'ec',          etiqueta: 'Conductividad', unidad: 'mS/cm', color: Color(0xFF639922)),
  ];

  static const _varsAmbiental = [
    _Variable(campo: 'temperatura', etiqueta: 'Temp. aire',   unidad: '°C', color: Color(0xFFD85A30)),
    _Variable(campo: 'humedad',     etiqueta: 'Humedad aire', unidad: '%',  color: Color(0xFF378ADD)),
  ];

  static const _rangos = ['7 días', '30 días', '90 días', 'Todo'];
  String _rango = '30 días';

  List<FlSpot> _puntos = [];
  List<int> _timestamps = [];
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSensores();
  }

  List<_Variable> _varsParaSensor(_SensorOpcion s) {
    if (s.id == '__ambiental__') return _varsAmbiental;
    if (s.esPrimario) return _varsPrimario;
    return _varsSecundario;
  }

  Future<void> _cargarSensores() async {
    final primarios = await _db.getSensoresConNombre();
    final secundariosRaw = await _db.getSensoresSecundariosConPrimario();

    final lista = <_SensorOpcion>[
      const _SensorOpcion(id: '__ambiental__', nombre: 'Ambiente (aire)', esPrimario: false),
      ...primarios.map((s) => _SensorOpcion(
            id: s['id'] as String,
            nombre: s['nombre'] as String? ?? s['id'] as String,
            esPrimario: true)),
      ...secundariosRaw.map((s) => _SensorOpcion(
            id: s['sec_id'] as String,
            nombre: s['primario_nombre'] != null
                ? '${s['primario_nombre']} › ${s['sec_id']}'
                : s['sec_id'] as String,
            esPrimario: false)),
    ];

    setState(() {
      _sensores = lista;
      if (lista.isNotEmpty) {
        _sensorSel = lista.first;
        _varSel = _varsParaSensor(lista.first).first;
      }
    });
    if (_sensorSel != null) _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (_sensorSel == null || _varSel == null) return;
    setState(() { _cargando = true; _error = null; });

    try {
      final desde = _fechaDesde();
      List<Map<String, dynamic>> filas;

      if (_sensorSel!.id == '__ambiental__') {
        filas = await _db.getHistorialAmbiental(limite: 200, desde: desde);
      } else if (_sensorSel!.esPrimario) {
        filas = await _db.getHistorialSensorPrimario(
            sensorId: _sensorSel!.id, campo: _varSel!.campo, limite: 200, desde: desde);
      } else {
        filas = await _db.getHistorialSensorSecundario(
            sensorId: _sensorSel!.id, campo: _varSel!.campo, limite: 200, desde: desde);
      }

      if (filas.isEmpty) {
        setState(() { _puntos = []; _timestamps = []; _cargando = false; });
        return;
      }

      _timestamps = filas.map((f) => f['timestamp'] as int).toList();
      final puntos = <FlSpot>[];
      for (int i = 0; i < filas.length; i++) {
        final raw = filas[i][_varSel!.campo];
        final double? y = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
        if (y != null && y.isFinite) puntos.add(FlSpot(i.toDouble(), y));
      }
      setState(() { _puntos = puntos; _cargando = false; });
    } catch (e) {
      setState(() { _error = 'Error cargando datos: $e'; _cargando = false; });
    }
  }

  DateTime? _fechaDesde() {
    final ahora = DateTime.now();
    switch (_rango) {
      case '7 días':  return ahora.subtract(const Duration(days: 7));
      case '30 días': return ahora.subtract(const Duration(days: 30));
      case '90 días': return ahora.subtract(const Duration(days: 90));
      default:        return null;
    }
  }

  String _etiquetaX(int idx) {
    if (idx < 0 || idx >= _timestamps.length) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(_timestamps[idx] * 1000);
    if (_rango == '7 días') return '${dt.day}/${dt.month}\n${_p(dt.hour)}:${_p(dt.minute)}';
    return '${dt.day}/${dt.month}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => BaseScaffold(
    title: 'Historial',
    body: Column(children: [
      _panelFiltros(),
      const Divider(height: 1),
      Expanded(child: _cuerpo()),
    ]),
  );

  Widget _panelFiltros() {
    final vars = _sensorSel != null ? _varsParaSensor(_sensorSel!) : <_Variable>[];
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Selector de sensor
        Row(children: [
          const Icon(Icons.sensors, size: 16, color: AppLightTheme.botonPrincipal),
          const SizedBox(width: 6),
          const Text('Sensor', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_SensorOpcion>(
                value: _sensorSel,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: _sensores.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.nombre, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (s) {
                  if (s == null) return;
                  setState(() { _sensorSel = s; _varSel = _varsParaSensor(s).first; });
                  _cargarDatos();
                },
              ),
            ),
          ),
        ]),

        const SizedBox(height: 8),

        // Chips de variable
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vars.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final v = vars[i];
              final sel = v.campo == _varSel?.campo;
              return GestureDetector(
                onTap: () { setState(() => _varSel = v); _cargarDatos(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? v.color.withOpacity(0.15) : Colors.transparent,
                    border: Border.all(color: sel ? v.color : Colors.grey.shade300, width: sel ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(v.etiqueta, style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel ? v.color : Colors.grey.shade600,
                  )),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Chips de rango
        SizedBox(
          height: 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _rangos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final r = _rangos[i];
              final sel = r == _rango;
              return GestureDetector(
                onTap: () { setState(() => _rango = r); _cargarDatos(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? AppLightTheme.botonPrincipal.withOpacity(0.12) : Colors.transparent,
                    border: Border.all(color: sel ? AppLightTheme.botonPrincipal : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r, style: TextStyle(
                    fontSize: 11,
                    color: sel ? AppLightTheme.botonPrincipal : Colors.grey.shade500,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  )),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_puntos.isEmpty) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.show_chart, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Sin datos para este período', style: TextStyle(color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        Text('Sincroniza con un nodo para empezar a acumular lecturas.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400), textAlign: TextAlign.center),
      ]),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _resumen(),
        const SizedBox(height: 16),
        _grafica(),
      ]),
    );
  }

  Widget _resumen() {
    final ys = _puntos.map((p) => p.y).toList();
    final min = ys.reduce((a, b) => a < b ? a : b);
    final max = ys.reduce((a, b) => a > b ? a : b);
    final avg = ys.reduce((a, b) => a + b) / ys.length;
    final ultimo = ys.last;
    final u = _varSel?.unidad ?? '';
    final c = _varSel?.color ?? AppLightTheme.botonPrincipal;
    String f(double v) => u.isEmpty ? v.toStringAsFixed(1) : '${v.toStringAsFixed(1)} $u';

    return Row(children: [
      _stat('Último', f(ultimo), c),
      const SizedBox(width: 8),
      _stat('Promedio', f(avg), Colors.grey.shade600),
      const SizedBox(width: 8),
      _stat('Mín', f(min), Colors.blue.shade400),
      const SizedBox(width: 8),
      _stat('Máx', f(max), Colors.orange.shade600),
    ]);
  }

  Widget _stat(String label, String valor, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  Widget _grafica() {
    final color = _varSel?.color ?? AppLightTheme.botonPrincipal;
    final etiqueta = _varSel?.etiqueta ?? '';
    final unidad = _varSel?.unidad ?? '';
    final ys = _puntos.map((p) => p.y).toList();
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).abs() < 0.01 ? 1.0 : (maxY - minY) * 0.15;
    final paso = (_puntos.length / 7).ceil().clamp(1, _puntos.length);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Row(children: [
            Container(width: 12, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text('$etiqueta${unidad.isNotEmpty ? ' ($unidad)' : ''}',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('${_puntos.length} lecturas', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ),
        SizedBox(
          height: 220,
          child: LineChart(LineChartData(
            minY: minY - pad,
            maxY: maxY + pad,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
                left: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min || v == meta.max) return const SizedBox.shrink();
                  return Text(v.toStringAsFixed(1), style: TextStyle(fontSize: 10, color: Colors.grey.shade500));
                },
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: paso.toDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx % paso != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_etiquetaX(idx),
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                        textAlign: TextAlign.center),
                  );
                },
              )),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final ts = _etiquetaX(s.x.toInt()).replaceAll('\n', ' ');
                  return LineTooltipItem(
                    '${s.y.toStringAsFixed(2)}${unidad.isNotEmpty ? ' $unidad' : ''}\n',
                    TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                    children: [TextSpan(text: ts, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.normal))],
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _puntos,
                isCurved: true,
                curveSmoothness: 0.3,
                color: color,
                barWidth: 2,
                dotData: FlDotData(
                  show: _puntos.length <= 30,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3, color: color, strokeWidth: 1.5, strokeColor: Colors.white),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          )),
        ),
      ]),
    );
  }
}
