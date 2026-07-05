import 'package:intl/intl.dart';
import './local_database.dart';
import './models.dart';


// Función para obtener los gastos del último mes, por categoría y por tipo de divisa.

Future<Map<String, double>> obtenerGastosPorCategoria(int tabIndex) async {
  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  final gastos = await LocalDatabase.obtenerGastos();
  
  final Map<String, double> mapa = {};

  for (var gasto in gastos) {
    final DateTime fechaGasto = DateTime.parse(gasto['date']);
    final String currencyGasto = gasto['currency'];

    if (fechaGasto.isAfter(firstDayOfMonth)&& currencyGasto==tabsList[tabIndex].data) {
      final categoria = gasto['category'] as String;
      final monto = gasto['amount'] as double;
      mapa[categoria] = (mapa[categoria] ?? 0) + monto;
    }
  }

  return mapa;
}


// funcion para calcular los gastos anuales (ultimo año)

Future<Map<String, double>> obtenerGastosUltimos12Meses(int tabIndex) async {
  final gastos = await LocalDatabase.obtenerGastos();
  final now = DateTime.now();
  final Map<String, double> gastosMensuales = {};

  // Inicializar los últimos 12 meses
  for (int i = 11; i >= 0; i--) {
    final mes = DateTime(now.year, now.month - i, 1);
    final key = DateFormat('yyyy-MM').format(mes);
    gastosMensuales[key] = 0.0;
  }

  // Procesar gastos
  for (var gasto in gastos) {
    final fecha = DateTime.parse(gasto['date']);
    final key = DateFormat('yyyy-MM').format(DateTime(fecha.year, fecha.month));
    
    // Solo sumar si el mes está en nuestros últimos 12 meses
    if (gastosMensuales.containsKey(key) && gasto['currency']== tabsList[tabIndex].data) {
      gastosMensuales[key] = gastosMensuales[key]! + (gasto['amount'] as double);
    }
  }

  return gastosMensuales;
}