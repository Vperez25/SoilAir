import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:soilair/services/database.dart';

class ReportService {
  static final _db = DatabaseHelper();

  static const _verde       = PdfColor.fromInt(0xFF2E7D32);
  static const _verdeClaro  = PdfColor.fromInt(0xFFE8F5E9);
  static const _rojo        = PdfColor.fromInt(0xFFC62828);
  static const _naranja     = PdfColor.fromInt(0xFFE65100);
  static const _gris        = PdfColor.fromInt(0xFF616161);
  static const _grisClaro   = PdfColor.fromInt(0xFFF5F5F5);
  static const _negro       = PdfColor.fromInt(0xFF212121);
  static const _azul        = PdfColor.fromInt(0xFF1565C0);
  static const _azulClaro   = PdfColor.fromInt(0xFFE3F2FD);
  static const _azulOscuro  = PdfColor.fromInt(0xFF0D47A1);
  static const _naranjaTend = PdfColor.fromInt(0xFFBF360C);

  // Colores por parámetro (mismos que historial_screen)
  static const _colorHumedad     = PdfColor.fromInt(0xFF378ADD);
  static const _colorTemperatura = PdfColor.fromInt(0xFFD85A30);
  static const _colorPh          = PdfColor.fromInt(0xFF7F77DD);
  static const _colorEc          = PdfColor.fromInt(0xFF639922);
  static const _colorN           = PdfColor.fromInt(0xFF1D9E75);
  static const _colorP           = PdfColor.fromInt(0xFFBA7517);
  static const _colorK           = PdfColor.fromInt(0xFFD4537E);
  static const _colorRadiacion   = PdfColor.fromInt(0xFFEF9F27);

  static const _paramsPrimario = {
    'n':           'Nitrógeno (mg/kg)',
    'p':           'Fósforo (mg/kg)',
    'k':           'Potasio (mg/kg)',
    'ph':          'pH',
    'humedad':     'Humedad (%)',
    'ec':          'Conductividad (mS/cm)',
    'temperatura': 'Temperatura (°C)',
    'radiacion':   'Radiación (lux)',
  };

  static const _coloresPorParam = <String, PdfColor>{
    'n':           _colorN,
    'p':           _colorP,
    'k':           _colorK,
    'ph':          _colorPh,
    'humedad':     _colorHumedad,
    'ec':          _colorEc,
    'temperatura': _colorTemperatura,
    'radiacion':   _colorRadiacion,
  };

  static String _fmt(num? v) =>
      v == null ? '-' : v.toDouble().toStringAsFixed(1);

  static String _p(int n) => n.toString().padLeft(2, '0');

