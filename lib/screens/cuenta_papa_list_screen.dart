import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/papa_local_database.dart';
import 'cuenta_papa_screen.dart'; // Importamos la pantalla de edición

class CuentaPapaListScreen extends StatefulWidget {
  const CuentaPapaListScreen({super.key});

  @override
  CuentaPapaListScreenState createState() => CuentaPapaListScreenState();
}

class CuentaPapaListScreenState extends State<CuentaPapaListScreen> {
  late Future<List<Map<String, dynamic>>> _cuentas;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _cuentas = _fetchCuentas();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchCuentas() async {
    return await PapaLocalDatabase.instance.queryAll();
  }

  String _formatMonto(double monto) {
    final formatter = NumberFormat('#,##0', 'es_CO');
    return formatter.format(monto);
  }

  Future<void> _deleteCuenta(int id) async {
    await PapaLocalDatabase.instance.delete(id);
    _refreshData();
  }

  void _showEditDialog(Map<String, dynamic> cuenta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgregarGastoPapaScreen(
          cuentaExistente: cuenta,
          onGastoGuardado: _refreshData,
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
  try {
    // Parsear la fecha (ajusta esto según el formato de tu fecha original)
    DateTime date = DateTime.parse(dateString);
    // Formatear para mostrar solo día y mes (ejemplo: "21 May")
    return DateFormat('d MMM').format(date);
  } catch (e) {
    // En caso de error, devolver la fecha original o un valor por defecto
    return dateString;
  }
}

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar este registro?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Eliminar'),
              onPressed: () {
                _deleteCuenta(id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listado de Cuenta Papá')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cuentas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay registros'));
          } else {
            final cuentas = snapshot.data!;
            return Column(
              children: [
                // Header (sin cambios)
                Container(
                  color: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    children: const [
                      SizedBox(width: 30, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      SizedBox(width: 50, child: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold))),
                      SizedBox(width: 90, child: Text('Monto', style: TextStyle(fontWeight: FontWeight.bold))),
                      SizedBox(width: 90, child: Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: cuentas.length,
                    itemBuilder: (context, index) {
                      final cuenta = cuentas[index];
                      return GestureDetector(
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: const Text('Editar'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showEditDialog(cuenta);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.red),
                                      title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showDeleteConfirmation(cuenta['id']);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(cuenta['id'].toString()),
                              ),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  _formatDate(cuenta['fecha']),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(cuenta['descripcion'] ?? 'No descripción', textAlign: TextAlign.center),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '\$${_formatMonto(cuenta['monto'] ?? 0.0)}',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: (cuenta['tipo'] == 'egreso') ? Colors.red : Colors.black,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '\$${_formatMonto(cuenta['saldo'] ?? 0.0)}',
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}