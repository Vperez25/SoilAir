import 'package:flutter/material.dart';

class AppLightTheme {
  // Colores principales
  static const Color fondo = Color(0xFFF2E9E1);
  static const Color fondoTarjeta = Color(0xFFFAF5EF);
  static const Color botonPrincipal = Color(0xFF619A63);
  static const Color fondoSideMenu = Color(0xFFB3BF8E);
  static const Color texto = Colors.black;
  static const Color divisor = Color(0xFFA6483F);
  static const Color alerta = Color(0xFFD98566);

  // Colores para la barra de navegación inferior
  static const Color navSelected = botonPrincipal;
  static final Color navUnselected = botonPrincipal.withOpacity(0.6);

  // TextStyles
  static const TextStyle titulo = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: texto,
  );

  static const TextStyle cuerpo = TextStyle(
    fontSize: 14,
    color: texto,
  );

  // Tema general
  static ThemeData get themeData {
    return ThemeData(
      scaffoldBackgroundColor: fondo,
      primaryColor: botonPrincipal,
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: botonPrincipal,
        surface: fondoTarjeta,
        onPrimary: Colors.white,
        onSurface: texto,
        secondary: fondoSideMenu,
      ),
      textTheme: const TextTheme(
        titleMedium: titulo,
        bodyMedium: cuerpo,
      ),
      cardColor: fondoTarjeta,
      dividerColor: divisor,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Colors.transparent, // Quita la "bola"
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: navSelected, fontWeight: FontWeight.bold);
          }
          return TextStyle(color: navUnselected);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: navSelected);
          }
          return IconThemeData(color: navUnselected);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: botonPrincipal,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: alerta,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
