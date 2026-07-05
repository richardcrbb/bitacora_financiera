import 'package:flutter/material.dart';
//import 'package:supabase_flutter/supabase_flutter.dart';
//import 'package:bitacora_financiera/db/papa_local_database.dart';


class Settings extends StatelessWidget {
  
  const Settings({super.key});



  final bool _sincronizando = false;

/*

   // Inicializa Supabase

Future<void> _inicializarSupabaseSiEsNecesario() async {
  try {
    // Verifica si ya está inicializado
    Supabase.instance.client;
  } catch (_) {
    // Si no está inicializado, lo inicializa
    await Supabase.initialize(
      url: 'http://192.168.0.10:8000',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzU3OTEyNDAwLCJleHAiOjE5MTU2Nzg4MDB9.DgcWxNy_0GdnDMVvNQ2zMuKLX5l93cHIZyQaa7aW7qc',
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

// funcion de sincronizacion papa

Future<void> _sincronizarConSupabasePapa() async {

   setState(() => _sincronizando = true);

  try {

     //inicializa supabase
     await _inicializarSupabaseSiEsNecesario();

    //Lista que almacena los datos no sincronizados por orden de id.
    final gastosLocales = List.from(await PapaLocalDatabase.instance.obtenerGastosNoSincronizados())
      ..sort((a, b) => a['id'].compareTo(b['id']));

    //Mensaje que avisa si no hay datos para sincronizar
    if (gastosLocales.isEmpty) {
      throw Exception("No hay gastos de cuenta_papa para sincronizar");
    }

    //Lista de datos ya organizados listos para sincronizar.
    final List<Map<String, dynamic>> datosParaUpsert = [];

    //for loop para organizar y verificar tipo de datos correctos.
    for (var gasto in gastosLocales) {
      final uuid = gasto['uuid'];
      if (uuid == null) continue;

      // Asegura que 'monto' sea numero tipo <double>
      if (gasto['monto'] is String) {
        gasto['monto'] = double.tryParse(gasto['monto']) ?? 0.0;
      }

      // Formato de fecha seguro<AAAA-MM-DD>
      String fechaFormateada;
      try {
        fechaFormateada = DateTime.parse(gasto['fecha']).toIso8601String().split('T').first;
      } catch (_) {
        fechaFormateada = DateTime.now().toIso8601String().split('T').first;
      }

      //añade los valores de este gasto a la Lista de datos para upsert ya corregidos o formateados y chequeados.
      datosParaUpsert.add({
        'uuid': uuid,
        'categoria': gasto['categoria'],
        'descripcion': gasto['descripcion'],
        'tipo': gasto['tipo'],
        'monto': gasto['monto'],
        'saldo': gasto['saldo'],
        'fecha': fechaFormateada,
        'generado': gasto['generado'],
      });
    }

    //Verifica que la Lista no este vacia, funcion que sincroniza con supabase los gastos de la Lista
    if (datosParaUpsert.isNotEmpty) {
      final response = await Supabase.instance.client
          .from('cuenta_papa') 
          .upsert(datosParaUpsert, onConflict: 'uuid')
          .select();

      for (var gasto in gastosLocales) {
        await PapaLocalDatabase.instance.marcarGastoComoSincronizado(gasto['uuid']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${response.length} gasto(s) de cuenta_papa sincronizado(s)"),
          ),
        );
      }
    }
  } on PostgrestException catch (e) {
    debugPrint('❌ Error Supabase cuenta_papa: (${e.code}) : (${e.message})');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error Supabase: ${ e.details ?? e.message}")),
      );
    }
  } catch (e, stackTrace) {
    debugPrint('⚠️ Error cuenta_papa: $e');
    debugPrint('🪵 StackTrace: $stackTrace');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error al sincronizar cuenta_papa: $e")),
      );
    }
  } finally {
    setState(() {
      _sincronizando = false;
    });
  }
}

*/

  @override
  Widget build(BuildContext context) {
    return  Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(0),
          child: ElevatedButton.icon(
            onPressed: null,//_sincronizando ? null : _sincronizarConSupabase,
            icon: const Icon(Icons.sync),
            label: Text(_sincronizando ? "Sincronizando..." : "Sincronizar con Supabase"),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(0),
          child: ElevatedButton.icon(
            onPressed: null, //_sincronizando ? null : _sincronizarConSupabasePapa,
            icon: const Icon(Icons.sync_alt),
            label: Text(_sincronizando ? "Sincronizando..." : "Sincronizar cuenta_papa"),
          ),
        ),
      ],
    );
  }
  
}