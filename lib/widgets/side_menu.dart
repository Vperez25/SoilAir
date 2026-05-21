import 'package:flutter/material.dart';
import 'package:soilair/services/json_reader_wifi.dart';
import 'package:soilair/services/conexion_wifi.dart';
import 'package:soilair/theme/app_light_theme.dart';
import 'package:soilair/screens/wifi_config_screen.dart';

class MySideMenuWidget extends StatelessWidget {
  final BuildContext scaffoldContext; // ← Contexto real del Scaffold

  const MySideMenuWidget({
    super.key,
    required this.scaffoldContext,
  });

  Future<void> _sincronizarDispositivo(BuildContext context) async {
    Navigator.pop(context); // Cerrar Drawer

    try {
      final conexion = ConexionWiFi();

      final resultado = await conexion.descargarTodosYEliminar(
        (jsonStr) async => await JsonReaderWiFi().importJsonFromString(jsonStr),
      );

      final bool esErrorDeConexion =
          resultado.mensaje.startsWith("Error obteniendo lista");

      // ❌ Antes: ScaffoldMessenger.of(context)
      // ✅ Ahora: ScaffoldMessenger.of(scaffoldContext)
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          content: Text(resultado.mensaje),
          duration: esErrorDeConexion
              ? const Duration(seconds: 7)
              : const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text("Error durante sincronización: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppLightTheme.fondoTarjeta,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.only(top: 48, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: const Text(
              'Soilair',
              style: TextStyle(
                color: AppLightTheme.botonPrincipal,
                fontFamily: "CrimsonText",
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  icon: Icons.sync,
                  label: 'Sincronizar con dispositivo',
                  onTap: () => _sincronizarDispositivo(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppLightTheme.divisor, height: 1),
          _buildMenuItem(
            icon: Icons.settings,
            label: 'Configuración',
            onTap: () {
              Navigator.pop(context); // cerrar Drawer
              Navigator.push(
                scaffoldContext,
                MaterialPageRoute(builder: (_) => const WifiConfigScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppLightTheme.botonPrincipal),
      title: Text(
        label,
        style: const TextStyle(
          color: AppLightTheme.texto,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
