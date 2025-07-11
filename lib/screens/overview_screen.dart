// /screens/overview_screen.dart

import 'package:bitacora_financiera/db/notifiers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bitacora_financiera/db/local_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';





class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key}); // super parameter

  @override
  OverviewScreenState createState() => OverviewScreenState();
}

class OverviewScreenState extends State<OverviewScreen> {
  
  bool _sincronizando = false;

 
  @override
  void initState() {
    super.initState();
    // Escuchar cambios en los notifiers
    ExpenseNotifiers.overviewNotifier.addListener(_refreshData);
  }

  @override
  void dispose() {
    ExpenseNotifiers.overviewNotifier.removeListener(_refreshData);
    super.dispose();
  }

  void _refreshData() {
    if (mounted) {
      setState(() {}); // Esto hará que los FutureBuilder se reconstruyan
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Resumen de Gastos", 
        style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPieChartSection(),
            _buildBarChartSection(),
            _buildSyncButtons(),
          ],
        ),
      ),
    );
  }
  

  Widget _buildPieChartSection() {
    return ValueListenableBuilder<bool>(
          valueListenable: ExpenseNotifiers.overviewNotifier,
          builder: (BuildContext context, _, child) {
            return FutureBuilder<Map<String, double>>(
              future: obtenerGastosPorCategoria(),
              builder: (context, snapshot) {
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                
                final datos = snapshot.data;
                if (datos == null || datos.isEmpty) {
                  return const SizedBox.shrink(); // No mostrar nada si no hay datos
                }
                
                return Padding(
                  padding: const EdgeInsets.all(0),
                  child: construirGraficoCircular(datos, context),
                );
              },
            );
      },
    );
  }

  Widget _buildBarChartSection() {
  return ValueListenableBuilder<bool>(
    valueListenable: ExpenseNotifiers.overviewNotifier,
    builder: (context,_,child) {
      return  FutureBuilder<Map<String, double>>(
        future: obtenerGastosUltimos12Meses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          
          final datos = snapshot.data;
          if (datos == null || datos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "No hay gastos para graficar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          
          return Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                const Text("Gastos mensuales últimos 12 meses", 
                  style: TextStyle(fontSize: 18)),
                construirGraficoBarras(datos),
              ],
            ),
          );
        },
      );
    },
  );
}

  Widget _buildSyncButtons() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(0),
          child: ElevatedButton.icon(
            onPressed: _sincronizando ? null : _sincronizarConSupabase,
            icon: const Icon(Icons.sync),
            label: Text(_sincronizando ? "Sincronizando..." : "Sincronizar con Supabase"),
          ),
        ),
      ],
    );
  }
  

 // Inicializa Supabase

Future<void> _inicializarSupabaseSiEsNecesario() async {
  try {
    // Verifica si ya está inicializado
    Supabase.instance.client;
  } catch (_) {
    // Si no está inicializado, lo inicializa
    await Supabase.initialize(
      url: 'http://192.168.0.10:8000',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE3MTU1NTAwMDAsImV4cCI6MTk5OTk5OTk5OX0.kavy1ZGC7jBFNGO5IXZ62mWp3BvQVWuxZzLKpaQgBF0',
    );
  }
}


// funcion de sincronizacion mia


