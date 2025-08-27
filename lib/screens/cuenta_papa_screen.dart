                                                  //! screens/cuenta_papa_screen.dart

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '/db/papa_local_database.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final log = Logger('AgregarGastoScreen');
final uuid = Uuid();

class AgregarGastoPapaScreen extends StatefulWidget {
  final VoidCallback? onGastoGuardado;
  final Map<String, dynamic>? cuentaExistente;
  const AgregarGastoPapaScreen({
    super.key, 
    this.onGastoGuardado,
    this.cuentaExistente,
  });

  @override
  State<AgregarGastoPapaScreen> createState() => _AgregarGastoPapaScreenState();
}

class _AgregarGastoPapaScreenState extends State<AgregarGastoPapaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();
  String _categoriaSeleccionada = 'Investments';
  String _tipoSeleccionado = 'egreso';
  DateTime _fechaSeleccionada = DateTime.now();
  String? _uuid;

  // Agregar el formateador personalizado
  final _montoFormatter = NumberTextInputFormatter(
    decimalDigits: 2,
    thousandSeparator: ',',
    decimalSeparator: '.',
  );
  
  @override
  void initState() {
    super.initState();
    
    // Si estamos editando un registro existente, cargamos sus datos
    if (widget.cuentaExistente != null) {
      final cuenta = widget.cuentaExistente!;
      _montoController.text = NumberFormat('#,##0.00').format(cuenta['monto']);
      _descripcionController.text = cuenta['descripcion'] ?? '';
      _categoriaSeleccionada = cuenta['categoria'] ?? 'Investments';
      _tipoSeleccionado = cuenta['tipo'] ?? 'egreso';
      _fechaSeleccionada = DateTime.parse(cuenta['fecha']);
      _uuid = cuenta['uuid'];
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
  

  Future<void> _seleccionarFecha() async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null && fecha != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = fecha;
      });
    }
  }

  Future<void> _guardarGasto() async {
  if (!_formKey.currentState!.validate()) return;

  final monto = _montoFormatter.getUnformattedValue(_montoController.text);

  if (monto <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor ingresa un monto válido')),
    );
    return;
  }

  final descripcion = _descripcionController.text;
  final uuid = _uuid ?? Uuid().v4();

  try {
    final row = {
      'uuid': uuid,
      'monto': monto,
      'descripcion': descripcion,
      'categoria': _categoriaSeleccionada,
      'tipo': _tipoSeleccionado,
      'fecha': _fechaSeleccionada.toIso8601String(),
      'generado': DateTime.now().toIso8601String(),
    };

    if (widget.cuentaExistente != null) {
      await PapaLocalDatabase.instance.actualizarGasto(
        widget.cuentaExistente!['id'], 
        row
      );
    } else {
      await PapaLocalDatabase.instance.insertarGasto(row);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Gasto guardado exitosamente')),
    );
    widget.onGastoGuardado?.call();
  } catch (e, stacktrace) {
    log.severe('❌ Error al guardar el gasto', e, stacktrace);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Error al guardar el gasto: $e')),
    );
  }
  }

// Eliminar los métodos _recalcularSaldosPosteriores y _calcularSaldoParaEdicion
// ya que ahora los triggers se encargan de esto

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Gasto De Papá')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_montoFormatter],
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  hintText: '0.00',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un monto';
                  }
                  final monto = _montoFormatter.getUnformattedValue(value);
                  if (monto <= 0) {
                    return 'El monto debe ser mayor a cero';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              DropdownButtonFormField<String>(
                value: _categoriaSeleccionada,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  'Food', 'Transport', 'Entertainment', 'Housing', 'Utilities',
                  'Healthcare', 'Education', 'Insurance', 'Shopping',
                  'Personal Care', 'Travel', 'Dining Out', 'Gifts',
                  'Savings', 'Investments', 'Miscellaneous',
                ].map((categoria) {
                  return DropdownMenuItem(value: categoria, child: Text(categoria));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _categoriaSeleccionada = value;
                    });
                  }
                },
              ),
              DropdownButtonFormField<String>(
                value: _tipoSeleccionado,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: ['egreso', 'ingreso'].map((tipo) {
                  return DropdownMenuItem(value: tipo, child: Text(tipo));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _tipoSeleccionado = value;
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_fechaSeleccionada.year == DateTime.now().year &&
                  _fechaSeleccionada.month == DateTime.now().month &&
                  _fechaSeleccionada.day == DateTime.now().day
                  ? 'Hoy'
                  :DateFormat('dd-MMM-yyyy').format(_fechaSeleccionada)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _seleccionarFecha,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardarGasto,
                child: const Text('Guardar Gasto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Asegúrate de que esta clase esté disponible (puede estar en un archivo separado)
class NumberTextInputFormatter extends TextInputFormatter {
  final int decimalDigits;
  final String thousandSeparator;
  final String decimalSeparator;

  NumberTextInputFormatter({
    this.decimalDigits = 2,
    this.thousandSeparator = ',',
    this.decimalSeparator = '.',
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Permitir solo números y un separador decimal
    if (newValue.text.replaceAll(thousandSeparator, '').replaceAll(decimalSeparator, '').split('').any((c) => !RegExp(r'[\d.]').hasMatch(c))) {
      return oldValue;
    }

     // Manejar múltiples puntos decimales
    if (newValue.text.split(decimalSeparator).length > 2) {
      return oldValue;
    }

    String newText = newValue.text.replaceAll(thousandSeparator, '');

    // Si hay un separador decimal, dividir en partes entera y decimal
    bool hasDecimal = newText.contains(decimalSeparator);
    String integerPart = hasDecimal ? newText.split(decimalSeparator)[0] : newText;
    String decimalPart = hasDecimal ? newText.split(decimalSeparator)[1] : '';

    // Limitar dígitos decimales
    if (decimalPart.length > decimalDigits) {
      decimalPart = decimalPart.substring(0, decimalDigits);
      newText = '$integerPart$decimalSeparator$decimalPart';
    }

     // Formatear parte entera con separadores de miles
    String formattedInteger = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formattedInteger += thousandSeparator;
      }
      formattedInteger += integerPart[i];
    }

       // Construir texto formateado
    String formattedText = hasDecimal || decimalPart.isNotEmpty
        ? '$formattedInteger$decimalSeparator$decimalPart'
        : formattedInteger;

      // Ajustar posición del cursor
    int cursorPosition = newValue.selection.end;
    int addedSeparators = formattedText.length - newText.length;
    cursorPosition += addedSeparators;
    cursorPosition = cursorPosition.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );

  }

  double getUnformattedValue(String value) {
    final cleanText = value
        .replaceAll(thousandSeparator, '')
        .replaceAll(decimalSeparator, '.');
    return double.tryParse(cleanText) ?? 0;
  }
}