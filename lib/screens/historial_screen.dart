import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/main.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/theme/app_light_theme.dart';
import 'package:soilair/widgets/base_scaffold.dart';

// ── Modelo de variable ─────────────────────────────────────────

class _Variable {
  final String campo;
  final String etiqueta;
  final String unidad;
  final Color color;
  const _Variable({
    required this.campo,
    required this.etiqueta,
    required this.unidad,
    required this.color,
  });
}

List<_Variable> _varsPrimario(AppStrings s) => [
  _Variable(campo: 'humedad',     etiqueta: s.humedadSuelo,   unidad: '%',     color: const Color(0xFF378ADD)),
  _Variable(campo: 'temperatura', etiqueta: s.tempSuelo,      unidad: '°C',    color: const Color(0xFFD85A30)),
  _Variable(campo: 'ph',          etiqueta: 'pH',              unidad: '',      color: const Color(0xFF7F77DD)),
  _Variable(campo: 'ec',          etiqueta: s.conductividad,   unidad: 'mS/cm', color: const Color(0xFF639922)),
  _Variable(campo: 'n',           etiqueta: s.nitrogeno,       unidad: 'mg/kg', color: const Color(0xFF1D9E75)),
  _Variable(campo: 'p',           etiqueta: s.fosforo,         unidad: 'mg/kg', color: const Color(0xFFBA7517)),
  _Variable(campo: 'k',           etiqueta: s.potasio,         unidad: 'mg/kg', color: const Color(0xFFD4537E)),
  _Variable(campo: 'radiacion',   etiqueta: s.radiacion,       unidad: 'lux',   color: const Color(0xFFEF9F27)),
];

List<_Variable> _varsAmbiental(AppStrings s) => [
  _Variable(campo: 'temperatura', etiqueta: s.tempAire,    unidad: '°C', color: const Color(0xFFD85A30)),
  _Variable(campo: 'humedad',     etiqueta: s.humedadAire, unidad: '%',  color: const Color(0xFF378ADD)),
];