Future<void> _sincronizarConSupabase() async {
  
 
setState(() => _sincronizando = true);
 

  try {

    //inicializa supabase
    await _inicializarSupabaseSiEsNecesario();


    //Lista que almacena los datos no sincronizados por orden de id.
    final gastosLocales = List.from(await LocalDatabase.obtenerGastosNoSincronizados())
     ..sort((a, b) => a['id'].compareTo(b['id']));

    
    //Mensaje que avisa si no hay datos para sincronizar
    if (gastosLocales.isEmpty) {
      throw Exception("No hay gastos locales para sincronizar");
    }

    //Lista de datos ya organizados listos para sincronizar.
    final List<Map<String, dynamic>> datosParaUpsert = [];

    //for loop para organizar y verificar tipo de datos correctos.
    for (var gasto in gastosLocales) {
      final uuid = gasto['uuid'];
      if (uuid == null) continue;

      // Asegura que 'amount' sea numero tipo <double>
      if (gasto['amount'] is String) {
        gasto['amount'] = double.tryParse(gasto['amount']) ?? 0.0;
      }

      // Formato de fecha seguro<AAAA-MM-DD>
      String fechaFormateada;
      try {
        fechaFormateada = DateTime.parse(gasto['date']).toIso8601String().split('T').first;
      } catch (_) {
        fechaFormateada = DateTime.now().toIso8601String().split('T').first;
      }

      //añade los valores de este gasto a la Lista de datos para upsert ya corregidos o formateados y chequeados.
      datosParaUpsert.add({
        'uuid': uuid,
        'category': gasto['category'],
        'description': gasto['description'],
        'amount': gasto['amount'],
        'currency': gasto['currency'],
        'payment_method': gasto['payment_method'],
        'date': fechaFormateada,
      });
    }

    //Verifica que la Lista no este vacia, funcion que sincroniza con supabase los gastos de la Lista
    if (datosParaUpsert.isNotEmpty) {
      final response = await Supabase.instance.client
          .from('expenses')
          .upsert(datosParaUpsert, onConflict: 'uuid')
          .select();

      for (var gasto in gastosLocales) {
        await LocalDatabase.marcarGastoComoSincronizado(gasto['uuid']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${response.length} gasto(s) sincronizado(s) correctamente"),
          ),
        );
      }
    }
  } on PostgrestException catch (e) {
    debugPrint('❌ Error de Supabase: ${e.code}:  ${e.message}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error Supabase: ${ e.details ?? e.message}")),
      );
    }
  } catch (e) {
    debugPrint('⚠️ Error desconocido: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error al sincronizar: $e")),
      );
    }
  } finally {
    setState(() {
      _sincronizando = false;
    });
  }
}

}







//Funcion para obtener los gastos por categoria mensual

// Función para obtener los gastos por categoría del último mes
Future<Map<String, double>> obtenerGastosPorCategoria() async {
  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  final gastos = await LocalDatabase.obtenerGastos();
  
  final Map<String, double> mapa = {};

  for (var gasto in gastos) {
    final fechaGasto = DateTime.parse(gasto['date']);
    if (fechaGasto.isAfter(firstDayOfMonth)) {
      final categoria = gasto['category'] as String;
      final monto = gasto['amount'] as double;
      mapa[categoria] = (mapa[categoria] ?? 0) + monto;
    }
  }

  return mapa;
}


// funcion para calcular los gastos del ultimo año

Future<Map<String, double>> obtenerGastosUltimos12Meses() async {
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
    if (gastosMensuales.containsKey(key)) {
      gastosMensuales[key] = gastosMensuales[key]! + (gasto['amount'] as double);
    }
  }

  return gastosMensuales;
}





// Grafico Circular 

