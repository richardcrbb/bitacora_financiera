// main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/overview_screen.dart';
import 'screens/add_expenses_screen.dart';
import 'screens/cuenta_papa_screen.dart';
import 'screens/cuenta_papa_list_screen.dart';
import 'screens/expenses_list_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa los datos de localización para español colombiano
  await initializeDateFormatting('es', null);

  // Inicializa Supabase
  bool usarSupabase = true; // ⬅️ Apagar o encender
  if (usarSupabase) {
    await Supabase.initialize(
      url: 'http://192.168.0.10:8000', // Tu URL local de Supabase
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE3MTU1NTAwMDAsImV4cCI6MTk5OTk5OTk5OX0.kavy1ZGC7jBFNGO5IXZ62mWp3BvQVWuxZzLKpaQgBF0',
    );
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitácora Financiera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
        const OverviewScreen(),
        const AgregarGastoScreen(),
        const ExpensesListScreen(),
        const AgregarGastoPapaScreen(),
        const CuentaPapaListScreen(),
        
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitácora Financiera'),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.indigo, 
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Resumen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Nuevo Gasto',
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.list), 
              label: 'Mis Gastos'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Cuenta Papá',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Lista Gastos Papá',
          ),

        ],
      ),
    );
  }
}
