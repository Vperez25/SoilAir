import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'soilair.db');
    return await openDatabase(path, version: 8, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  // ── Schemas ─────────────────────────────────────────────────

  static const String _schemaPrimarios = '''
    CREATE TABLE sensores_primarios (
      rowid       INTEGER PRIMARY KEY AUTOINCREMENT,
      id          TEXT    NOT NULL,
      timestamp   INTEGER NOT NULL,
      n           REAL,
      p           REAL,
      k           REAL,
      ph          REAL,
      humedad     REAL,
      ec          REAL,
      temperatura REAL,
      radiacion   REAL
    )
  ''';

  static const String _schemaSecundarios = '''
    CREATE TABLE sensores_secundarios (
      rowid              INTEGER PRIMARY KEY AUTOINCREMENT,
      id                 TEXT    NOT NULL,
      timestamp          INTEGER NOT NULL,
      sensor_primario_id TEXT,
      ec                 REAL,
      humedad            REAL,
      temperatura        REAL,
      FOREIGN KEY(sensor_primario_id) REFERENCES admin_sensores(id)
    )
  ''';

  // ── Creación ─────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_schemaPrimarios);
    await db.execute('''
      CREATE TABLE admin_sensores (
        id_key           INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre           TEXT,
        id               TEXT,
        cultivo_asignado INTEGER,
        oculto           INTEGER DEFAULT 0,
        ssid             TEXT,
        FOREIGN KEY(id) REFERENCES sensores_primarios(id),
        FOREIGN KEY(cultivo_asignado) REFERENCES cultivos(id)
      )
    ''');
    await db.execute(_schemaSecundarios);
    await db.execute('''
      CREATE TABLE sensores_ambientales (
        timestamp   INTEGER PRIMARY KEY,
        temperatura REAL,
        humedad     REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE configuracion (
        id             INTEGER PRIMARY KEY,
        cultivo_id     INTEGER,
        cultivo_nombre TEXT,
        device_token   TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE nodos_propietario (
        ssid TEXT PRIMARY KEY
      )
    ''');
    await db.execute('''
      CREATE TABLE cultivos (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre                TEXT,
        n_optimo_min          REAL, n_optimo_max          REAL,
        p_optimo_min          REAL, p_optimo_max          REAL,
        k_optimo_min          REAL, k_optimo_max          REAL,
        ph_optimo_min         REAL, ph_optimo_max         REAL,
        humedad_optimo_min    REAL, humedad_optimo_max    REAL,
        ec_optimo_min         REAL, ec_optimo_max         REAL,
        temp_optimo_min       REAL, temp_optimo_max       REAL,
        n_critico_min         REAL, n_critico_max         REAL,
        p_critico_min         REAL, p_critico_max         REAL,
        k_critico_min         REAL, k_critico_max         REAL,
        ph_critico_min        REAL, ph_critico_max        REAL,
        humedad_critico_min   REAL, humedad_critico_max   REAL,
        ec_critico_min        REAL, ec_critico_max        REAL,
        temp_critico_min      REAL, temp_critico_max      REAL,
        temp_amb_optimo_min   REAL, temp_amb_optimo_max   REAL,
        temp_amb_critico_min  REAL, temp_amb_critico_max  REAL,
        hum_amb_optimo_min    REAL, hum_amb_optimo_max    REAL,
        hum_amb_critico_min   REAL, hum_amb_critico_max   REAL,
        radiacion_optimo_min  REAL, radiacion_optimo_max  REAL,
        radiacion_critico_min REAL, radiacion_critico_max REAL
      )
    ''');
  }

  // ── Migraciones ──────────────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS admin_sensores (
          id_key INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT, id TEXT, cultivo_asignado INTEGER
        )
      ''');
    }
    if (oldVersion < 5) {
      // sensores_primarios: de PRIMARY KEY en 'id' a rowid autoincrement
      await db.execute('ALTER TABLE sensores_primarios RENAME TO _sp_old');
      await db.execute(_schemaPrimarios);
      await db.execute('''
        INSERT INTO sensores_primarios (id, timestamp, n, p, k, ph, humedad, ec, temperatura, radiacion)
        SELECT id, timestamp, n, p, k, ph, humedad, ec, temperatura, radiacion FROM _sp_old
      ''');
      await db.execute('DROP TABLE _sp_old');

      // sensores_secundarios: de PRIMARY KEY en 'id' a rowid autoincrement
      await db.execute('ALTER TABLE sensores_secundarios RENAME TO _ss_old');
      await db.execute(_schemaSecundarios);
      await db.execute('''
        INSERT INTO sensores_secundarios (id, timestamp, sensor_primario_id, ec, humedad, temperatura)
        SELECT id, timestamp, sensor_primario_id, ec, humedad, temperatura FROM _ss_old
      ''');
      await db.execute('DROP TABLE _ss_old');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS configuracion (
          id          INTEGER PRIMARY KEY,
          cultivo_id  INTEGER,
          cultivo_nombre TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE admin_sensores ADD COLUMN oculto INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE configuracion ADD COLUMN device_token TEXT');
      await db.execute('CREATE TABLE IF NOT EXISTS nodos_propietario (ssid TEXT PRIMARY KEY)');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE admin_sensores ADD COLUMN ssid TEXT');
    }
  }

  // ── Escritura: primarios ─────────────────────────────────────

  /// Inserta una lectura nueva — NO reemplaza, acumula historial.
  Future<int> insertSensorPrimario(Map<String, dynamic> sensor) async {
    final db = await database;
    final data = Map<String, dynamic>.from(sensor)
      ..remove('nombre')
      ..remove('cultivo_id');
    data.putIfAbsent('radiacion', () => null);
    return await db.insert('sensores_primarios', data);
  }

  // Alias de compatibilidad con código existente
  Future<int> insertOrUpdateSensorPrimario(Map<String, dynamic> s) =>
      insertSensorPrimario(s);
  Future<int> addSensorPrimario(Map<String, dynamic> s) =>
      insertSensorPrimario(s);

  // ── Escritura: secundarios ───────────────────────────────────

  Future<int> insertSensorSecundario(Map<String, dynamic> sensor) async {
    final db = await database;
    // Preservar sensor_primario_id si ya fue asignado y no viene en el JSON
    if (sensor['sensor_primario_id'] == null) {
      final existing = await db.query('sensores_secundarios',
          where: 'id = ?', whereArgs: [sensor['id']], limit: 1);
      if (existing.isNotEmpty) {
        sensor['sensor_primario_id'] = existing.first['sensor_primario_id'];
      }
    }
    return await db.insert('sensores_secundarios', sensor);
  }

  Future<int> insertOrUpdateSensorSecundario(Map<String, dynamic> s) =>
      insertSensorSecundario(s);
  Future<int> addSensorSecundario(Map<String, dynamic> s) =>
      insertSensorSecundario(s);

  // ── Escritura: ambiental ─────────────────────────────────────

  Future<int> addSensorAmbiental(Map<String, dynamic> sensor) async {
    final db = await database;
    return await db.insert('sensores_ambientales', sensor,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Admin sensores ───────────────────────────────────────────

  Future<int?> addSensorIfNotExists(Map<String, dynamic> sensor) async {
    final db = await database;
    final existing = await db
        .query('admin_sensores', where: 'id = ?', whereArgs: [sensor['id']]);
    if (existing.isEmpty) return await db.insert('admin_sensores', sensor);
    // If re-syncing a previously desynced sensor, make it visible again.
    // Also backfill ssid if it wasn't stored before.
    final updates = <String, dynamic>{};
    if ((existing.first['oculto'] as int? ?? 0) == 1) updates['oculto'] = 0;
    if (sensor['ssid'] != null && existing.first['ssid'] == null) {
      updates['ssid'] = sensor['ssid'];
    }
    if (updates.isNotEmpty) {
      await db.update('admin_sensores', updates,
          where: 'id = ?', whereArgs: [sensor['id']]);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getSensorById(String id) async {
    final db = await database;
    final res = await db
        .query('admin_sensores', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getSensoresSinConfig() async {
    final db = await database;
    return await db.query('admin_sensores',
        where: 'nombre IS NULL OR cultivo_asignado IS NULL');
  }

  Future<List<Map<String, dynamic>>> getSensoresConNombre() async {
    final db = await database;
    return await db.query('admin_sensores', where: 'nombre IS NOT NULL');
  }

  Future<List<Map<String, dynamic>>> getSensoresSecundariosConPrimario() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ss.id AS sec_id, ss.sensor_primario_id,
             s.nombre AS primario_nombre
      FROM (SELECT DISTINCT id, sensor_primario_id FROM sensores_secundarios) ss
      LEFT JOIN admin_sensores s ON ss.sensor_primario_id = s.id
    ''');
  }

  Future<int> updateSensorConfig({
    required String id,
    String? nombre,
    int? cultivoAsignado,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (nombre != null) updates['nombre'] = nombre;
    if (cultivoAsignado != null) updates['cultivo_asignado'] = cultivoAsignado;
    return await db
        .update('admin_sensores', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateSensorSecundarioConfig({
    required String id,
    required String sensorPrimarioId,
  }) async {
    final db = await database;
    return await db.update('sensores_secundarios',
        {'sensor_primario_id': sensorPrimarioId},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Lecturas: dashboard (última por sensor) ──────────────────

  Future<Map<String, dynamic>?> getUltimaMedicionCompleta() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT MAX(timestamp) as max_ts FROM sensores_ambientales');
    final int? maxTs = result.first['max_ts'] as int?;
    if (maxTs == null) return null;

    final ambiente = await db.query('sensores_ambientales',
        where: 'timestamp = ?', whereArgs: [maxTs], limit: 1);

    final primarios = await db.rawQuery('''
      SELECT sp.*, ads.nombre
      FROM sensores_primarios sp
      INNER JOIN (
        SELECT id, MAX(rowid) AS last_rowid FROM sensores_primarios GROUP BY id
      ) latest ON sp.rowid = latest.last_rowid
      LEFT JOIN admin_sensores ads ON sp.id = ads.id
    ''');

    final secundarios = await db.rawQuery('''
      SELECT ss.*, ads.nombre AS nombre
      FROM sensores_secundarios ss
      INNER JOIN (
        SELECT id, MAX(rowid) AS last_rowid FROM sensores_secundarios GROUP BY id
      ) latest ON ss.rowid = latest.last_rowid
      LEFT JOIN admin_sensores ads ON ss.sensor_primario_id = ads.id
    ''');

    return {
      'timestamp': maxTs,
      'ambiente': ambiente.first,
      'primarios': primarios,
      'secundarios': secundarios,
    };
  }

  // ── Lecturas: historial para gráficas ───────────────────────

  Future<List<Map<String, dynamic>>> getHistorialSensorPrimario({
    required String sensorId,
    required String campo,
    int limite = 200,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final db = await database;
    String where = 'id = ?';
    final args = <dynamic>[sensorId];
    if (desde != null) { where += ' AND timestamp >= ?'; args.add(desde.millisecondsSinceEpoch ~/ 1000); }
    if (hasta != null) { where += ' AND timestamp <= ?'; args.add(hasta.millisecondsSinceEpoch ~/ 1000); }
    return await db.query('sensores_primarios',
        columns: ['timestamp', campo], where: where, whereArgs: args,
        orderBy: 'timestamp ASC', limit: limite);
  }

  Future<List<Map<String, dynamic>>> getHistorialSensorSecundario({
    required String sensorId,
    required String campo,
    int limite = 200,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final db = await database;
    String where = 'id = ?';
    final args = <dynamic>[sensorId];
    if (desde != null) { where += ' AND timestamp >= ?'; args.add(desde.millisecondsSinceEpoch ~/ 1000); }
    if (hasta != null) { where += ' AND timestamp <= ?'; args.add(hasta.millisecondsSinceEpoch ~/ 1000); }
    return await db.query('sensores_secundarios',
        columns: ['timestamp', campo], where: where, whereArgs: args,
        orderBy: 'timestamp ASC', limit: limite);
  }

  Future<List<Map<String, dynamic>>> getHistorialAmbiental({
    int limite = 200,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final db = await database;
    String? where;
    final args = <dynamic>[];
    if (desde != null) { where = 'timestamp >= ?'; args.add(desde.millisecondsSinceEpoch ~/ 1000); }
    if (hasta != null) {
      where = (where != null ? '$where AND ' : '') + 'timestamp <= ?';
      args.add(hasta.millisecondsSinceEpoch ~/ 1000);
    }
    return await db.query('sensores_ambientales',
        orderBy: 'timestamp ASC',
        where: where, whereArgs: args.isEmpty ? null : args, limit: limite);
  }

  // ── Cultivos ─────────────────────────────────────────────────

  Future<int> addCultivo(Map<String, dynamic> cultivo) async {
    final db = await database;
    return await db.insert('cultivos', cultivo);
  }

  Future<int> deleteCultivo(int id) async {
    final db = await database;
    return await db.delete('cultivos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getCultivos() async {
    final db = await database;
    return await db.query('cultivos');
  }

  Future<Map<String, dynamic>?> getCultivoPorNombre(String nombre) async {
    final db = await database;
    final r = await db.query('cultivos', where: 'nombre = ?', whereArgs: [nombre]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<void> updateCultivo(Map<String, dynamic> cultivo) async {
    final db = await database;
    await db.update('cultivos', cultivo,
        where: 'nombre = ?', whereArgs: [cultivo['nombre']]);
  }

  Future<Map<String, dynamic>?> getRangosCultivoAsignado(String sensorId) async {
    final db = await database;
    final r = await db.rawQuery('''
      SELECT c.* FROM cultivos c
      INNER JOIN admin_sensores a ON a.cultivo_asignado = c.id
      WHERE a.id = ?
    ''', [sensorId]);
    return r.isNotEmpty ? r.first : null;
  }

  // ── Configuracion global ─────────────────────────────────────

  Future<Map<String, dynamic>?> getConfiguracion() async {
    final db = await database;
    final r = await db.query('configuracion', where: 'id = ?', whereArgs: [1], limit: 1);
    return r.isNotEmpty ? r.first : null;
  }

  Future<void> setConfiguracion({int? cultivoId, String? cultivoNombre}) async {
    final db = await database;
    await db.insert(
      'configuracion',
      {'id': 1, 'cultivo_id': cultivoId, 'cultivo_nombre': cultivoNombre},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCultivoById(int id) async {
    final db = await database;
    final r = await db.query('cultivos', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isNotEmpty ? r.first : null;
  }

  /// IDs distintos de sensores primarios con su último timestamp.
  Future<List<Map<String, dynamic>>> getTodosSensoresPrimarios() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT id, MAX(timestamp) AS ultimo_timestamp
      FROM sensores_primarios
      GROUP BY id
      ORDER BY id
    ''');
  }

  /// Sensores primarios visibles (no ocultos) con su configuración y último timestamp.
  Future<List<Map<String, dynamic>>> getSensoresPrimarioConConfig() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        sp.id,
        MAX(sp.timestamp)  AS ultimo_timestamp,
        a.nombre,
        a.cultivo_asignado,
        c.nombre           AS cultivo_nombre
      FROM sensores_primarios sp
      LEFT JOIN admin_sensores  a ON a.id  = sp.id
      LEFT JOIN cultivos        c ON c.id  = a.cultivo_asignado
      WHERE COALESCE(a.oculto, 0) = 0
      GROUP BY sp.id
      ORDER BY sp.id
    ''');
  }

  /// Guarda nombre y cultivo de un sensor (siempre sobreescribe ambos campos).
  Future<void> configurarSensor({
    required String sensorId,
    required String nombre,
    int? cultivoId,
  }) async {
    final db = await database;
    await db.update(
      'admin_sensores',
      {'nombre': nombre, 'cultivo_asignado': cultivoId},
      where: 'id = ?',
      whereArgs: [sensorId],
    );
  }

  /// Nombres configurados de todos los sensores excepto el indicado.
  Future<List<String>> getNombresExcepto(String sensorId) async {
    final db = await database;
    final r = await db.query('admin_sensores',
        columns: ['nombre'],
        where: 'id != ? AND nombre IS NOT NULL',
        whereArgs: [sensorId]);
    return r.map((row) => row['nombre'] as String).toList();
  }

  /// IDs distintos de sensores secundarios con su último timestamp.
  Future<List<Map<String, dynamic>>> getTodosSensoresSecundarios() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT id, sensor_primario_id, MAX(timestamp) AS ultimo_timestamp
      FROM sensores_secundarios
      GROUP BY id
      ORDER BY id
    ''');
  }

  // ── Desincronización ─────────────────────────────────────────

  /// Oculta un sensor de la vista de conectados; sus datos históricos permanecen.
  Future<void> desincronizarSensor(String sensorId) async {
    final db = await database;
    final existe = await db.query('admin_sensores',
        where: 'id = ?', whereArgs: [sensorId], limit: 1);
    if (existe.isNotEmpty) {
      await db.update('admin_sensores', {'oculto': 1},
          where: 'id = ?', whereArgs: [sensorId]);
    } else {
      await db.insert('admin_sensores', {'id': sensorId, 'oculto': 1});
    }
  }

  // ── Token de dispositivo ─────────────────────────────────────

  String _generarToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Obtiene (o genera) el token único permanente de este dispositivo.
  Future<String> getDeviceToken() async {
    final db = await database;
    final r = await db.query('configuracion',
        where: 'id = ?', whereArgs: [1], limit: 1);
    if (r.isNotEmpty && r.first['device_token'] != null) {
      return r.first['device_token'] as String;
    }
    final token = _generarToken();
    if (r.isEmpty) {
      await db.insert('configuracion', {'id': 1, 'device_token': token});
    } else {
      await db.update('configuracion', {'device_token': token},
          where: 'id = ?', whereArgs: [1]);
    }
    return token;
  }

  // ── Propiedad de nodos ───────────────────────────────────────

  Future<List<String>> getNodosPropietario() async {
    final db = await database;
    final r = await db.query('nodos_propietario', columns: ['ssid']);
    return r.map((row) => row['ssid'] as String).toList();
  }

  Future<void> marcarNodoPropietario(String ssid) async {
    final db = await database;
    await db.insert('nodos_propietario', {'ssid': ssid},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> liberarNodoPropietario(String ssid) async {
    final db = await database;
    await db.delete('nodos_propietario', where: 'ssid = ?', whereArgs: [ssid]);
  }

  Future<String?> getSsidDeSensor(String sensorId) async {
    final db = await database;
    final r = await db.query('admin_sensores',
        columns: ['ssid'], where: 'id = ?', whereArgs: [sensorId], limit: 1);
    return r.isNotEmpty ? r.first['ssid'] as String? : null;
  }

  /// Returns true if [sensorId] is the only active sensor linked to its node SSID.
  Future<bool> esUltimoSensorDeNodo(String sensorId) async {
    final db = await database;
    final r = await db.query('admin_sensores',
        columns: ['ssid'], where: 'id = ?', whereArgs: [sensorId], limit: 1);
    if (r.isEmpty || r.first['ssid'] == null) return false;
    final ssid = r.first['ssid'] as String;
    final others = await db.query('admin_sensores',
        where: "ssid = ? AND id != ? AND COALESCE(oculto, 0) = 0",
        whereArgs: [ssid, sensorId]);
    return others.isEmpty;
  }

  /// Releases ownership of the node that sensor [sensorId] came from,
  /// but only if no other active (non-hidden) sensor is still linked to that SSID.
  Future<void> liberarNodoPropietarioPorSensor(String sensorId) async {
    final db = await database;
    final r = await db.query('admin_sensores',
        columns: ['ssid'], where: 'id = ?', whereArgs: [sensorId], limit: 1);
    if (r.isEmpty || r.first['ssid'] == null) return;
    final ssid = r.first['ssid'] as String;
    final others = await db.query('admin_sensores',
        where: "ssid = ? AND id != ? AND COALESCE(oculto, 0) = 0",
        whereArgs: [ssid, sensorId]);
    if (others.isEmpty) {
      await db.delete('nodos_propietario', where: 'ssid = ?', whereArgs: [ssid]);
    }
  }

  /// Devuelve un mapa {id → nombre} para todos los sensores en admin_sensores.
  Future<Map<String, String?>> getNombresSensores() async {
    final db = await database;
    final r = await db.query('admin_sensores', columns: ['id', 'nombre']);
    return {for (final row in r) row['id'] as String: row['nombre'] as String?};
  }
}
