// /db/papa_local_database.dart

import 'package:sqflite/sqflite.dart'; // Importa sqflite
import 'package:path/path.dart'; // Importa path


class PapaLocalDatabase {

  //.constructor nombrado y tambien privado de esta clase.
  PapaLocalDatabase._init();
  //.la clase se está “auto-instanciando”, 
  static final PapaLocalDatabase instance = PapaLocalDatabase._init();
  //parece “raro” o “contraintuitivo”, pero es exactamente lo que hace el patrón singleton.
  //ahora puedo acceder a los metodos de esta clase mediante esta instancia {instance} => es un campo //.estático → vive en la clase, no en las instancias.
  //no necesito crear uns instancia fuera de aqui para poder acceder a estos metodos abajo!
  
  
  static Database? _database; //aqui se almacenara la base de datos cuando se cree, o cuando se acceda al getter de esta clase la primera vez.

  

  //. getter para devolver la conexion unica a la base de datos conexion#1 y no tener varias conexiones en paralelo [threads].
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('papa_local_database.db');
    return _database!;
  }

  //. Metodo principal para crear base de datos.
  Future<Database> _initDB(String nombreDeDb) async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, nombreDeDb);
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

  //. Funcion que crea la base de datos, se usa dentro de _initDB
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

  //.insert
  Future<int> insert(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('cuenta_papa', row);
  }

  //. toda la db
  Future<List<Map<String, dynamic>>> queryAll() async {
    final db = await instance.database;
    return await db.query('cuenta_papa');
  }

  //.update
  Future<int> update(Map<String, dynamic> row) async {
    final db = await instance.database;
    final id = row['id'];
    return await db.update('cuenta_papa', row, where: 'id = ?', whereArgs: [id]);
  }

  //.saldo
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

  //. insertar
  // Método para insertar un gasto
  Future<int> insertarGasto(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('cuenta_papa', row);
  }

  //. actualizar saldo
  // Método para actualizar el saldo
  Future<void> actualizarSaldo(double nuevoSaldo) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE cuenta_papa SET saldo = ? WHERE id = ?',
      [nuevoSaldo, 1], // Asegúrate de que el '1' sea el id correcto para tu saldo
    );
  }

  //. ultimo gasto
  Future<Map<String, dynamic>?> obtenerUltimoGasto() async {
  final db = await database;
  final result = await db.query(
    'cuenta_papa', // o como se llame tu tabla
    orderBy: 'fecha DESC', // o 'id DESC' si usas autoincremental
    limit: 1,
  );
  return result.isNotEmpty ? result.first : null;
  }

  //. eliminar todo
  Future<void> borrarTodosLosGastos() async {
    final db = await database;
    await db.delete('cuenta_papa');
  }

  //. gastos no sincronizados
  Future<List<Map<String, dynamic>>> obtenerGastosNoSincronizados() async {
  final db = await database;
  return await db.query(
    'cuenta_papa',
    where: 'sincronizado = ?',
    whereArgs: [0],
  );
  }
  
  //.Marcar como sincronizado
  Future<void> marcarGastoComoSincronizado(String uuid) async {
  final db = await database;
  await db.update(
    'cuenta_papa',
    {'sincronizado': 1},
    where: 'uuid = ?',
    whereArgs: [uuid],
  );
  }

  //.actualizar
  Future<int> actualizarGasto(int id, Map<String, dynamic> row) async {
  final db = await database;
  return await db.update(
    'cuenta_papa',
    row,
    where: 'id = ?',
    whereArgs: [id],
  );
}

//.delete
Future<int> delete(int id) async {
  final db = await database;
  return await db.delete(
    'cuenta_papa',
    where: 'id = ?',
    whereArgs: [id],
  );
}

}

