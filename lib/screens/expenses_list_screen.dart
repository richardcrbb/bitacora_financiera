import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../db/local_database.dart';
import 'add_expenses_screen.dart';
import 'package:intl/intl.dart';

final log = Logger('ExpensesListScreen');

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  List<Map<String, dynamic>> _gastos = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final int _pageSize = 100;
  int _totalGastos = 0;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    await _cargarTotalGastos();
    await _cargarGastosPagina(_currentPage);
  }

  Future<void> _cargarTotalGastos() async {
    final total = await LocalDatabase.contarGastos();
    setState(() {
      _totalGastos = total;
    });
  }

  Future<void> _cargarGastosPagina(int pagina) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final gastos = await LocalDatabase.obtenerGastosPaginados(
        limit: _pageSize,
        offset: pagina * _pageSize,
      );
      
      setState(() {
        _gastos = gastos;
        _currentPage = pagina;
        _isLoading = false;
      });
      
      // Scroll al inicio después de cambiar de página
      if (_verticalScrollController.hasClients) {
        _verticalScrollController.jumpTo(0);
      }
      if (_horizontalScrollController.hasClients) {
        _horizontalScrollController.jumpTo(0);
      }
    } catch (e, stacktrace) {
      log.severe('Error al cargar gastos', e, stacktrace);
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar gastos: $e')),
      );
    }
  }

  Future<void> _cargarGastos() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
    });
    try {
      final gastos = await LocalDatabase.obtenerGastosPaginados(
        limit: _pageSize,
        offset: 0,
      );
      setState(() {
        _gastos = gastos;
        _isLoading = false;
      });
    } catch (e, stacktrace) {
      log.severe('Error al cargar gastos', e, stacktrace);
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar gastos: $e')),
      );
    }
  }

  
  Future<void> _eliminarGasto(String uuid) async {
    try {
      await LocalDatabase.eliminarGasto(uuid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto eliminado exitosamente')),
      );
      await _cargarGastos(); // Recargar desde el inicio
    } catch (e, stacktrace) {
      log.severe('Error al eliminar gasto', e, stacktrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar gasto: $e')),
      );
    }
  }

  Widget _buildPaginationControls() {
    final totalPages = (_totalGastos / _pageSize).ceil();
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage >= totalPages - 1 || totalPages == 0;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: isFirstPage
                ? null
                : () => _cargarGastosPagina(0),
            tooltip: 'Primera página',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: isFirstPage
                ? null
                : () => _cargarGastosPagina(_currentPage - 1),
            tooltip: 'Página anterior',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Página ${_currentPage + 1} de ${totalPages == 0 ? 1 : totalPages}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isLastPage
                ? null
                : () => _cargarGastosPagina(_currentPage + 1),
            tooltip: 'Página siguiente',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: isLastPage
                ? null
                : () => _cargarGastosPagina(totalPages - 1),
            tooltip: 'Última página',
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoOpciones(Map<String, dynamic> gasto) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Opciones del Gasto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.pop(context);
                  _editarGasto(gasto);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarDialogoConfirmacion(gasto['uuid']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDialogoConfirmacion(String uuid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar este gasto?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _eliminarGasto(uuid);
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _editarGasto(Map<String, dynamic> gasto) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgregarGastoScreen(
          gastoExistente: gasto,
        ),
      ),
    );

    if (resultado == true) {
      await _cargarGastos();
    }
  }

  Widget _buildHeaderCell(String text, {double width = 120}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(dynamic value, {bool isAmount = false, bool isDate = false, double width = 120}) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
      locale: 'es_CO',
    );

    String textValue;
    if (value == null) {
      textValue = '-';
    } else if (isDate) {
      textValue = dateFormat.format(DateTime.parse(value));
    } else if (isAmount) {
      textValue = currencyFormat.format(value);
    } else {
      textValue = value.toString();
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        textValue,
        style: TextStyle(
          fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
          color: isAmount ? Colors.indigo : Colors.black,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }


@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final columnWidth = screenWidth / 7;
  final idWidth = columnWidth * 0.7;
  final categoriaWidth = columnWidth * 2;
  final descripcionWidth = columnWidth * 4;
  final montoWidth = columnWidth * 3;
  final monedaWidth = columnWidth * 1;
  final metododepagoWidth = columnWidth * 2;
  final fechaWidth = columnWidth * 2;
  final sincronizadoWidth = columnWidth * 2;

  return Scaffold(
    appBar: AppBar(
      title: const Text('Registro de Gastos'),
    ),
    body: Column(
      children: [
        // Mostrar información del total de registros y página actual
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total de gastos: $_totalGastos',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Página ${_currentPage + 1} de ${(_totalGastos / _pageSize).ceil()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        // Controles de paginación
        _buildPaginationControls(),
        
        Expanded(
          child: _isLoading && _gastos.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _gastos.isEmpty
                  ? const Center(child: Text('No hay gastos registrados'))
                  : Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) => notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 0,
                              horizontalMargin: 0,
                              columns: [
                                DataColumn(label: _buildHeaderCell('ID', width: idWidth)),
                                DataColumn(label: _buildHeaderCell('Categoría', width: categoriaWidth)),
                                DataColumn(label: _buildHeaderCell('Descripción', width: descripcionWidth)),
                                DataColumn(label: _buildHeaderCell('Monto', width: montoWidth)),
                                DataColumn(label: _buildHeaderCell('Moneda', width: monedaWidth)),
                                DataColumn(label: _buildHeaderCell('Método Pago', width: metododepagoWidth)),
                                DataColumn(label: _buildHeaderCell('Fecha', width: fechaWidth)),
                                DataColumn(label: _buildHeaderCell('Sincronizado', width: sincronizadoWidth)),
                              ],
                              rows: _gastos.map((gasto) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      _buildDataCell(gasto['id'], width: idWidth),
                                      onLongPress: () => _mostrarDialogoOpciones(gasto),
                                    ),
                                    DataCell(
                                      _buildDataCell(gasto['category'], width: categoriaWidth),
                                      onLongPress: () => _mostrarDialogoOpciones(gasto),
                                    ),
                                    DataCell(
                                      _buildDataCell(gasto['description'], width: descripcionWidth),
                                      onLongPress: () => _mostrarDialogoOpciones(gasto),
                                    ),
                                    DataCell(
                                      _buildDataCell(gasto['amount'], isAmount: true, width: montoWidth),
                                      onLongPress: () => _mostrarDialogoOpciones(gasto),
                                    ),
                                    DataCell(
                                      _buildDataCell(gasto['currency'], width: monedaWidth),
                                      onLongPress: () => _mostrarDialogoOpciones(gasto),
                                    ),
                                    DataCell(
                                      _buildDataCell(gasto['payment_method'], width: metododepagoWidth),
                                      onLongPress: () => _mostrarDialogoOpciones(gasto),
                                    ),
                                    DataCell(
                                      _buildDataCell(gasto['date'], isDate: true, width: fechaWidth),
                                      onLongPress: () => _mostrarDialogoOpciones(gasto),
                                    ),
                                    DataCell(
                                      _buildDataCell(gasto['sincronizado'] == 1 ? '✓' : '✗', width: sincronizadoWidth),
                                      onLongPress: () => _mostrarDialogoOpciones(gasto),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
        
        // Controles de paginación en la parte inferior
        _buildPaginationControls(),
        
        // Indicador de carga cuando se están cargando datos
        if (_isLoading && _gastos.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
      ],
    ),
  );
}

}