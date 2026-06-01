import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const nav      = 'tutorial_nav_v1';
  static const sensores = 'tutorial_sensores_v1';

  static Future<bool> debeEjecutar(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(clave) ?? false);
  }

  static Future<void> marcarVisto(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(clave, true);
  }

  static Future<void> reiniciar(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(clave);
  }
}
