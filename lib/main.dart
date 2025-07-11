// main.dart

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/overview_screen.dart';
import 'screens/add_expenses_screen.dart';
import 'screens/expenses_list_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa los datos de localización para español colombiano
  await initializeDateFormatting('es', null);

  
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitácora Financiera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo,
       brightness: Brightness.dark,
        primaryColor: Colors.indigo[300],
        colorScheme: ColorScheme.dark(
          primary: Colors.indigo[300]!,
          secondary: Colors.amber[300]!,
          surface: const Color(0xFF121212),
          //background: const Color(0xFF121212),
          )
        ),
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
