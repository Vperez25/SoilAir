import 'package:flutter/material.dart';

class AppLightTheme {
  // ── Colores de la paleta ───────────────────────────────────────
  static const Color fondo           = Color(0xFFF2E9E1);
  static const Color fondoTarjeta    = Color(0xFFFAF5EF);
  static const Color botonPrincipal  = Color(0xFF619A63);
  static const Color fondoSideMenu   = Color(0xFFB3BF8E);
  static const Color texto           = Colors.black;
  static const Color divisor         = Color(0xFFA6483F);
  static const Color alerta          = Color(0xFFD98566);

  // ── Colores modo oscuro ────────────────────────────────────────
  static const Color fondoOscuro        = Color(0xFF121212);
  static const Color fondoTarjetaOscura = Color(0xFF1E1E1E);
  static const Color textoOscuro        = Colors.white;

  // ── Navegación ─────────────────────────────────────────────────
  static const Color navSelected         = botonPrincipal;
  static const Color navUnselectedLight  = Color(0xFF757575); // grey 600
  static const Color navUnselectedDark   = Color(0xFF9E9E9E); // grey 500

  // ── Tema claro ─────────────────────────────────────────────────
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
        outline: Colors.black26,
      ),
      textTheme: const TextTheme(
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: texto),
        bodyMedium:  TextStyle(fontSize: 14, color: texto),
      ),
      cardColor: fondoTarjeta,
      dividerColor: divisor,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: fondoTarjeta,
        selectedItemColor: navSelected,
        unselectedItemColor: navUnselectedLight,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: navSelected, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: navUnselectedLight);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: navSelected);
          }
          return const IconThemeData(color: navUnselectedLight);
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
          foregroundColor: botonPrincipal,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Tema oscuro ────────────────────────────────────────────────
  static ThemeData get darkThemeData {
    return ThemeData(
      scaffoldBackgroundColor: fondoOscuro,
      primaryColor: botonPrincipal,
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: botonPrincipal,
        surface: fondoTarjetaOscura,
        onPrimary: Colors.white,
        onSurface: textoOscuro,
        secondary: fondoSideMenu,
        outline: Colors.white24,
      ),
      textTheme: const TextTheme(
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textoOscuro),
        bodyMedium:  TextStyle(fontSize: 14, color: textoOscuro),
      ),
      cardColor: fondoTarjetaOscura,
      dividerColor: divisor,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: fondoTarjetaOscura,
        selectedItemColor: navSelected,
        unselectedItemColor: navUnselectedDark,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: navSelected, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: navUnselectedDark);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: navSelected);
          }
          return const IconThemeData(color: navUnselectedDark);
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
          foregroundColor: botonPrincipal,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
