import 'package:flutter/material.dart';

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

  Color determineColor() {
    if (cultivo == null || paramKey == null) return Colors.blueGrey.shade400;

    final double? val = double.tryParse(value);
    if (val == null) return Colors.grey;

    // Mapeo de claves específicas a columnas DB
    String key = paramKey!;
    if (key == 'temperatura') key = 'temp';
    if (key == 'humedad') key = 'humedad'; // ya coincide
    if (key == 'ph') key = 'ph';
    if (key == 'ec' || key == 'conductividad') key = 'ec';
    if (key == 'n' || key == 'p' || key == 'k') key = key; // NPK igual
    if (key == 'radiacion') key = 'radiacion';

    final optMin = cultivo?['${key}_optimo_min'] as num?;
    final optMax = cultivo?['${key}_optimo_max'] as num?;
    final critMin = cultivo?['${key}_critico_min'] as num?;
    final critMax = cultivo?['${key}_critico_max'] as num?;

    if (optMin != null && optMax != null && val >= optMin && val <= optMax) {
      return Colors.green; // rango ideal
    }

    if (critMin != null && optMin != null && val >= critMin && val < optMin) {
      return Colors.orange; // crítico inferior a ideal inferior
    }

    if (critMax != null && optMax != null && val > optMax && val <= critMax) {
      return Colors.orange; // crítico superior a ideal superior
    }

    return Colors.red; // fuera de rango crítico
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? determineColor();

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
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
