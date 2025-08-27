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
  
  late Future<List<Map<String, dynamic>>> _cuentas; //futura referencia a la base de datos.
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _setCurrentPage();
  }
//. Funcion para cargar mi base de datos y asignarla en un campo de instancia de esta clase.
  void _refreshData() {
    setState(() {
      _cuentas = _fetchCuentas();
    });
  }
//.Esta funcion obtiene los datos de la db.
  Future<List<Map<String, dynamic>>> _fetchCuentas() async {
    return await PapaLocalDatabase.instance.queryAll();
  }

//.Esta funcion ajusta la currentpage a la ultima.
  Future<void> _setCurrentPage() async {
    List<Map<String,dynamic>> cuentas = await PapaLocalDatabase.instance.queryAll();
    final int itemsPerPage = 20;
    final int totalPages = (cuentas.length/itemsPerPage).ceil();
    setState(() {
      currentPage = totalPages-1;
    });

  }

  //. foramto en pesos sin decimales.
  String _formatMonto(double monto) {
    final formatter = NumberFormat('#,##0', 'es_CO');
    return formatter.format(monto);
  }

  //. elimina un registro
  Future<void> _deleteCuenta(int id) async {
    await PapaLocalDatabase.instance.delete(id);
    _refreshData();
  }

  //.Funcion para editar un registro en el formulario, envia un callback (setState) y el registro (cuenta).
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

  //.formato fecha dia y mes
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

  //.muestra ventana de confirmacion para eliminar, llama a la funcion de eliminar y elimina el registro.
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

  //. Funciones de paginacion

  void _paginaAtras(){
    if(currentPage-1<0){return;}
    setState(() {
      currentPage -= 1;
    });
  }

  void _paginaAdelante(int totalPages ){
    if(currentPage+1 >= totalPages){return;}
    setState(() {
      currentPage +=1;
    });
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
            final int itemsPerPage = 20;
            final int totalPages = (cuentas.length/itemsPerPage).ceil();
            final int startIndex = currentPage*itemsPerPage;
            final int endIndex = (currentPage+1)*itemsPerPage;
            final List<Map<String,dynamic>> sublista = cuentas.sublist(
              startIndex,endIndex < cuentas.length? endIndex:cuentas.length
            );
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
                    itemCount: sublista.length,
                    itemBuilder: (context, index) {
                      final cuenta = sublista[index];
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
                                    color: (cuenta['tipo'] == 'egreso') ? Colors.red : Colors.lightGreenAccent,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(onPressed: () {
                      _paginaAtras();
                    }, icon: Icon(Icons.arrow_back_ios_rounded)),
                    SizedBox(width: 30,),
                    Text('Pag.  ${currentPage+1}'),
                    SizedBox(width: 30,),
                    IconButton(onPressed: () {
                      _paginaAdelante(totalPages);
                    }, icon: Icon(Icons.arrow_forward_ios_rounded))
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }
}