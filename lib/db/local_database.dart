// /db/local_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    return await _initDB();
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'bitacora_financiera.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _crearTablas,
    );
  }

  static Future<void> _crearTablas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT CHECK(category IN (
          'Food', 'Transport', 'Entertainment', 'Housing', 'Utilities',
          'Healthcare', 'Education', 'Insurance', 'Shopping', 'Personal Care',
          'Travel', 'Dining Out', 'Gifts', 'Savings', 'Investments', 'Miscellaneous'
        )),
        description TEXT,
        amount REAL,
        currency TEXT CHECK(currency IN ('COP', 'USD', 'EUR')) DEFAULT 'COP',
        payment_method TEXT CHECK(payment_method IN (
          'Efectivo', 'Nequi', 'Tarjeta de Credito', 'Bancolombia', 'Falabella'
        )),
        date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        uuid TEXT UNIQUE,
        sincronizado INTEGER DEFAULT 0
      )
    ''');
  }

  static Future<void> insertarGasto(Map<String, dynamic> gasto) async {
    final db = await database;
    await db.insert('expenses', gasto);
  }

  static Future<List<Map<String, dynamic>>> obtenerGastos() async {
    final db = await database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  static Future<void> borrarTodosLosGastos() async {
    final db = await database;
    await db.delete('expenses');
  }

  static Future<List<Map<String, dynamic>>> obtenerGastosNoSincronizados() async {
  final db = await database;
  return await db.query(
    'expenses',
    where: 'sincronizado = ?',
    whereArgs: [0],
  );
  }
  
  static Future<void> marcarGastoComoSincronizado(String uuid) async {
  final db = await database;
  await db.update(
    'expenses',
    {'sincronizado': 1},
    where: 'uuid = ?',
    whereArgs: [uuid],
  );
  }

  static Future<void> eliminarGasto(String uuid) async {
  // Implementación para eliminar el gasto
  }

static Future<void> actualizarGasto(Map<String, dynamic> gasto) async {
  // Implementación para actualizar el gasto
  }

  // Funcion de paginacion
static Future<List<Map<String, dynamic>>> obtenerGastosPaginados({
  int limit = 100,
  int offset = 0,
}) async {
  final db = await database;
  return await db.query(
    'expenses',
    orderBy: 'date DESC',
    limit: limit,
    offset: offset,
  );
}

static Future<int> contarGastos() async {
  final db = await database;
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM expenses')
  );
  return count ?? 0;
}


  
}
