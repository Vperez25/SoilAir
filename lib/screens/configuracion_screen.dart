import 'package:flutter/material.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/main.dart';
import 'package:soilair/screens/faq_screen.dart';
import 'package:soilair/theme/app_light_theme.dart';
import 'package:soilair/widgets/base_scaffold.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);
    return BaseScaffold(
      title: s.navAjustes,
      body: ListView(
        children: [
          // ── Apariencia ────────────────────────────────────────
          _seccion(s.apariencia),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeMode,
            builder: (_, mode, __) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: Text(s.modoOscuro),
              value: mode == ThemeMode.dark,
              activeColor: AppLightTheme.botonPrincipal,
              onChanged: (v) =>
                  appThemeMode.value = v ? ThemeMode.dark : ThemeMode.light,
            ),
          ),

          // ── Idioma ────────────────────────────────────────────
          _seccion(s.idiomaSeccion),
          ValueListenableBuilder<String>(
            valueListenable: appLanguage,
            builder: (ctx, lang, __) => Column(
              children: [
                _opcionIdioma(ctx, lang, 'es', 'Español',  '🇲🇽'),
                _opcionIdioma(ctx, lang, 'en', 'English',  '🇺🇸'),
                _opcionIdioma(ctx, lang, 'fr', 'Français', '🇫🇷'),
              ],
            ),
          ),

          // ── FAQ ──────────────────────────────────────────────
          _seccion(s.faqSeccion),
          ListTile(
            leading: const Icon(Icons.help_outline,
                color: AppLightTheme.botonPrincipal),
            title: Text(s.faqSeccion),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FaqScreen())),
          ),

          // ── Información ───────────────────────────────────────
          _seccion(s.informacion),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(s.version),
            trailing: const Text('0.0.1',
                style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: Text(s.dispositivosSoportados),
            trailing: const Text('Android 10+',
                style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _opcionIdioma(
      BuildContext context, String langActual, String code, String label, String flag) {
    final sel = langActual == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(label,
          style: TextStyle(
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      trailing: sel
          ? const Icon(Icons.check_circle,
              color: AppLightTheme.botonPrincipal, size: 20)
          : const Icon(Icons.circle_outlined,
              color: Colors.grey, size: 20),
      onTap: () {
        if (sel) return;
        appLanguage.value = code;
        final s = AppStrings.of(code);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.idiomaActualizado),
          backgroundColor: AppLightTheme.botonPrincipal,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      },
    );
  }

  static Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          titulo.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppLightTheme.botonPrincipal,
            letterSpacing: 0.8,
          ),
        ),
      );
}
