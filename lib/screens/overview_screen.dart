// /screens/overview_screen.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';  
import 'package:bitacora_financiera/db/notifiers.dart';
import 'package:flutter/material.dart';
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        "No hay gastos registrados este mes para mostrar en el gráfico",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ); // No mostrar nada si no hay datos
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
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.save_alt),
          label: Text(_sincronizando ? 'Exportando...' : 'Exportar Base de Datos'),
          onPressed: _sincronizando ? null : () async {
            final path = await _exportarDatabase();
            if (path != null) await _abrirArchivo(path);
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: Text(_sincronizando ? 'Importando...' : 'Importar Base de Datos'),
          onPressed: _sincronizando ? null : _importarDatabase,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    ),
  );
}
  



// funcion de exportacion .db
  Future<String?> _exportarDatabase() async {
    setState(() => _sincronizando = true);
    
    try {
      // Verificar permisos en Android
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) return null;
      }

      final db = await LocalDatabase.database;
      final sourceFile = File(db.path);
      
      Directory targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = (await getExternalStorageDirectory())!;
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final exportFile = File('${targetDir.path}/bitacora_$timestamp.db');
      await sourceFile.copy(exportFile.path);
      
      return exportFile.path;
    } catch (e) {
      debugPrint('Error al exportar: $e');
      return null;
    } finally {
      setState(() => _sincronizando = false);
    }
  }

  Future<void> _abrirArchivo(String filePath) async {
    try {

      

      final params = ShareParams(     
        files:[XFile(filePath, mimeType: 'application/x-sqlite3')],
        subject: 'Backup Bitácora Financiera',
        text: 'Copia de seguridad ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      );
      
      final result = await SharePlus.instance.share(params);

      if (result.status == ShareResultStatus.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Archivo compartido'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }



// Agrega este nuevo método para importar la base de datos



Future<void> _importarDatabase() async {
  setState(() => _sincronizando = true);

  try {
    // Solicitar permisos en Android
    if (Platform.isAndroid) {
      final permiso = await Permission.storage.request();
      if (!mounted) return;
      if (!permiso.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Permiso de almacenamiento denegado')),
        );
        return;
      }
    }

    // Elegir archivo .db
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (resultado == null || resultado.files.single.path == null) {
      return; // Cancelado por el usuario
    }

    final archivoSeleccionado = File(resultado.files.single.path!);

    // Obtener el path de la base de datos de la app
    final baseDatos = await LocalDatabase.database;
    final pathDestino = baseDatos.path;

    // Cerrar la base de datos antes de sobrescribirla
    await baseDatos.close();

    // Reemplazar la base de datos
    await archivoSeleccionado.copy(pathDestino);

    // Volver a abrir la base de datos
    await LocalDatabase.reiniciarBaseDeDatos();

    // Notificar a los listeners que deben actualizarse
    ExpenseNotifiers.overviewNotifier.value = !ExpenseNotifiers.overviewNotifier.value;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Base de datos importada con éxito')),
      );
    }
  } catch (e) {
    debugPrint('Error al importar la base de datos: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al importar: $e')),
      );
    }
  } finally {
    setState(() => _sincronizando = false);
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
    final fechaGasto = DateTime.parse(gasto['fecha']);
    if (fechaGasto.isAfter(firstDayOfMonth)) {
      final categoria = gasto['categoria'] as String;
      final monto = gasto['monto'] as double;
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
    final fecha = DateTime.parse(gasto['fecha']);
    final key = DateFormat('yyyy-MM').format(DateTime(fecha.year, fecha.month));
    
    // Solo sumar si el mes está en nuestros últimos 12 meses
    if (gastosMensuales.containsKey(key)) {
      gastosMensuales[key] = gastosMensuales[key]! + (gasto['monto'] as double);
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
                          if (event is FlLongPressEnd || event is FlPanEndEvent) {
                          setState(() {
                            showTooltip = false;
                            sectionMargin = 2;
                          });
                          }
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
            NumberFormat.currency(locale: 'en_AE', symbol: 'AED ', decimalDigits: 0).format(total),
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
}