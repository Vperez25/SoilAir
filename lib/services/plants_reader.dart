import 'dart:convert';
import 'package:flutter/services.dart';
import 'database.dart';

class PlantImporter {
  final DatabaseHelper dbHelper = DatabaseHelper();

  Future<void> importarDesdeAssets() async {
    final List<String> archivos = [
      'assets/plants/oranges.json',
      'assets/plants/tomatoes.json',
      'assets/plants/carrot.json',
      'assets/plants/chicharo.json',
      'assets/plants/chili.json',
      'assets/plants/corn.json',
      'assets/plants/haba.json',
      'assets/plants/jitomate.json',
      'assets/plants/lettuce.json',
      'assets/plants/potatoe.json',
      'assets/plants/strawberry.json',
      'assets/plants/tomatillo.json',
      'assets/plants/triticale.json',
      'assets/plants/wheat.json',
    ];

    for (final assetPath in archivos) {
      final String contenido = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> planta = json.decode(contenido);
      final cultivo = _parseCultivoDesdeJson(planta);

      final existente = await dbHelper.getCultivoPorNombre(cultivo['nombre']);
      if (existente != null) {
        await dbHelper.updateCultivo(cultivo); // Actualiza si ya existe
      } else {
        await dbHelper.addCultivo(cultivo); // Inserta si es nuevo
      }
    }
  }

  Map<String, dynamic> _parseCultivoDesdeJson(Map<String, dynamic> json) {
    final suelo = json['suelo'];
    final ambiente = json['ambiente'];

    return {
      'nombre': json['nombre'],
      'n_optimo_min': suelo['npk']['n']['ideal']['min'],
      'n_optimo_max': suelo['npk']['n']['ideal']['max'],
      'p_optimo_min': suelo['npk']['p']['ideal']['min'],
      'p_optimo_max': suelo['npk']['p']['ideal']['max'],
      'k_optimo_min': suelo['npk']['k']['ideal']['min'],
      'k_optimo_max': suelo['npk']['k']['ideal']['max'],
      'ph_optimo_min': suelo['ph']['ideal']['min'],
      'ph_optimo_max': suelo['ph']['ideal']['max'],
      'humedad_optimo_min': suelo['humedad']['ideal']['min'],
      'humedad_optimo_max': suelo['humedad']['ideal']['max'],
      'ec_optimo_min': suelo['conductividad']['ideal']['min'],
      'ec_optimo_max': suelo['conductividad']['ideal']['max'],
      'temp_optimo_min': suelo['temperatura']['ideal']['min'],
      'temp_optimo_max': suelo['temperatura']['ideal']['max'],
      'n_critico_min': suelo['npk']['n']['critico']['min'],
      'n_critico_max': suelo['npk']['n']['critico']['max'],
      'p_critico_min': suelo['npk']['p']['critico']['min'],
      'p_critico_max': suelo['npk']['p']['critico']['max'],
      'k_critico_min': suelo['npk']['k']['critico']['min'],
      'k_critico_max': suelo['npk']['k']['critico']['max'],
      'ph_critico_min': suelo['ph']['critico']['min'],
      'ph_critico_max': suelo['ph']['critico']['max'],
      'humedad_critico_min': suelo['humedad']['critico']['min'],
      'humedad_critico_max': suelo['humedad']['critico']['max'],
      'ec_critico_min': suelo['conductividad']['critico']['min'],
      'ec_critico_max': suelo['conductividad']['critico']['max'],
      'temp_critico_min': suelo['temperatura']['critico']['min'],
      'temp_critico_max': suelo['temperatura']['critico']['max'],
      'temp_amb_optimo_min': ambiente['temperatura']['ideal']['min'],
      'temp_amb_optimo_max': ambiente['temperatura']['ideal']['max'],
      'temp_amb_critico_min': ambiente['temperatura']['critico']['min'],
      'temp_amb_critico_max': ambiente['temperatura']['critico']['max'],
      'hum_amb_optimo_min': ambiente['humedad_relativa']['ideal']['min'],
      'hum_amb_optimo_max': ambiente['humedad_relativa']['ideal']['max'],
      'hum_amb_critico_min': ambiente['humedad_relativa']['critico']['min'],
      'hum_amb_critico_max': ambiente['humedad_relativa']['critico']['max'],
      'radiacion_optimo_min': ambiente['radiacion']?['ideal']?['min'],
      'radiacion_optimo_max': ambiente['radiacion']?['ideal']?['max'],
      'radiacion_critico_min': ambiente['radiacion']?['critico']?['min'],
      'radiacion_critico_max': ambiente['radiacion']?['critico']?['max'],
    };
  }
}
