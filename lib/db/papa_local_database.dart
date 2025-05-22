// /db/papa_local_database.dart

import 'package:sqflite/sqflite.dart'; // Importa sqflite
import 'package:path/path.dart'; // Importa path


class PapaLocalDatabase {
  static final PapaLocalDatabase instance = PapaLocalDatabase._init();
  static Database? _database;

  PapaLocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('papa_local_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, filePath);
  return await openDatabase(
    path,
    version: 2, // Incrementamos la versión por el cambio de esquema
    onCreate: _createDB,
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await _createTriggers(db);
      }
    },
  );
  }

  Future _createDB(Database db, int version) async {
  await db.execute('''
  CREATE TABLE cuenta_papa (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    categoria TEXT NOT NULL DEFAULT 'Investments',
    descripcion TEXT,
    tipo TEXT NOT NULL DEFAULT 'egreso',
    monto REAL NOT NULL,
    saldo REAL,
    fecha TEXT DEFAULT CURRENT_DATE,
    generado TEXT,
    uuid TEXT UNIQUE,
    sincronizado INTEGER DEFAULT 0
  )
  ''');

  await _createTriggers(db);
  }

  Future<void> _createTriggers(Database db) async {
  // Trigger para INSERT
  await db.execute('''
  CREATE TRIGGER IF NOT EXISTS calcular_saldo_insert
  AFTER INSERT ON cuenta_papa
  BEGIN
    UPDATE cuenta_papa 
    SET saldo = (
      SELECT COALESCE((
        SELECT saldo 
        FROM cuenta_papa 
        WHERE id < NEW.id 
        ORDER BY id DESC 
        LIMIT 1
      ), 0) + 
      CASE WHEN NEW.tipo = 'ingreso' THEN NEW.monto ELSE -NEW.monto END
    )
    WHERE id = NEW.id;
  END;
  ''');

  // Trigger para UPDATE
  await db.execute('''
  CREATE TRIGGER IF NOT EXISTS recalcular_saldos_update
  AFTER UPDATE ON cuenta_papa
  BEGIN
    -- Recalcular el saldo del registro actual
    UPDATE cuenta_papa 
    SET saldo = (
      SELECT COALESCE((
        SELECT saldo 
        FROM cuenta_papa 
        WHERE id < NEW.id 
        ORDER BY id DESC 
        LIMIT 1
      ), 0) + 
      CASE WHEN NEW.tipo = 'ingreso' THEN NEW.monto ELSE -NEW.monto END
    )
    WHERE id = NEW.id;
    
    -- Recalcular todos los saldos posteriores
    UPDATE cuenta_papa
    SET saldo = (
      SELECT COALESCE((
        SELECT saldo 
        FROM cuenta_papa prev
        WHERE prev.id < cuenta_papa.id
        ORDER BY prev.id DESC
        LIMIT 1
      ), 0) +
      CASE WHEN tipo = 'ingreso' THEN monto ELSE -monto END
    )
    WHERE id > NEW.id;
  END;
  ''');

  // Trigger para DELETE
  await db.execute('''
  CREATE TRIGGER IF NOT EXISTS recalcular_saldos_delete
  AFTER DELETE ON cuenta_papa
  BEGIN
    -- Recalcular todos los saldos posteriores al eliminado
    UPDATE cuenta_papa
    SET saldo = (
      SELECT COALESCE((
        SELECT saldo 
        FROM cuenta_papa prev
        WHERE prev.id < cuenta_papa.id
        ORDER BY prev.id DESC
        LIMIT 1
      ), 0) +
      CASE WHEN tipo = 'ingreso' THEN monto ELSE -monto END
    )
    WHERE id > OLD.id;
  END;
  ''');
  }

  Future<int> insert(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('cuenta_papa', row);
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    final db = await instance.database;
    return await db.query('cuenta_papa');
  }

  Future<int> update(Map<String, dynamic> row) async {
    final db = await instance.database;
    final id = row['id'];
    return await db.update('cuenta_papa', row, where: 'id = ?', whereArgs: [id]);
  }

   Future<double?> obtenerSaldo() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'cuenta_papa',
      columns: ['saldo'], // Suponiendo que 'saldo' es la columna que guarda el saldo
      orderBy: 'id DESC',
      limit: 1, // Obtenemos el último registro
    );
    if (result.isNotEmpty) {
      return result.first['saldo'] as double?;
    }
    return null; // Si no se encuentra saldo
  }

  // Método para insertar un gasto
  Future<int> insertarGasto(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('cuenta_papa', row);
  }

  // Método para actualizar el saldo
  Future<void> actualizarSaldo(double nuevoSaldo) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE cuenta_papa SET saldo = ? WHERE id = ?',
      [nuevoSaldo, 1], // Asegúrate de que el '1' sea el id correcto para tu saldo
    );
  }

  Future<Map<String, dynamic>?> obtenerUltimoGasto() async {
  final db = await database;
  final result = await db.query(
    'cuenta_papa', // o como se llame tu tabla
    orderBy: 'fecha DESC', // o 'id DESC' si usas autoincremental
    limit: 1,
  );
  return result.isNotEmpty ? result.first : null;
  }

  Future<void> borrarTodosLosGastos() async {
    final db = await database;
    await db.delete('cuenta_papa');
  }

  Future<List<Map<String, dynamic>>> obtenerGastosNoSincronizados() async {
  final db = await database;
  return await db.query(
    'cuenta_papa',
    where: 'sincronizado = ?',
    whereArgs: [0],
  );
  }
  
  Future<void> marcarGastoComoSincronizado(String uuid) async {
  final db = await database;
  await db.update(
    'cuenta_papa',
    {'sincronizado': 1},
    where: 'uuid = ?',
    whereArgs: [uuid],
  );
  }

  Future<int> actualizarGasto(int id, Map<String, dynamic> row) async {
  final db = await database;
  return await db.update(
    'cuenta_papa',
    row,
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<int> delete(int id) async {
  final db = await database;
  return await db.delete(
    'cuenta_papa',
    where: 'id = ?',
    whereArgs: [id],
  );
}

}

