import 'package:flutter/material.dart';

class _EstadoSensor {
  final Color color;
  final String? etiqueta;
  const _EstadoSensor(this.color, [this.etiqueta]);
}

class SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Map<String, dynamic>? cultivo;
  final String? paramKey;
  final Color? color;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.cultivo,
    this.paramKey,
    this.color,
  });

  _EstadoSensor _calcEstado() {
    if (cultivo == null || paramKey == null) {
      return _EstadoSensor(Colors.blueGrey.shade400);
    }

    final double? val = double.tryParse(value);
    if (val == null) return _EstadoSensor(Colors.grey);

    String key = paramKey!;
    if (key == 'temperatura') key = 'temp';
    if (key == 'ec' || key == 'conductividad') key = 'ec';

    final optMin  = cultivo?['${key}_optimo_min']  as num?;
    final optMax  = cultivo?['${key}_optimo_max']  as num?;
    final critMin = cultivo?['${key}_critico_min'] as num?;
    final critMax = cultivo?['${key}_critico_max'] as num?;

    // Rango óptimo
    if (optMin != null && optMax != null && val >= optMin && val <= optMax) {
      return _EstadoSensor(Colors.green);
    }

    // Por debajo del óptimo
    if (optMin != null && val < optMin) {
      if (critMin != null && val < critMin) {
        return _EstadoSensor(Colors.indigo.shade700, 'Crítico bajo');
      }
      return _EstadoSensor(Colors.lightBlue.shade700, 'Bajo');
    }

    // Por encima del óptimo
    if (optMax != null && val > optMax) {
      if (critMax != null && val > critMax) {
        return _EstadoSensor(Colors.red, 'Crítico alto');
      }
      return _EstadoSensor(Colors.orange, 'Alto');
    }

    return _EstadoSensor(Colors.blueGrey.shade400);
  }

  @override
  Widget build(BuildContext context) {
    final estado  = color != null ? _EstadoSensor(color!) : _calcEstado();
    final bgColor = estado.color;

    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        border: Border.all(color: bgColor, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 16,
                color: bgColor,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: unit.isNotEmpty ? ' $unit' : '',
                  style: TextStyle(
                    fontSize: 13,
                    color: bgColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (estado.etiqueta != null) ...[
            const SizedBox(height: 4),
            Text(
              estado.etiqueta!,
              style: TextStyle(
                fontSize: 10,
                color: bgColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
