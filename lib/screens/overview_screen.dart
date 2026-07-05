// /screens/overview_screen.dart

import 'package:bitacora_financiera/db/models.dart';
import 'package:bitacora_financiera/db/functions.dart';
import 'package:bitacora_financiera/db/notifiers.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';





class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key}); // super parameter

  @override
  OverviewScreenState createState() => OverviewScreenState();
}

class OverviewScreenState extends State<OverviewScreen> with SingleTickerProviderStateMixin{

  
//!                         SingleTicker Controller
  late TabController tabIndexController = TabController(length: 4, vsync: this);
  
//!                         initState Method  
  @override
  void initState() {
    super.initState();
    // Escuchar cambios en los notifiers
    ExpenseNotifiers.overviewNotifier.addListener(_refreshData);
  }

//!                         Dispose Method
  @override
  void dispose() {
    ExpenseNotifiers.overviewNotifier.removeListener(_refreshData);
    super.dispose();
  }

//!                         Refresh Method
  void _refreshData() {
    if (mounted) {
      setState(() {}); // Esto hará que los FutureBuilder se reconstruyan
    }
  }
  

//!                         Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: tabIndexController,
              children:
                List.generate(4, (tabIndex) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPieChartSection(tabIndex),
                      _buildBarChartSection(tabIndex), ],);
                },) 
             ),
          )
        ],
        )
      ),
    );
  }
  
//!                                 Pie Chart ---- Data Integrity Check Method

  Widget _buildPieChartSection(int tabIndex) {
    return ValueListenableBuilder<bool>(
          valueListenable: ExpenseNotifiers.overviewNotifier,
          builder: (BuildContext context, _, __) {
            return FutureBuilder<Map<String, double>>(
              future: obtenerGastosPorCategoria(tabIndex),
              builder: (context, snapshot) {
                
                if (snapshot.connectionState == ConnectionState.waiting) {return const Center(child: CircularProgressIndicator());}
                if (snapshot.hasError) {return Center(child: Text("Error: ${snapshot.error}"));}
                if (snapshot.data == null || snapshot.data!.isEmpty) {return const SizedBox(height: 300,child: Center(child: Text('No hay datos registrados todavia.')),);} // No mostrar nada si no hay datos
                
                return Padding(
                  padding: const EdgeInsets.all(0),
                  child: construirGraficoCircular(snapshot.data!, context, tabIndex),
                );
              },
            );
      },
    );
  }

//!                                Grafico Circular Build

Widget construirGraficoCircular(Map<String, double> datos, BuildContext context, int tabIndex) {
  
  //verifica si no hay datos para hacer el grafico
  if (datos.isEmpty) {return Center(child: Text("No hay datos disponibles"));}

  final colores = [Color.fromRGBO(102, 101, 71, 1),Color.fromRGBO(251, 46, 1, 1),Color.fromRGBO(111, 203, 159, 1),Color.fromRGBO(255, 226, 138, 1),Color.fromRGBO(255, 254, 179, 1),];
        
  //[(0,(String,double)),(1,(String,Double)),(2,(String,Double)),...]
  final List<MapEntry<int,MapEntry<String,double>>> data = datos.entries.toList().asMap().entries.toList();

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
            height: 300,
            child: Stack(
              alignment: AlignmentGeometry.topCenter,
              children: [
                Text("Resumen de Gastos Este Mes", style: style1,),
                PieChart(
                  PieChartData(
                    sections: data.map((entry) {
                      
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
                            
                            if (event.isInterestedForInteractions) {
                              setState(() {
                                showTooltip = true;
                                touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                currentAmount = data[touchedIndex].value.value;
                                tooltipPosition = event.localPosition!;
                                sectionMargin = 10;
                              });
                            }
                            
                            if (!event.isInterestedForInteractions) {
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
                    startDegreeOffset: 0,
                  ),
                  duration: Duration(milliseconds: 100),
                ),
                if (showTooltip) AnimatedPositioned(
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
                        '${NumberFormat.currency(locale: localeList[tabIndex],symbol: '${tabsList[tabIndex].data}',decimalDigits:  decimalList[tabIndex],customPattern: '#,##0.## ¤').format(currentAmount)}.',
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
            NumberFormat.currency(locale: localeList[tabIndex], symbol: '${tabsList[tabIndex].data}', decimalDigits: decimalList[tabIndex],customPattern: '#,##0.## ¤').format(total),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      );
    },
  );
}






//!                                 Bar Chart ---- Data Integrity Check Method

  Widget _buildBarChartSection(int tabIndex) {
  return ValueListenableBuilder<bool>(
    valueListenable: ExpenseNotifiers.overviewNotifier,
    builder: (context,_,__) {
      return  FutureBuilder<Map<String, double>>(
        future: obtenerGastosUltimos12Meses(tabIndex),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {return const Center(child: CircularProgressIndicator());}
          if (snapshot.hasError) {return Center(child: Text("Error: ${snapshot.error}"));}
          if (snapshot.data == null || snapshot.data!.isEmpty) { return Center(child: Padding(padding: EdgeInsets.all(20),child: Text("No hay gastos para graficar",style: style1,textAlign: TextAlign.center,),),);}
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text("Gastos mensuales últimos 12 meses", style: style2),
              construirGraficoBarras(snapshot.data!),
            ],
          );
        },
      );
    },
  );
}



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
    height: 280,
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