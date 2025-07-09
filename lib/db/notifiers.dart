import 'package:flutter/foundation.dart';

class ExpenseNotifiers {
  // Notifier para la lista de gastos
  static final ValueNotifier<bool> expenseListNotifier = ValueNotifier(false);
  
  // Notifier para el resumen/gráficos
  static final ValueNotifier<bool> overviewNotifier = ValueNotifier(false);

  // Método para actualizar todos
  static void refreshAll() {
    expenseListNotifier.value = !expenseListNotifier.value;
    overviewNotifier.value = !overviewNotifier.value;
  }
}