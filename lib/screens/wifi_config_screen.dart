import 'package:flutter/material.dart';
import 'package:soilair/theme/app_light_theme.dart';
import 'package:soilair/widgets/base_scaffold.dart';
import 'package:http/http.dart' as http;

class WifiConfigScreen extends StatefulWidget {
  const WifiConfigScreen({super.key});

  @override
  _WifiConfigScreenState createState() => _WifiConfigScreenState();
}

class _WifiConfigScreenState extends State<WifiConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _isLoading = false;

  Future<void> _updateWifi() async {
    if (!_formKey.currentState!.validate()) return;

    String ssid = _ssidController.text.trim();
    String pass = _passController.text.trim();

    setState(() => _isLoading = true);

    try {
      // Aquí colocas la IP del ESP (o domain)
      String ip = "192.168.4.1"; // Cambiar según tu AP real
      final uri = Uri.http(ip, "/setwifi", {"ssid": ssid, "pass": pass});
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.body),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error conectando al ESP: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showWifiPopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Actualizar WiFi"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _ssidController,
                decoration: const InputDecoration(labelText: "Nuevo SSID"),
                validator: (v) =>
                    (v == null || v.isEmpty) ? "Ingresa un SSID" : null,
              ),
              TextFormField(
                controller: _passController,
                decoration:
                    const InputDecoration(labelText: "Nueva contraseña"),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 8) ? "Mínimo 8 caracteres" : null,
              ),
              TextFormField(
                controller: _confirmPassController,
                decoration:
                    const InputDecoration(labelText: "Confirmar contraseña"),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Confirma la contraseña";
                  if (v != _passController.text) return "No coincide";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      _updateWifi();
                    }
                  },
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Actualizar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: "Configuración",
      body: ListView(
        children: [
          ListTile(
            leading:
                const Icon(Icons.wifi, color: AppLightTheme.botonPrincipal),
            title: const Text("WiFi"),
            subtitle: const Text("Configurar nombre y contraseña"),
            onTap: _showWifiPopup,
          ),
          // Aquí puedes agregar más configuraciones en el futuro
        ],
      ),
    );
  }
}
