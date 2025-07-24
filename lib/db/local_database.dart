// /db/local_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // <-- Añade esto
//import 'package:permission_handler/permission_handler.dart';
//import 'package:share_plus/share_plus.dart';

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
        categoria TEXT CHECK(categoria IN (
         'Alimentación', 'Suplementación', 'Manutención', 'Cuidado Personal', 'Transporte', 'Viajes', 
         'Nómina', 'Entretenimiento', 'Educación', 
         'Seguros', 'Compras', 'Restaurantes', 'Regalos', 'Imprevistos'
        )),
        descripcion TEXT,
        monto REAL,
        divisa TEXT CHECK(divisa IN ('COP', 'USD', 'EUR', 'AED')) DEFAULT 'AED',
        metodo_pago TEXT CHECK(metodo_pago IN (
          'Efectivo', 'Tarjeta Debito'
        )),
        fecha TEXT,
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
    return await db.query('expenses', orderBy: 'id DESC');
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
    orderBy: 'id DESC', 
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
  final db = await database;
  await db.delete(
    'expenses',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );
  }

  static Future<int> actualizarGasto(Map<String, dynamic> gasto) async {
  final db = await database;
    
    return await db.update(
      'expenses', // Nombre de tu tabla
      gasto,
      where: 'uuid = ?', // Usamos UUID como identificador único
      whereArgs: [gasto['uuid']],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Funcion de paginacion
static Future<List<Map<String, dynamic>>> obtenerGastosPaginados({
  int limit = 100,
  int offset = 0,
}) async {
  final db = await database;
  return await db.query(
    'expenses',
    orderBy: 'id DESC',
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

static Future<Map<String, dynamic>> obtenerGastoPorUuid(String uuid) async {
  final db = await database;
  final List<Map<String, dynamic>> result = await db.query(
    'expenses',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );
  return result.isNotEmpty ? result.first : {};
}

static Future<String> exportRawDatabase() async {
  final dbPath = await getDatabasesPath();
  final sourceFile = File('$dbPath/bitacora_financiera.db');
  
  // Verificar si el archivo existe
  if (!await sourceFile.exists()) {
    throw Exception('Archivo de base de datos no encontrado');
  }

  // Obtener directorio de descargas (funciona en Android/iOS)
  final directory = Platform.isAndroid
      ? Directory('/storage/emulated/0/Download') // Ruta estándar Android
      : await getApplicationDocumentsDirectory(); // iOS usa Documents

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  // Crear archivo destino
  final exportFile = File('${directory.path}/bitacora_financiera_${DateTime.now().millisecondsSinceEpoch}.db');
  
  // Copiar el archivo
  await sourceFile.copy(exportFile.path);

  return exportFile.path;
  }

 static Future<void> reiniciarBaseDeDatos() async {
  _database = null; // Limpiar instancia
  await database; // Volver a cargar
  }


  
}