// ── Pantalla principal ─────────────────────────────────────────

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _db = DatabaseHelper();
  int _rangoIdx = 1; // índice en la lista de rangos
  List<String> _idsPrimarios = [];
  Map<String, String?> _nombresSensores = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarSensores();
  }

  Future<void> _cargarSensores() async {
    final ids = await _db.getTodosSensoresPrimarios();
    final nombres = await _db.getNombresSensores();
    setState(() {
      _idsPrimarios = ids.map((r) => r['id'] as String).toList();
      _nombresSensores = nombres;
      _cargando = false;
    });
  }

  String _nombreSensor(String id, AppStrings s) {
    final nombre = _nombresSensores[id];
    if (nombre != null) return nombre;
    if (id.startsWith('p')) {
      final n = id.substring(1);
      return n == '1' ? s.sensorPrincipal : s.sensorN(int.tryParse(n) ?? 0);
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);
    final rangos = [s.rangoSemana, s.rangoTreinta, s.rangoNoventa, s.rangoTodo];

    return BaseScaffold(
      title: s.navHistorial,
      body: Column(children: [
        _barraRango(s, rangos),
        const Divider(height: 1),
        Expanded(
          child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _SensorSection(
                    titulo: s.condicionesAmbientales,
                    sensorId: '__ambiental__',
                    esPrimario: false,
                    vars: _varsAmbiental(s),
                    rango: rangos[_rangoIdx],
                    s: s,
                  ),
                  ..._idsPrimarios.map((id) => _SensorSection(
                    titulo: _nombreSensor(id, s),
                    sensorId: id,
                    esPrimario: true,
                    vars: _varsPrimario(s),
                    rango: rangos[_rangoIdx],
                    s: s,
                  )),
                  if (_idsPrimarios.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        Icon(Icons.sensors_off, size: 48,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(s.sinSensoresRegistrados,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
                        const SizedBox(height: 6),
                        Text(s.sincronizaParaLecturas,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                      ]),
                    ),
                ],
              ),
        ),
      ]),
    );
  }

  Widget _barraRango(AppStrings s, List<String> rangos) {
    final primary   = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline   = Theme.of(context).colorScheme.outline;

    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        Text('${s.periodo}:',
            style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.5))),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(rangos.length, (i) {
                final sel = i == _rangoIdx;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _rangoIdx = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? primary.withValues(alpha: 0.12) : Colors.transparent,
                        border: Border.all(
                            color: sel ? primary : outline.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(rangos[i], style: TextStyle(
                        fontSize: 12,
                        color: sel ? primary : onSurface.withValues(alpha: 0.55),
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      )),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Sección por sensor ─────────────────────────────────────────

class _SensorSection extends StatefulWidget {
  final String titulo;
  final String sensorId;
  final bool esPrimario;
  final List<_Variable> vars;
  final String rango;
  final AppStrings s;

  const _SensorSection({
    required this.titulo,
    required this.sensorId,
    required this.esPrimario,
    required this.vars,
    required this.rango,
    required this.s,
  });

  @override
  State<_SensorSection> createState() => _SensorSectionState();
}

class _SensorSectionState extends State<_SensorSection> {
  final _db = DatabaseHelper();
  late String _campSel;
  List<FlSpot> _puntos = [];
  List<int> _timestamps = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _campSel = widget.vars.first.campo;
    _cargarDatos();
  }

  @override
  void didUpdateWidget(covariant _SensorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rango != widget.rango) _cargarDatos();
  }

  _Variable get _varSel =>
      widget.vars.firstWhere((v) => v.campo == _campSel,
          orElse: () => widget.vars.first);

  DateTime? _fechaDesde() {
    final ahora = DateTime.now();
    final s = widget.s;
    if (widget.rango == s.rangoSemana)   return ahora.subtract(const Duration(days: 7));
    if (widget.rango == s.rangoTreinta)  return ahora.subtract(const Duration(days: 30));
    if (widget.rango == s.rangoNoventa)  return ahora.subtract(const Duration(days: 90));
    return null;
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final desde = _fechaDesde();
      List<Map<String, dynamic>> filas;

      if (widget.sensorId == '__ambiental__') {
        filas = await _db.getHistorialAmbiental(limite: 200, desde: desde);
      } else {
        filas = await _db.getHistorialSensorPrimario(
            sensorId: widget.sensorId,
            campo: _varSel.campo,
            limite: 200,
            desde: desde);
      }

      if (filas.isEmpty) {
        setState(() { _puntos = []; _timestamps = []; _cargando = false; });
        return;
      }

      _timestamps = filas.map((f) => f['timestamp'] as int).toList();
      final puntos = <FlSpot>[];
      for (int i = 0; i < filas.length; i++) {
        final raw = filas[i][_varSel.campo];
        final double? y =
            raw is num ? raw.toDouble() : double.tryParse(raw.toString());
        if (y != null && y.isFinite) puntos.add(FlSpot(i.toDouble(), y));
      }
      setState(() { _puntos = puntos; _cargando = false; });
    } catch (_) {
      setState(() { _puntos = []; _cargando = false; });
    }
  }

  String _etiquetaX(int idx) {
    if (idx < 0 || idx >= _timestamps.length) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(_timestamps[idx] * 1000);
    final s = widget.s;
    if (widget.rango == s.rangoSemana)
      return '${dt.day}/${dt.month}\n${_p(dt.hour)}:${_p(dt.minute)}';
    return '${dt.day}/${dt.month}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(children: [
            Icon(widget.esPrimario ? Icons.sensors : Icons.air,
                size: 18, color: AppLightTheme.botonPrincipal),
            const SizedBox(width: 8),
            Text(widget.titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),

        SizedBox(
          height: 34,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: widget.vars.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final v = widget.vars[i];
              final sel = v.campo == _campSel;
              return GestureDetector(
                onTap: () {
                  setState(() => _campSel = v.campo);
                  _cargarDatos();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? v.color.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(
                        color: sel
                            ? v.color
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                        width: sel ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(v.etiqueta, style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel
                        ? v.color
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  )),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_puntos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(s.sinDatosPeriodo,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 13)),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _resumen(s),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _grafica(),
          ),
        ],

        const Divider(height: 32),
      ],
    );
  }

  Widget _resumen(AppStrings s) {
    final ys = _puntos.map((p) => p.y).toList();
    final mn  = ys.reduce((a, b) => a < b ? a : b);
    final mx  = ys.reduce((a, b) => a > b ? a : b);
    final avg = ys.reduce((a, b) => a + b) / ys.length;
    final u = _varSel.unidad;
    final c = _varSel.color;
    String f(double v) =>
        u.isEmpty ? v.toStringAsFixed(1) : '${v.toStringAsFixed(1)} $u';

    return Row(children: [
      _stat(s.ultimo,   f(ys.last), c),
      const SizedBox(width: 8),
      _stat(s.promedio, f(avg), Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      const SizedBox(width: 8),
      _stat(s.min,      f(mn), Colors.blue.shade400),
      const SizedBox(width: 8),
      _stat(s.max,      f(mx), Colors.orange.shade600),
    ]);
  }

  Widget _stat(String label, String valor, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
        const SizedBox(height: 3),
        Text(valor,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
            overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  Widget _grafica() {
    final color  = _varSel.color;
    final unidad = _varSel.unidad;
    final ys     = _puntos.map((p) => p.y).toList();
    final minY   = ys.reduce((a, b) => a < b ? a : b);
    final maxY   = ys.reduce((a, b) => a > b ? a : b);
    final pad    = (maxY - minY).abs() < 0.01 ? 1.0 : (maxY - minY) * 0.15;
    final paso   = (_puntos.length / 7).ceil().clamp(1, _puntos.length);

    final gridColor    = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    final borderColor  = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25);
    final axisColor    = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gridColor),
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: borderColor),
              left:   BorderSide(color: borderColor),
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) {
                if (v == meta.min || v == meta.max)
                  return const SizedBox.shrink();
                return Text(v.toStringAsFixed(1),
                    style: TextStyle(fontSize: 10, color: axisColor));
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
                      style: TextStyle(fontSize: 9, color: axisColor),
                      textAlign: TextAlign.center),
                );
              },
            )),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((sp) {
                final ts =
                    _etiquetaX(sp.x.toInt()).replaceAll('\n', ' ');
                return LineTooltipItem(
                  '${sp.y.toStringAsFixed(2)}${unidad.isNotEmpty ? ' $unidad' : ''}\n',
                  TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                  children: [
                    TextSpan(
                        text: ts,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.normal))
                  ],
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
                    radius: 3,
                    color: color,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }
}