  static String _fmtFecha(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.day}/${_p(dt.month)}/${dt.year}';
  }

  static String _fmtFechaHora(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.day}/${_p(dt.month)}/${dt.year} ${_p(dt.hour)}:${_p(dt.minute)}';
  }

  static String _dbKey(String campo) =>
      campo == 'temperatura' ? 'temp' : campo;

  static _EstadoParam _estado(double? val, Map<String, dynamic>? rangos, String campo) {
    if (val == null || rangos == null) { return _EstadoParam.sinDatos; }
    final k      = _dbKey(campo);
    final optMin = (rangos['${k}_optimo_min']  as num?)?.toDouble();
    final optMax = (rangos['${k}_optimo_max']  as num?)?.toDouble();
    final critMin= (rangos['${k}_critico_min'] as num?)?.toDouble();
    final critMax= (rangos['${k}_critico_max'] as num?)?.toDouble();
    if (optMin != null && optMax != null && val >= optMin && val <= optMax) {
      return _EstadoParam.ok;
    }
    if ((critMin != null && val < critMin) || (critMax != null && val > critMax)) {
      return _EstadoParam.critico;
    }
    return _EstadoParam.fuera;
  }

  static String _rangoStr(Map<String, dynamic>? rangos, String campo) {
    if (rangos == null) { return 'Sin cultivo asignado'; }
    final k  = _dbKey(campo);
    final mn = (rangos['${k}_optimo_min'] as num?)?.toDouble();
    final mx = (rangos['${k}_optimo_max'] as num?)?.toDouble();
    if (mn == null || mx == null) { return 'No definido'; }
    return '${_fmt(mn)} – ${_fmt(mx)}';
  }

  static Map<String, List<Map<String, dynamic>>> _agruparPorDia(
      List<Map<String, dynamic>> filas) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in filas) {
      final key = _fmtFecha(r['timestamp'] as int);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  static double? _avg(List<Map<String, dynamic>> filas, String campo) {
    final vals = filas
        .map((r) => (r[campo] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (vals.isEmpty) { return null; }
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  // Extrae valores de un campo del historial y reduce a max 60 puntos para sparklines
  static List<double> _extraerVals(List<Map<String, dynamic>> historial, String campo) {
    final all = historial
        .map((r) => (r[campo] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (all.length <= 60) { return all; }
    // Submuestreo uniforme
    final step = all.length / 60;
    return List.generate(60, (i) => all[(i * step).round().clamp(0, all.length - 1)]);
  }

  // Estadísticas simples de un campo
  static _Stats? _calcStats(List<Map<String, dynamic>> historial, String campo) {
    final vals = historial
        .map((r) => (r[campo] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (vals.isEmpty) { return null; }
    final mn  = vals.reduce((a, b) => a < b ? a : b);
    final mx  = vals.reduce((a, b) => a > b ? a : b);
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    return _Stats(min: mn, avg: avg, max: mx, lecturas: vals.length);
  }

  // ── Sparkline ────────────────────────────────────────────────────

  static pw.Widget _sparklineCard(String label, List<double> vals, PdfColor color,
      {double width = 245, double height = 52}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _gris)),
        pw.SizedBox(height: 2),
        vals.length < 2
            ? pw.Container(
                width: width,
                height: height,
                color: _grisClaro,
                child: pw.Center(
                  child: pw.Text('Sin datos',
                      style: pw.TextStyle(fontSize: 8, color: _gris)),
                ),
              )
            : pw.CustomPaint(
                size: PdfPoint(width, height),
                painter: (PdfGraphics canvas, PdfPoint size) {
                  _drawSparkline(canvas, size, vals, color);
                },
              ),
      ],
    );
  }

  static void _drawSparkline(
      PdfGraphics canvas, PdfPoint size, List<double> vals, PdfColor color) {
    final mn    = vals.reduce((a, b) => a < b ? a : b);
    final mx    = vals.reduce((a, b) => a > b ? a : b);
    final range = (mx - mn).abs();

    double toX(int i) => i * size.x / (vals.length - 1);
    double toY(double v) {
      if (range == 0) { return size.y / 2; }
      return (v - mn) / range * (size.y - 10) + 5;
    }

    canvas.setFillColor(const PdfColor(0.976, 0.976, 0.976));
    canvas.drawRect(0, 0, size.x, size.y);
    canvas.fillPath();

    canvas.setFillColor(PdfColor(color.red, color.green, color.blue, 0.18));
    canvas.moveTo(toX(0), 0);
    canvas.lineTo(toX(0), toY(vals[0]));
    for (int i = 1; i < vals.length; i++) {
      canvas.lineTo(toX(i), toY(vals[i]));
    }
    canvas.lineTo(toX(vals.length - 1), 0);
    canvas.closePath();
    canvas.fillPath();

    canvas.setStrokeColor(color);
    canvas.setLineWidth(1.5);
    canvas.moveTo(toX(0), toY(vals[0]));
    for (int i = 1; i < vals.length; i++) {
      canvas.lineTo(toX(i), toY(vals[i]));
    }
    canvas.strokePath();

    canvas.setFillColor(color);
    for (final idx in [0, vals.length - 1]) {
      canvas.drawEllipse(toX(idx), toY(vals[idx]), 2.5, 2.5);
      canvas.fillPath();
    }
  }

  // ── Portada ──────────────────────────────────────────────────────

  static pw.Page _portada(
    String fechaHora,
    List<String> sensorIds,
    Map<String, String?> nombresSensores,
  ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: _verde,
            padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SOILAIR',
                    style: pw.TextStyle(
                        fontSize: 34, fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text('Reporte histórico de monitoreo de suelo',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.white)),
              ],
            ),
          ),
          pw.SizedBox(height: 36),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Generado el $fechaHora',
                    style: pw.TextStyle(fontSize: 12, color: _gris)),
                pw.SizedBox(height: 28),
                pw.Text('Sensores incluidos',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold, color: _negro)),
                pw.SizedBox(height: 12),
                ...sensorIds.map((id) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Row(children: [
                        pw.Container(
                          width: 8, height: 8,
                          decoration: pw.BoxDecoration(
                              color: _verde, shape: pw.BoxShape.circle),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(nombresSensores[id] ?? id,
                            style: pw.TextStyle(fontSize: 12, color: _negro)),
                      ]),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección por sensor ────────────────────────────────────────────

  static List<pw.Widget> _seccionSensor(
    String nombre,
    String cultivo,
    Map<String, dynamic>? rangos,
    Map<String, dynamic> ultimaMedicion,
    List<Map<String, dynamic>> historial,
    String periodoLabel,
  ) {
    final widgets = <pw.Widget>[];

    // Encabezado
    widgets.add(pw.Container(
      color: _verdeClaro,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(nombre,
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold, color: _verde)),
              pw.Text('Cultivo: $cultivo',
                  style: pw.TextStyle(fontSize: 11, color: _gris)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text('$periodoLabel  ·  ${historial.length} lecturas registradas',
              style: pw.TextStyle(fontSize: 9, color: _gris)),
        ],
      ),
    ));
    widgets.add(pw.SizedBox(height: 8));

    // ── Tabla: última lectura ────────────────────────────────────
    widgets.add(pw.Text('Última lectura',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _negro)));
    widgets.add(pw.SizedBox(height: 4));

    final campos = _paramsPrimario.keys.toList();

    widgets.add(pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _verde),
          children: ['Parámetro', 'Valor', 'Rango óptimo', 'Estado']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ))
              .toList(),
        ),
        ...campos.asMap().entries.map((entry) {
          final i       = entry.key;
          final campo   = entry.value;
          final val     = (ultimaMedicion[campo] as num?)?.toDouble();
          final est     = _estado(val, rangos, campo);
          final bg      = i.isOdd ? _grisClaro : PdfColors.white;
          final estColor= est == _EstadoParam.ok ? _verde
              : est == _EstadoParam.critico ? _rojo
              : est == _EstadoParam.fuera   ? _naranja
              : _gris;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Text(_paramsPrimario[campo]!,
                    style: pw.TextStyle(fontSize: 9, color: _negro)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Text(_fmt(val),
                    style: pw.TextStyle(fontSize: 9, color: _negro)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Text(_rangoStr(rangos, campo),
                    style: pw.TextStyle(fontSize: 9, color: _negro)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Text(est.label,
                    style: pw.TextStyle(
                        fontSize: 9, color: estColor,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ],
          );
        }),
      ],
    ));

    // ── Tabla: resumen histórico (min / prom / max) ───────────────
    if (historial.length >= 2) {
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(pw.Text('Resumen histórico',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _negro)));
      widgets.add(pw.SizedBox(height: 4));

      final statsRows = <pw.TableRow>[];
      statsRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: _gris),
        children: ['Parámetro', 'Mín', 'Promedio', 'Máx', 'Lecturas']
            .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Text(h,
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ))
            .toList(),
      ));

      for (int i = 0; i < campos.length; i++) {
        final campo  = campos[i];
        final stats  = _calcStats(historial, campo);
        final bg     = i.isOdd ? _grisClaro : PdfColors.white;
        statsRows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            _celdaStat(_paramsPrimario[campo]!, bold: false),
            _celdaStat(stats == null ? '-' : _fmt(stats.min)),
            _celdaStat(stats == null ? '-' : _fmt(stats.avg)),
            _celdaStat(stats == null ? '-' : _fmt(stats.max)),
            _celdaStat(stats == null ? '-' : '${stats.lecturas}'),
          ],
        ));
      }

      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(1.5),
        },
        children: statsRows,
      ));

      // ── Grilla de sparklines — un gráfico por parámetro ──────────
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(pw.Text('Tendencias históricas',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _negro)));
      widgets.add(pw.SizedBox(height: 6));

      // Pares de parámetros: 2 por fila
      final pares = <List<String>>[];
      for (int i = 0; i < campos.length; i += 2) {
        pares.add(i + 1 < campos.length
            ? [campos[i], campos[i + 1]]
            : [campos[i]]);
      }

      for (final par in pares) {
        widgets.add(pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: [
            for (int i = 0; i < par.length; i++) ...[
              if (i > 0) pw.SizedBox(width: 12),
              _sparklineCard(
                _paramsPrimario[par[i]]!,
                _extraerVals(historial, par[i]),
                _coloresPorParam[par[i]] ?? _gris,
              ),
            ],
          ],
        ));
        widgets.add(pw.SizedBox(height: 8));
      }
    }

    widgets.add(pw.SizedBox(height: 16));
    return widgets;
  }

  static pw.Widget _celdaStat(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9, color: _negro,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  // ── Sección ambiental ─────────────────────────────────────────────

  static List<pw.Widget> _seccionAmbiental(List<Map<String, dynamic>> amb) {
    if (amb.isEmpty) { return []; }
    final widgets = <pw.Widget>[];

    widgets.add(pw.Container(
      color: _azulClaro,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Condiciones Ambientales',
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold, color: _azulOscuro)),
          pw.SizedBox(height: 2),
          pw.Text('${amb.length} lecturas registradas',
              style: pw.TextStyle(fontSize: 9, color: _gris)),
        ],
      ),
    ));
    widgets.add(pw.SizedBox(height: 8));

    // Sparklines ambientales
    final tempVals = _extraerVals(amb, 'temperatura');
    final humVals  = _extraerVals(amb, 'humedad');

    if (tempVals.length >= 2 || humVals.length >= 2) {
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          if (tempVals.length >= 2) ...[
            _sparklineCard('Temperatura Aire (°C)', tempVals, _naranjaTend),
            pw.SizedBox(width: 12),
          ],
          if (humVals.length >= 2)
            _sparklineCard('Humedad Aire (%)', humVals, _azul),
        ],
      ));
      widgets.add(pw.SizedBox(height: 10));
    }

    // Tabla de promedios diarios
    final dias   = _agruparPorDia(amb);
    final fechas = dias.keys.toList();

    widgets.add(pw.Text('Promedios diarios',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _negro)));
    widgets.add(pw.SizedBox(height: 4));

    widgets.add(pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _azulOscuro),
          children: ['Fecha', 'Temp. Aire (°C)', 'Humedad Aire (%)']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ))
              .toList(),
        ),
        ...fechas.asMap().entries.map((e) {
          final bg   = e.key.isOdd ? _grisClaro : PdfColors.white;
          final temp = _avg(dias[e.value]!, 'temperatura');
          final hum  = _avg(dias[e.value]!, 'humedad');
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [e.value, _fmt(temp), _fmt(hum)]
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: pw.Text(cell,
                          style: pw.TextStyle(fontSize: 9, color: _negro)),
                    ))
                .toList(),
          );
        }),
      ],
    ));

    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  // ── Generación principal ──────────────────────────────────────────

  static Future<void> generarYCompartir({
    required List<String> sensorIds,
    required Map<String, String?> nombresSensores,
  }) async {
    final doc       = pw.Document();
    final ts        = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final fechaHora = _fmtFechaHora(ts);

    doc.addPage(_portada(fechaHora, sensorIds, nombresSensores));

    final sensorWidgets = <pw.Widget>[];
    for (final id in sensorIds) {
      final nombre  = nombresSensores[id] ?? id;
      final rangos  = await _db.getRangosCultivoAsignado(id);
      final cultivo = rangos?['nombre'] as String? ?? 'Sin cultivo asignado';
      final filas   = await _db.getHistorialCompletoSensorPrimario(id);
      if (filas.isEmpty) { continue; }

      // Periodo cubierto
      final tsMin   = filas.first['timestamp'] as int;
      final tsMax   = filas.last['timestamp']  as int;
      final inicio  = _fmtFecha(tsMin);
      final fin     = _fmtFecha(tsMax);
      final periodo = inicio == fin ? inicio : '$inicio – $fin';

      sensorWidgets.addAll(_seccionSensor(
        nombre, cultivo, rangos, filas.last, filas, periodo));
    }

    if (sensorWidgets.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SOILAIR',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: _verde)),
              pw.Text('Historial de sensores',
                  style: pw.TextStyle(fontSize: 10, color: _gris)),
            ],
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
        ]),
        build: (_) => sensorWidgets,
      ));
    }

    final amb = await _db.getHistorialCompletoAmbiental();
    final ambWidgets = _seccionAmbiental(amb);
    if (ambWidgets.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SOILAIR',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: _verde)),
              pw.Text('Condiciones ambientales',
                  style: pw.TextStyle(fontSize: 10, color: _gris)),
            ],
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
        ]),
        build: (_) => ambWidgets,
      ));
    }

    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte_soilair.pdf');
    await file.writeAsBytes(await doc.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Reporte SoilAir',
    );
  }
}

// ── Modelos internos ──────────────────────────────────────────────

enum _EstadoParam { ok, fuera, critico, sinDatos }

extension _EstadoLabel on _EstadoParam {
  String get label {
    switch (this) {
      case _EstadoParam.ok:       return 'OK';
      case _EstadoParam.fuera:    return 'Fuera de rango';
      case _EstadoParam.critico:  return 'Crítico';
      case _EstadoParam.sinDatos: return '-';
    }
  }
}

class _Stats {
  final double min;
  final double avg;
  final double max;
  final int lecturas;
  const _Stats({required this.min, required this.avg, required this.max, required this.lecturas});
}
