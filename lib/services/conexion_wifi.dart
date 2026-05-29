import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Clase para devolver resultados de sincronización
class ResultadoSincronizacion {
  final bool exito;
  final int archivosSincronizados;
  final String mensaje;

  ResultadoSincronizacion({
    required this.exito,
    required this.archivosSincronizados,
    required this.mensaje,
  });
}

class ConexionWiFi {
  final String baseUrl = "http://192.168.4.1";

  // ── Claim / propiedad ────────────────────────────────────────

  /// Consulta si el nodo está reclamado. Retorna {"claimed": bool}.
  Future<Map<String, dynamic>> getClaim() async {
    final response = await http
        .get(Uri.parse("$baseUrl/claim"))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) throw Exception("Error claim: ${response.statusCode}");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Intenta reclamar el nodo con el token dado.
  /// Retorna true si OK (nuevo o ya es nuestro), false si bloqueado por otro.
  Future<bool> setClaim(String token) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/claim"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        )
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  }

  /// Libera el claim (requiere el token correcto).
  /// Retorna true si liberado, false si el token no coincide.
  Future<bool> deleteClaim(String token) async {
    final request = http.Request('DELETE', Uri.parse("$baseUrl/claim"));
    request.headers[HttpHeaders.contentTypeHeader] = 'application/json';
    request.body = jsonEncode({'token': token});
    final streamed = await request.send().timeout(const Duration(seconds: 5));
    return streamed.statusCode == 200;
  }

  /// Listar archivos
  Future<List<String>> listarArchivos() async {
    final url = Uri.parse("$baseUrl/list");
    final response = await http.get(url).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception("Error obteniendo lista: ${response.statusCode}");
    }

    List<dynamic> lista = jsonDecode(response.body);
    return lista.map((e) => e.toString()).toList();
  }

  /// Descargar archivo
  Future<String> descargarArchivo(String filename) async {
    final url = Uri.parse("$baseUrl/get?name=$filename");
    final response = await http.get(url).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception("Error descargando $filename: ${response.statusCode}");
    }

    return response.body;
  }

  /// Eliminar archivo remoto
  Future<void> eliminarArchivo(String filename) async {
    final url = Uri.parse("$baseUrl/delete?name=$filename");
    final response = await http.get(url).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception("Error eliminando $filename: ${response.statusCode}");
    }
  }

  /// Función principal — descarga todo, procesa y elimina
  Future<ResultadoSincronizacion> descargarTodosYEliminar(
    Future<void> Function(String jsonStr) procesarJson,
  ) async {
    // 1) Listar archivos
    List<String> archivos = [];
    try {
      archivos = await listarArchivos();
    } catch (e) {
      return ResultadoSincronizacion(
        exito: false,
        archivosSincronizados: 0,
        mensaje:
            "Error obteniendo lista o Conexión a la red incorrecta (confirmar conexión WiFi): $e",
      );
    }

    int count = 0;
    final List<String> errores = [];

    for (String rawArchivo in archivos) {
      // Normalizar el nombre: quitar espacios/CR/LF y comparar en minúsculas
      final archivo = rawArchivo.trim();
      if (archivo.isEmpty) {
        // ignora entradas vacías por si acaso
        continue;
      }

      if (!archivo.toLowerCase().endsWith('.json')) {
        // opcional: loguear o añadir a errores si quieres
        errores.add("Omitido (no .json): '$rawArchivo'");
        continue;
      }

      try {
        // Descargar contenido
        String contenido = await descargarArchivo(archivo);

        // Procesar json (función proporcionada por el consumidor)
        await procesarJson(contenido);

        // Intentar eliminar (si falla, lanzará excepción y se atrapará abajo)
        await eliminarArchivo(archivo);

        // Si llegamos aquí todo fue OK — contar
        count++;
      } catch (e, st) {
        // Guardar información para debug, pero seguimos con los siguientes archivos
        errores.add("Error con '$archivo' -> $e");
        print("Error procesando $archivo: $e\n$st");
      }
    }

    if (count == 0) {
      final detalle =
          errores.isNotEmpty ? '\nDetalles: ${errores.join(" | ")}' : '';
      return ResultadoSincronizacion(
        exito: false,
        archivosSincronizados: 0,
        mensaje: "No se sincronizó ningún archivo.$detalle",
      );
    } else {
      final detalleErrores = errores.isNotEmpty
          ? '\nAlgunos archivos fallaron: ${errores.length}'
          : '';
      return ResultadoSincronizacion(
        exito: true,
        archivosSincronizados: count,
        mensaje: "Sincronización exitosa: $count archivos.$detalleErrores",
      );
    }
  }
}
