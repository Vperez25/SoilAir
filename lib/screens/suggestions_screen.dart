import 'package:flutter/material.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/main.dart';
import 'package:soilair/widgets/base_scaffold.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/services/recommendations.dart';

class SugerenciasScreen extends StatefulWidget {
  const SugerenciasScreen({super.key});

  @override
  State<SugerenciasScreen> createState() => _SugerenciasScreenState();
}

class _SugerenciasScreenState extends State<SugerenciasScreen> {
  final _db = DatabaseHelper();
  List<Sugerencia> _sugerencias = [];
  bool _cargando = true;

  static const Map<String, String> _nombresParams = {
    'n':           'Nitrógeno',
    'p':           'Fósforo',
    'k':           'Potasio',
    'ph':          'pH',
    'ec':          'Conductividad',
    'humedad':     'Humedad',
    'temperatura': 'Temperatura',
    'radiacion':   'Radiación',
  };

  static const Map<String, String> _unidades = {
    'n':           'mg/kg',
    'p':           'mg/kg',
    'k':           'mg/kg',
    'ph':          '',
    'ec':          'mS/cm',
    'humedad':     '%',
    'temperatura': '°C',
    'radiacion':   'lux',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await _db.getUltimaMedicionCompleta();
    if (data == null) {
      setState(() { _sugerencias = []; _cargando = false; });
      return;
    }

    final sensores = data['primarios'] as List<dynamic>;
    final todas = <Sugerencia>[];

    for (final sensor in sensores) {
      final rangos = await _db.getRangosCultivoAsignado(sensor['id']);
      if (rangos != null) {
        todas.addAll(EvaluadorSugerencias.evaluarSensor(
          sensor: sensor,
          rangos: rangos,
        ));
      }
    }

    todas.sort((a, b) {
      const orden = {'crítico': 0, 'bajo': 1, 'alto': 2};
      return (orden[a.nivel] ?? 3).compareTo(orden[b.nivel] ?? 3);
    });

    setState(() {
      _sugerencias = todas;
      _cargando = false;
    });
  }

  IconData _iconoPorNivel(String nivel) {
    switch (nivel) {
      case 'crítico': return Icons.error_rounded;
      case 'bajo':    return Icons.arrow_circle_down_rounded;
      case 'alto':    return Icons.arrow_circle_up_rounded;
      default:        return Icons.info_rounded;
    }
  }

  Color _colorPorNivel(String nivel) {
    switch (nivel) {
      case 'crítico': return Colors.red.shade600;
      case 'bajo':    return Colors.orange.shade700;
      case 'alto':    return Colors.blue.shade600;
      default:        return Colors.grey.shade600;
    }
  }

  String _etiquetaNivel(String nivel) {
    switch (nivel) {
      case 'crítico': return 'Crítico';
      case 'bajo':    return 'Bajo';
      case 'alto':    return 'Alto';
      default:        return nivel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s        = AppStrings.of(appLanguage.value);
    final primary  = Theme.of(context).colorScheme.primary;
    final onSurface= Theme.of(context).colorScheme.onSurface;

    return BaseScaffold(
      title: s.navSugerencias,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _tarjetaInfo(s, primary, onSurface),
                  const SizedBox(height: 12),
                  if (_sugerencias.isEmpty)
                    _estadoVacio(s, primary, onSurface)
                  else ...[
                    _contadorResumen(),
                    const SizedBox(height: 12),
                    ..._sugerencias.map((sug) => _tarjetaSugerencia(sug, onSurface)),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _tarjetaInfo(AppStrings s, Color primary, Color onSurface) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: primary.withValues(alpha: 0.3)),
    ),
    color: primary.withValues(alpha: 0.07),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.sugerenciasInfo,
              style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.75),
                  height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _contadorResumen() {
    final criticos = _sugerencias.where((s) => s.nivel == 'crítico').length;
    final bajos    = _sugerencias.where((s) => s.nivel == 'bajo').length;
    final altos    = _sugerencias.where((s) => s.nivel == 'alto').length;

    return Row(children: [
      if (criticos > 0) _chip('$criticos crítico${criticos != 1 ? 's' : ''}', Colors.red.shade600),
      if (criticos > 0 && (bajos > 0 || altos > 0)) const SizedBox(width: 8),
      if (bajos > 0) _chip('$bajos bajo${bajos != 1 ? 's' : ''}', Colors.orange.shade700),
      if (bajos > 0 && altos > 0) const SizedBox(width: 8),
      if (altos > 0) _chip('$altos alto${altos != 1 ? 's' : ''}', Colors.blue.shade600),
    ]);
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _estadoVacio(AppStrings s, Color primary, Color onSurface) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_outline_rounded,
          size: 60, color: primary.withValues(alpha: 0.7)),
      const SizedBox(height: 14),
      Text(s.sinSugerencias,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      const SizedBox(height: 8),
      Text(s.sinSugerenciasSub,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              color: onSurface.withValues(alpha: 0.55),
              height: 1.4)),
    ]),
  );

  Widget _tarjetaSugerencia(Sugerencia sug, Color onSurface) {
    final color    = _colorPorNivel(sug.nivel);
    final icono    = _iconoPorNivel(sug.nivel);
    final param    = _nombresParams[sug.parametro] ?? sug.parametro;
    final unidad   = _unidades[sug.parametro] ?? '';
    final etiqueta = _etiquetaNivel(sug.nivel);
    final valorStr = sug.valor != null
        ? '${sug.valor!.toStringAsFixed(1)}${unidad.isNotEmpty ? ' $unidad' : ''}'
        : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icono, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(sug.sensorNombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(etiqueta,
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text(param,
                        style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600)),
                    if (valorStr != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(valorStr,
                            style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Text(sug.mensaje,
                      style: TextStyle(
                          fontSize: 13,
                          color: onSurface.withValues(alpha: 0.75),
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
