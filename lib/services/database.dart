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
    return await openDatabase(path, version: 5, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
}
