import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class JsonDataService {
  /// Copia todos los archivos JSON de assets/jsondata/ al directorio local de la app
  Future<void> copyJsonAssetsToLocal() async {
    final localDir = await _getLocalJsonDir();

    // Aquí debes conocer la lista de archivos en assets/jsondata
    // Flutter no provee forma directa de listar archivos en assets,
    // por eso debes mantener una lista manual o generar una.

    final List<String> assetFiles = [
      'assets/jsondata/1719648000.json',
      // agrega todos los nombres de archivos JSON que tengas
    ];

    for (final assetPath in assetFiles) {
      final filename = assetPath.split('/').last;
      final localFile = File('${localDir.path}/$filename');

      // Solo copia si no existe ya, para no sobrescribir datos modificados
      if (!await localFile.exists()) {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        await localFile.writeAsBytes(bytes);
      }
    }
  }

  /// Obtiene (o crea) la carpeta local para JSON en app documents
  Future<Directory> _getLocalJsonDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final jsonDir = Directory('${directory.path}/jsondata');
    if (!await jsonDir.exists()) {
      await jsonDir.create(recursive: true);
    }
    return jsonDir;
  }

  /// Retorna el directorio local donde están los JSON para leer o modificar
  Future<Directory> getLocalJsonDir() async {
    return await _getLocalJsonDir();
  }
}