Widget construirGraficoCircular(Map<String, double> datos, BuildContext context) {
  
  //verifica si no hay datos para hacer el grafico
  if (datos.isEmpty) {return Center(child: Text("No hay datos disponibles"));}

  final colores = [
    Colors.red, Colors.blue, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.brown,
  ];

  double total = datos.values.fold(0, (sum, val) => sum + val);
  
  // Variable para controlar la visibilidad del tooltip
  int touchedIndex =0;
  bool showTooltip = false;
  double currentAmount = 0;
  Offset tooltipPosition = Offset.zero;
  double sectionMargin = 2;

  return StatefulBuilder(
    builder: (context, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sections: datos.entries.toList().asMap().entries.map((entry) {
                      
                      final index = entry.key;
                      final value = entry.value.value;
                      final cat = entry.value.key;
                      final color = colores[index % colores.length];
                      final bool isTouched = showTooltip && touchedIndex == index ;
                      
                      return PieChartSectionData(
                        value: value,
                        title: cat,
                        titlePositionPercentageOffset: isTouched ? .99 : .5,
                        color: color,
                        radius: isTouched ? 150 : 120,
                        titleStyle: isTouched ? 
                        
                          const TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                          )
                          :
                          const TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          ),
                      );
                    }).toList(),
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (pieTouchResponse?.touchedSection != null && pieTouchResponse!.touchedSection!.touchedSectionIndex >= 0) {
                          final section = pieTouchResponse.touchedSection!;
                          final category = datos.keys.elementAt(section.touchedSectionIndex);
                          final amount = datos[category]!;
                          
                          if (event is FlLongPressStart || 
                              event is FlLongPressMoveUpdate ||
                              event is FlPanStartEvent ||
                              event is FlPanUpdateEvent) {
                            setState(() {
                              showTooltip = true;
                              currentAmount = amount;
                              tooltipPosition = event.localPosition!;
                              touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              sectionMargin = 10;
                            });
                          }
                          
                          if (event is FlLongPressEnd || event is FlPanEndEvent) {
                            setState(() {
                              showTooltip = false;
                              sectionMargin = 2;
                            });
                          }
                        } else if (event is FlLongPressEnd || event is FlPanEndEvent) {
                          setState(() {
                            showTooltip = false;
                            sectionMargin = 2;
                          });
                        }
                      },
                      enabled: true,
                      longPressDuration: const Duration(milliseconds: 100),
                    ),
                    centerSpaceRadius: 0,
                    sectionsSpace: sectionMargin,
                    startDegreeOffset: 180,
                  ),
                  swapAnimationDuration: Duration(milliseconds: 100),
                ),
                if (showTooltip)
                  AnimatedPositioned(
                    duration: Duration(milliseconds: 200),
                    left: tooltipPosition.dx - 70,
                    top: tooltipPosition.dy -100,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        '${NumberFormat("#,##0", "es_COP").format(currentAmount)} pesos.',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Total de gastos del mes de ${DateFormat('MMMM', 'es_CO').format(DateTime.now())}:",
            style: const TextStyle(fontSize: 18),
          ),
          Text(
            NumberFormat.currency(locale: 'es_CO', symbol: 'COP', decimalDigits: 0).format(total),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      );
    },
  );
}





















// función auxiliar para calcular intervalos adecuados para el eje Y
double calcularIntervalos(double maxValue) {
  if (maxValue <= 0) return 10.0;
  
  // Calcular un intervalo "lindo" para el eje Y
  final potencia = (log(maxValue) / ln10).floor();
  final maxSinPotencia = maxValue / pow(10, potencia);
  
  double intervalo;
  if (maxSinPotencia <= 2) {
    intervalo = 0.5;
  } else if (maxSinPotencia <= 5) {
    intervalo = 1.0;
  } else if (maxSinPotencia <= 10) {
    intervalo = 2.0;
  } else {
    intervalo = 5.0;
  }
  
  return (intervalo * pow(10, potencia)).toDouble();
}















// grafico de barras del ultimo año




Widget construirGraficoBarras(Map<String, double> datos) {
  final meses = datos.keys.toList();
  final valores = datos.values.toList();
  
  final maxY = valores.isNotEmpty ? valores.reduce((a, b) => a > b ? a : b) * 1.2 : 100.0;
  final intervalos = calcularIntervalos(maxY);

  return SizedBox(
    height: 180,
    child: BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barGroups: List.generate(meses.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: valores[index],
                color: Colors.blue,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          );
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= meses.length) return Container();
                final mes = DateFormat.MMM('es_CO').format(DateTime.parse('${meses[value.toInt()]}-01'));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(mes, style: const TextStyle(fontSize: 10)),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    NumberFormat.compactCurrency(
                      decimalDigits: 0,
                      symbol: '',
                      locale: 'es_CO'
                    ).format(value),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              interval: intervalos,
              reservedSize: 40,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Color.lerp(Colors.grey, Colors.transparent, 0.7)!, // Reemplazo para withOpacity(0.3)
              strokeWidth: 1,
            );
          },
          checkToShowHorizontalLine: (value) => value % intervalos == 0,
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: Color.lerp(Colors.grey, Colors.transparent, 0.5)!, // Reemplazo para withOpacity(0.5)
              width: 1,
            ),
            left: BorderSide(
              color: Color.lerp(Colors.grey, Colors.transparent, 0.5)!, // Reemplazo para withOpacity(0.5)
              width: 1,
            ),
          ),
        ),
      ),
    ),
  );
}