import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app_strings.dart';
import '../database/db_helper.dart';
import '../utils/time_utils.dart';

class _TimeTableInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  const _TimeTableInputWidget({required this.controller, this.onChanged});

  @override
  State<_TimeTableInputWidget> createState() => _TimeTableInputWidgetState();
}

class _TimeTableInputWidgetState extends State<_TimeTableInputWidget> {
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    String val = widget.controller.text;
    if (val.isEmpty) val = '00:00';
    final parts = val.split(':');
    _hourController = TextEditingController(text: parts.length > 0 ? parts[0] : '00');
    _minuteController = TextEditingController(text: parts.length > 1 ? parts[1] : '00');
  }

  @override
  void didUpdateWidget(_TimeTableInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _initControllers();
    }
  }

  void _updateMain() {
    final h = _hourController.text.isEmpty ? '00' : _hourController.text.padLeft(2, '0');
    final m = _minuteController.text.isEmpty ? '00' : _minuteController.text.padLeft(2, '0');
    widget.controller.text = "$h:$m";
    if (widget.onChanged != null) widget.onChanged!();
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_hourFocus.hasFocus && !_minuteFocus.hasFocus) {
          _hourFocus.requestFocus();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hour field
            SizedBox(
              width: 24,
              child: TextFormField(
                controller: _hourController,
                focusNode: _hourFocus,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '00',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onChanged: (v) {
                  if (v.length == 2) {
                    final h = int.tryParse(v) ?? 0;
                    if (h > 23) {
                      _hourController.text = '23';
                    }
                    _minuteFocus.requestFocus();
                  }
                  _updateMain();
                },
              ),
            ),
            // Static colon
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                ':',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            // Minute field
            SizedBox(
              width: 24,
              child: TextFormField(
                controller: _minuteController,
                focusNode: _minuteFocus,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '00',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onChanged: (v) {
                  if (v.length == 2) {
                    final m = int.tryParse(v) ?? 0;
                    if (m > 59) {
                      _minuteController.text = '59';
                    }
                  }
                  _updateMain();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductionReportScreen extends StatefulWidget {
  const ProductionReportScreen({
    super.key, 
    required this.currentUsername, 
    this.isEmbedded = false,
    this.initialData,
    this.isReadOnly = false,
  });
  final String currentUsername;
  final bool isEmbedded;
  final Map<String, dynamic>? initialData;
  final bool isReadOnly;

  @override
  State<ProductionReportScreen> createState() => _ProductionReportScreenState();
}

class _ProductionReportScreenState extends State<ProductionReportScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  final _formKey = GlobalKey<FormState>();

  // Header data
  String? _selectedLine;
  DateTime _selectedDate = DateTime.now();
  String? _selectedShift;
  
  final List<TextEditingController> _operatorControllers = [TextEditingController()];
  final List<TextEditingController> _helpOperatorControllers = [TextEditingController()];
  List<String> _savedNames = [];
  List<Map<String, dynamic>> _savedBarrelTypes = [];
  Timer? _draftTimer;
  int _draftSessionId = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedNames();
    _loadSavedBarrelTypes();
    if (widget.initialData != null) {
      _loadFromInitialData();
    } else {
      _loadDraft();
    }
  }

  void _loadFromInitialData() {
    final data = widget.initialData!;
    final report = data['report'] as Map<String, dynamic>;
    final entries = data['entries'] as List<Map<String, dynamic>>;
    final measurements = data['measurements'] as List<Map<String, dynamic>>;

    setState(() {
      _selectedLine = report['line'];
      if (report['date'] != null) {
        _selectedDate = DateTime.parse(report['date']);
      }
      _selectedShift = report['shift'];
      _barrelsEmpty = report['barrels_empty'] == 1;
      _machineClean = report['machine_clean'] == 1;
      _nozzlesPierced = report['nozzles_pierced'] == 1;
      _commentsController.text = report['comments'] ?? '';

      // Operators
      final String rawOpNames = report['operator_names'] ?? '';
      List<String> operators = [];
      List<String> helpers = [];
      final parts = rawOpNames.split(', ');
      for (var p in parts) {
        if (p.startsWith('Helpoperator: ')) {
          helpers.add(p.replaceFirst('Helpoperator: ', ''));
        } else if (p.startsWith('Helper: ')) {
          helpers.add(p.replaceFirst('Helper: ', ''));
        } else {
          operators.add(p);
        }
      }

      for (var c in _operatorControllers) {
        c.dispose();
      }
      _operatorControllers.clear();
      if (operators.isEmpty) {
        _operatorControllers.add(TextEditingController());
      } else {
        for (var op in operators) {
          _operatorControllers.add(TextEditingController(text: op));
        }
      }

      for (var c in _helpOperatorControllers) {
        c.dispose();
      }
      _helpOperatorControllers.clear();
      if (helpers.isEmpty) {
        _helpOperatorControllers.add(TextEditingController());
      } else {
        for (var hop in helpers) {
          _helpOperatorControllers.add(TextEditingController(text: hop));
        }
      }

      // Production Entries
      for (var entry in _productionEntries) {
        (entry['start_time'] as TextEditingController).dispose();
        (entry['end_time'] as TextEditingController).dispose();
        (entry['pause_minutes'] as TextEditingController).dispose();
        (entry['cart_count'] as TextEditingController).dispose();
        (entry['barrel_count'] as TextEditingController).dispose();
      }
      _productionEntries.clear();
      if (entries.isEmpty) {
        _productionEntries.add({
          'fust_type': null,
          'start_time': TextEditingController(),
          'end_time': TextEditingController(),
          'cart_count': TextEditingController(),
          'barrel_count': TextEditingController(),
        });
      } else {
        for (var entry in entries) {
          _productionEntries.add({
            'fust_type': entry['fust_type'],
            'start_time': TextEditingController(text: entry['start_time']),
            'end_time': TextEditingController(text: entry['end_time']),
            'cart_count': TextEditingController(text: entry['cart_count']?.toString() ?? '0'),
            'barrel_count': TextEditingController(), // will be calculated on UI
          });
        }
      }

      // Chlorine
      for (var controller in _chlorineControllers) {
        controller.clear();
      }
      for (var m in measurements) {
        final time = m['measurement_time'];
        final index = _chlorineTimes.indexOf(time);
        if (index != -1) {
          _chlorineControllers[index].text = m['chlorine_level']?.toString() ?? '';
        }
      }
      
      _draftSessionId++;
    });
  }

  void _triggerDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 1), () => _saveDraft());
  }

  Future<void> _saveDraft() async {
    try {
      final draft = {
        'selectedLine': _selectedLine,
        'selectedDate': _selectedDate.toIso8601String(),
        'selectedShift': _selectedShift,
        'operators': _operatorControllers.map((c) => c.text).toList(),
        'helpOperators': _helpOperatorControllers.map((c) => c.text).toList(),
        'barrelsEmpty': _barrelsEmpty,
        'machineClean': _machineClean,
        'nozzlesPierced': _nozzlesPierced,
        'comments': _commentsController.text,
        'productionEntries': _productionEntries.map((e) => {
          'fust_type': e['fust_type'],
          'start_time': (e['start_time'] as TextEditingController).text,
          'end_time': (e['end_time'] as TextEditingController).text,
          'cart_count': (e['cart_count'] as TextEditingController).text,
        }).toList(),
        'chlorineMeasurements': _chlorineControllers.map((c) => c.text).toList(),
      };
      await _dbHelper.saveProductionReportDraft(jsonEncode(draft));
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final draftJson = await _dbHelper.getProductionReportDraft();
      if (draftJson == null) return;

      final draft = jsonDecode(draftJson);
      
      if (mounted) {
        setState(() {
          _selectedLine = draft['selectedLine'];
          if (draft['selectedDate'] != null) {
            _selectedDate = DateTime.parse(draft['selectedDate']);
          }
          _selectedShift = draft['selectedShift'];
          _barrelsEmpty = draft['barrelsEmpty'] ?? false;
          _machineClean = draft['machineClean'] ?? false;
          _nozzlesPierced = draft['nozzlesPierced'] ?? false;
          _commentsController.text = draft['comments'] ?? '';

          // Operators
          final List<dynamic> ops = draft['operators'] ?? [];
          for (var c in _operatorControllers) {
            c.dispose();
          }
          _operatorControllers.clear();
          if (ops.isEmpty) {
            _operatorControllers.add(TextEditingController());
          } else {
            for (var op in ops) {
              _operatorControllers.add(TextEditingController(text: op));
            }
          }

          // Help Operators
          final List<dynamic> hOps = draft['helpOperators'] ?? [];
          for (var c in _helpOperatorControllers) {
            c.dispose();
          }
          _helpOperatorControllers.clear();
          if (hOps.isEmpty) {
            _helpOperatorControllers.add(TextEditingController());
          } else {
            for (var hop in hOps) {
              _helpOperatorControllers.add(TextEditingController(text: hop));
            }
          }

          // Production Entries
          final List<dynamic> entries = draft['productionEntries'] ?? [];
          for (var entry in _productionEntries) {
            (entry['start_time'] as TextEditingController).dispose();
            (entry['end_time'] as TextEditingController).dispose();
            (entry['cart_count'] as TextEditingController).dispose();
            (entry['barrel_count'] as TextEditingController).dispose();
          }
          _productionEntries.clear();
          if (entries.isEmpty) {
            _productionEntries.add({
              'fust_type': null,
              'start_time': TextEditingController(),
              'end_time': TextEditingController(),
              'cart_count': TextEditingController(),
              'barrel_count': TextEditingController(),
            });
          } else {
            for (var entry in entries) {
              _productionEntries.add({
                'fust_type': entry['fust_type'],
                'start_time': TextEditingController(text: entry['start_time']),
                'end_time': TextEditingController(text: entry['end_time']),
                'cart_count': TextEditingController(text: entry['cart_count']),
                'barrel_count': TextEditingController(), // will be calculated on UI
              });
            }
          }

          // Chlorine
          final List<dynamic> chlorine = draft['chlorineMeasurements'] ?? [];
          for (int i = 0; i < chlorine.length && i < _chlorineControllers.length; i++) {
            _chlorineControllers[i].text = chlorine[i];
          }
          
          _draftSessionId++; // Increment to force rebuild of widgets using this in their key
        });
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  Future<void> _loadSavedNames() async {
    final names = await _dbHelper.getSavedNames();
    setState(() {
      _savedNames = names;
    });
  }

  Future<void> _loadSavedBarrelTypes() async {
    final types = await _dbHelper.getSavedBarrelTypes();
    setState(() {
      _savedBarrelTypes = types;
    });
  }

  Future<void> _addNewBarrelType({int? entryIndex}) async {
    final s = AppStrings.of(context);
    final nameController = TextEditingController();
    final multiplierController = TextEditingController(text: '1');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? errorText;

            void submit() {
              final name = nameController.text.trim();
              final mult = int.tryParse(multiplierController.text) ?? 1;
              if (name.isNotEmpty) {
                Navigator.pop(context, {'name': name, 'multiplier': mult});
              } else {
                setDialogState(() {
                  errorText = s.t('emptyField') ?? 'Field cannot be empty';
                });
              }
            }

            return AlertDialog(
              title: Text(s.t('addBarrelType') ?? 'Add Barrel Type'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: s.t('fustType'),
                      errorText: errorText,
                    ),
                    autofocus: true,
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: multiplierController,
                    decoration: InputDecoration(
                      labelText: s.t('barrelsPerCart') ?? 'Barrels per cart',
                      hintText: 'e.g. 24',
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: submit,
                  child: Text(s.t('save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _dbHelper.insertSavedBarrelType(result['name'], result['multiplier']);
      await _loadSavedBarrelTypes();
      
      if (mounted) {
        setState(() {
          if (entryIndex != null && entryIndex < _productionEntries.length) {
            _productionEntries[entryIndex]['fust_type'] = result['name'];
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('saveSuccess') ?? 'Saved successfully')),
        );
      }
    }
  }

  // Realized Production data
  final List<Map<String, dynamic>> _productionEntries = [
    {
      'fust_type': null,
      'start_time': TextEditingController(),
      'end_time': TextEditingController(),
      'pause_minutes': TextEditingController(text: '30'),
      'cart_count': TextEditingController(),
      'barrel_count': TextEditingController(),
    }
  ];

  // Chlorine data
  final List<String> _chlorineTimes = ['23:00', '02:00', '05:00', '08:00', '11:00', '14:00', '15:00', '17:00', '20:00'];
  final List<TextEditingController> _chlorineControllers = List.generate(9, (_) => TextEditingController());

  // Checklist data
  bool _barrelsEmpty = false;
  bool _machineClean = false;
  bool _nozzlesPierced = false;

  // Comments
  final TextEditingController _commentsController = TextEditingController();

  @override
  void dispose() {
    _draftTimer?.cancel();
    for (var e in _productionEntries) {
      (e['start_time'] as TextEditingController).dispose();
      (e['end_time'] as TextEditingController).dispose();
      (e['pause_minutes'] as TextEditingController).dispose();
      (e['cart_count'] as TextEditingController).dispose();
      (e['barrel_count'] as TextEditingController).dispose();
    }
    for (var c in _chlorineControllers) {
      c.dispose();
    }
    for (var c in _operatorControllers) {
      c.dispose();
    }
    for (var c in _helpOperatorControllers) {
      c.dispose();
    }
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _saveReport() async {
    final s = AppStrings.of(context);
    
    if (_selectedLine == null || _selectedShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.t('selectLineAndShift') ?? 'Proszę wybrać linię i zmianę.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final report = {
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'line': _selectedLine,
      'shift': _selectedShift,
      'operator_names': [
        ..._operatorControllers.map((c) => c.text).where((t) => t.isNotEmpty),
        ..._helpOperatorControllers.map((c) => c.text).where((t) => t.isNotEmpty).map((t) => 'Helpoperator: $t'),
      ].join(', '),
      'barrels_empty': _barrelsEmpty ? 1 : 0,
      'machine_clean': _machineClean ? 1 : 0,
      'nozzles_pierced': _nozzlesPierced ? 1 : 0,
      'comments': _commentsController.text,
      'created_at': DateTime.now().toIso8601String(),
    };

    final entries = _productionEntries.where((e) => e['fust_type'] != null).map((e) {
      final cartCount = int.tryParse((e['cart_count'] as TextEditingController).text) ?? 0;
      final fustType = e['fust_type'] as String;
      
      // Calculate total barrels based on multiplier
      final typeMap = _savedBarrelTypes.firstWhere((t) => t['name'] == fustType, orElse: () => {'multiplier': 1});
      final multiplier = typeMap['multiplier'] as int? ?? 1;
      final totalBarrels = cartCount * multiplier;

      return {
        'fust_type': fustType,
        'start_time': (e['start_time'] as TextEditingController).text,
        'end_time': (e['end_time'] as TextEditingController).text,
        'cart_count': cartCount,
        'barrel_count': totalBarrels,
      };
    }).toList();

    final measurements = <Map<String, dynamic>>[];
    for (int i = 0; i < _chlorineTimes.length; i++) {
      if (_chlorineControllers[i].text.isNotEmpty) {
        measurements.add({
          'measurement_time': _chlorineTimes[i],
          'chlorine_level': double.tryParse(_chlorineControllers[i].text) ?? 0.0,
        });
      }
    }

    try {
      if (widget.initialData != null) {
        final oldId = widget.initialData!['report']['id'] as int;
        await _dbHelper.deleteProductionReport(oldId);
      }
      await _dbHelper.insertProductionReport(report, entries, measurements);
      await _dbHelper.clearProductionReportDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('saveSuccess'))));
        
        // Clear all fields after successful save
        setState(() {
          _operatorControllers.clear();
          _operatorControllers.add(TextEditingController());
          _helpOperatorControllers.clear();
          _helpOperatorControllers.add(TextEditingController());
          _productionEntries.clear();
          _productionEntries.add({
            'fust_type': null,
            'start_time': TextEditingController(),
            'end_time': TextEditingController(),
            'cart_count': TextEditingController(),
            'barrel_count': TextEditingController(),
          });
          for (var c in _chlorineControllers) {
            c.clear();
          }
          _barrelsEmpty = false;
          _machineClean = false;
          _nozzlesPierced = false;
          _commentsController.clear();
          _selectedLine = null;
          _selectedShift = null;
          _selectedDate = DateTime.now();
        });

        if (!widget.isEmbedded) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.t('errorSaving')} $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final content = PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        // Jeśli wychodzimy, wymuś natychmiastowy zapis szkicu
        if (_draftTimer?.isActive ?? false) {
          _draftTimer?.cancel();
          await _saveDraft();
        }
      },
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(s),
              const Divider(height: 32),
              _buildProductionTable(s),
              const Divider(height: 32),
              _buildChlorineTable(s),
              const Divider(height: 32),
              _buildChecklist(s),
              const Divider(height: 32),
              _buildComments(s),
              const SizedBox(height: 50), // Extra space at bottom
            ],
          ),
        ),
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('productionReportTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _saveReport,
              icon: const Icon(Icons.check_circle, size: 18),
              label: Text(widget.initialData != null ? (s.t('update') ?? 'Update') : s.t('finalize')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildHeader(AppStrings s) {
    final shiftOptions = [
      'Ochtend (6:00 - 14:00)',
      'Middag (14:00 - 22:00)',
      'Nacht (22:00 - 06:00)',
    ];
    final shiftLabels = [s.t('shiftMorning'), s.t('shiftAfternoon'), s.t('shiftNight')];
    final lineOptions = ['1', '2', '3'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Date, Line, Shift
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Selection
              Text(s.t('date').toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              ToggleButtons(
                isSelected: const [false],
                onPressed: (_) async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _triggerDraftSave();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 120),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('dd-MM-yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Production Line
              Text(s.t('productionLine').toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              ToggleButtons(
                isSelected: lineOptions.map((l) => _selectedLine == l).toList(),
                onPressed: (index) {
                  setState(() => _selectedLine = lineOptions[index]);
                  _triggerDraftSave();
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 45),
                selectedColor: Colors.black,
                fillColor: Colors.grey.shade300,
                children: lineOptions
                    .map((l) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // Shift Selection
              Text(s.t('shift').toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              ToggleButtons(
                isSelected: shiftOptions.map((sh) => _selectedShift == sh).toList(),
                onPressed: (index) {
                  setState(() => _selectedShift = shiftOptions[index]);
                  _triggerDraftSave();
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
                selectedColor: Colors.black,
                fillColor: Colors.grey.shade300,
                children: shiftLabels
                    .map((sh) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(sh, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column: Operators and Help Operators
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDynamicNameList(s.t('operator').toUpperCase(), _operatorControllers),
              const SizedBox(height: 16),
              _buildDynamicNameList(s.t('helpOperator').toUpperCase(), _helpOperatorControllers),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicNameList(String label, List<TextEditingController> controllers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            const SizedBox(width: 8),
            // 1. Przycisk dodawania kolejnego wiersza (niebieski plus w kółku)
            IconButton(
              onPressed: () {
                setState(() {
                  controllers.add(TextEditingController());
                });
                _triggerDraftSave();
              },
              icon: const Icon(Icons.add_circle_outline, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Theme.of(context).colorScheme.primary,
              tooltip: 'Add another operator',
            ),
            const SizedBox(width: 8),
            // 2. Przycisk dodawania nowego operatora do bazy (pomarańczowa osoba z plusem)
            IconButton(
              onPressed: () => _addNameDialog(controllers, controllers.length - 1),
              icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.orange, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Add new name to database',
            ),
            const SizedBox(width: 8),
            // 3. Przycisk zarządzania listą osób (ikona info, kolor niebiesko-szary)
            IconButton(
              onPressed: _manageNamesDialog,
              icon: const Icon(Icons.info_outline, color: Colors.blueGrey, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Manage names list',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Autocomplete<String>(
                        key: ValueKey('autocomplete_${label}_${index}_$_draftSessionId'),
                        initialValue: TextEditingValue(text: controller.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _savedNames;
                        }
                        return _savedNames.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        controller.text = selection;
                        _triggerDraftSave();
                      },
                      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                        // Synchronize internal controller with external one
                        fieldController.addListener(() {
                          if (controller.text != fieldController.text) {
                            controller.text = fieldController.text;
                            _triggerDraftSave();
                          }
                        });
                        
                        return TextFormField(
                          controller: fieldController,
                          focusNode: focusNode,
                          onFieldSubmitted: (v) => onFieldSubmitted(),
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: SizedBox(
                              width: 300,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(index);
                                  return ListTile(
                                    title: Text(option, style: const TextStyle(fontSize: 14)),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (index > 0) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        controllers[index].dispose();
                        controllers.removeAt(index);
                      });
                      _triggerDraftSave();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addNameDialog(List<TextEditingController> controllers, int index) async {
    final s = AppStrings.of(context);
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('addName')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: s.t('name')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(s.t('save'))),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _dbHelper.insertSavedName(result);
      await _loadSavedNames();
      setState(() {
        controllers[index].text = result;
      });
      _triggerDraftSave();
    }
  }

  Future<void> _manageNamesDialog() async {
    final s = AppStrings.of(context);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.people_outline, color: Colors.blueGrey),
              const SizedBox(width: 10),
              Text(s.t('manageNames') ?? 'Manage Names'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _savedNames.isEmpty
                ? Center(child: Text(s.t('listEmpty') ?? 'List is empty'))
                : ListView.separated(
                    itemCount: _savedNames.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final name = _savedNames[index];
                      return ListTile(
                        title: Text(name, style: const TextStyle(fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edytuj
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                              onPressed: () async {
                                final controller = TextEditingController(text: name);
                                final newName = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.t('editName') ?? 'Edit Name'),
                                    content: TextField(
                                      controller: controller,
                                      decoration: InputDecoration(hintText: s.t('name')),
                                      autofocus: true,
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, controller.text.trim()),
                                        child: Text(s.t('save')),
                                      ),
                                    ],
                                  ),
                                );

                                if (newName != null && newName.isNotEmpty && newName != name) {
                                  await _dbHelper.updateSavedName(name, newName);
                                  await _loadSavedNames();
                                  setDialogState(() {}); // Odśwież widok wewnątrz dialogu
                                  setState(() {}); // Odśwież główny ekran
                                }
                              },
                            ),
                            // Usuń
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.t('confirmDelete') ?? 'Confirm Delete'),
                                    content: Text('${s.t('deleteConfirmMessage') ?? 'Are you sure you want to delete'} "$name"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text(s.t('delete')),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _dbHelper.deleteSavedName(name);
                                  await _loadSavedNames();
                                  setDialogState(() {}); // Odśwież widok wewnątrz dialogu
                                  setState(() {}); // Odśwież główny ekran
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('close'))),
          ],
        ),
      ),
    );
  }

  Future<void> _showBarrelTypesInfo() async {
    final s = AppStrings.of(context);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Colors.blueGrey),
              const SizedBox(width: 10),
              Text(s.t('manageBarrelTypes') ?? 'Manage Barrel Types'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _savedBarrelTypes.isEmpty
                ? Center(child: Text(s.t('listEmpty') ?? 'List is empty'))
                : ListView.separated(
                    itemCount: _savedBarrelTypes.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final type = _savedBarrelTypes[index];
                      final name = type['name'] as String;
                      final multiplier = type['multiplier'] as int;
                      return ListTile(
                        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('${s.t('multiplier') ?? 'Multiplier'}: $multiplier'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edytuj
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                              onPressed: () async {
                                final nameController = TextEditingController(text: name);
                                final multiplierController = TextEditingController(text: multiplier.toString());
                                final result = await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.t('editBarrelType') ?? 'Edit Barrel Type'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: nameController,
                                          decoration: InputDecoration(hintText: s.t('name')),
                                        ),
                                        TextField(
                                          controller: multiplierController,
                                          decoration: InputDecoration(hintText: s.t('multiplier')),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, {
                                          'name': nameController.text.trim(),
                                          'multiplier': int.tryParse(multiplierController.text) ?? 1,
                                        }),
                                        child: Text(s.t('save')),
                                      ),
                                    ],
                                  ),
                                );

                                if (result != null && result['name'].isNotEmpty) {
                                  await _dbHelper.updateSavedBarrelType(name, result['name'], result['multiplier']);
                                  await _loadSavedBarrelTypes();
                                  setDialogState(() {});
                                  setState(() {});
                                }
                              },
                            ),
                            // Usuń
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.t('confirmDelete') ?? 'Confirm Delete'),
                                    content: Text('${s.t('deleteConfirmMessage') ?? 'Are you sure you want to delete'} "$name"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text(s.t('delete')),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _dbHelper.deleteSavedBarrelType(name);
                                  await _loadSavedBarrelTypes();
                                  setDialogState(() {});
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('close'))),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionTable(AppStrings s) {
    const columnWidths = {
      0: FlexColumnWidth(1.2), // Barrel Type
      1: FlexColumnWidth(0.6), // Start Time
      2: FlexColumnWidth(0.6), // End Time
      3: FlexColumnWidth(0.9), // Total production time
      4: FlexColumnWidth(4.5), // Number of Carts
      5: FlexColumnWidth(1.5), // Total barrels
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200), // Rozszerzono do 1200
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(s.t('realizedProduction'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _productionEntries.add({
                        'fust_type': null,
                        'start_time': TextEditingController(),
                        'end_time': TextEditingController(),
                        'cart_count': TextEditingController(),
                        'barrel_count': TextEditingController(),
                      });
                    });
                    _triggerDraftSave();
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _addNewBarrelType(),
                  icon: const Icon(Icons.playlist_add_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.orange,
                  tooltip: s.t('addBarrelType'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _showBarrelTypesInfo,
                  icon: const Icon(Icons.info_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.blueGrey,
                  tooltip: 'Barrel types info',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 1. STICKY HEADER
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    _tableHeader(s.t('fustType')),
                    _tableHeader(s.t('startTime')),
                    _tableHeader(s.t('endTime')),
                    _tableHeader('Total production time'),
                    _tableHeader(s.t('cartCount')),
                    _tableHeader('Total number of barrels'),
                  ],
                ),
              ],
            ),

            // 2. SCROLLABLE BODY
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder(
                    left: BorderSide(color: Colors.grey.shade300),
                    right: BorderSide(color: Colors.grey.shade300),
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                  columnWidths: columnWidths,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: _productionEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controllers = entry.value;
                    
                    return TableRow(
                      children: [
                        // fust_type Dropdown
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: controllers['fust_type'] as String?,
                              isDense: true,
                              isExpanded: true,
                              alignment: Alignment.center,
                              padding: EdgeInsets.zero,
                              iconSize: 0,
                              icon: const SizedBox.shrink(),
                              style: const TextStyle(fontSize: 13, color: Colors.black),
                              items: _savedBarrelTypes.map((typeMap) {
                                final type = typeMap['name'] as String? ?? 'Unknown';
                                return DropdownMenuItem(
                                  value: type,
                                  alignment: Alignment.center,
                                  child: Center(child: Text(type, style: const TextStyle(fontSize: 13))),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() => controllers['fust_type'] = v);
                                _triggerDraftSave();
                              },
                            ),
                          ),
                        ),
                        _timeTableInput(controllers['start_time'] as TextEditingController, onChanged: () {
                          setState(() {});
                          _triggerDraftSave();
                        }),
                        _timeTableInput(controllers['end_time'] as TextEditingController, onChanged: () {
                          setState(() {});
                          _triggerDraftSave();
                        }),
                        _buildProductionTimeDisplay(controllers),
                        // Number of Carts
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: controllers['cart_count'] as TextEditingController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    setState(() {});
                                    _triggerDraftSave();
                                  },
                                ),
                              ),
                              if (!widget.isReadOnly) ...[
                                _incrementButton(controllers['cart_count'] as TextEditingController, 1),
                                _incrementButton(controllers['cart_count'] as TextEditingController, 5),
                                _incrementButton(controllers['cart_count'] as TextEditingController, 15, isLarge: true, s: s),
                              ],
                            ],
                          ),
                        ),
                        _buildTotalBarrelsDisplay(controllers),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

            // 3. STICKY FOOTER (TOTAL) - Redesigned to match the drawing
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.3),
                border: Border(
                  left: BorderSide(color: Colors.grey.shade300),
                  right: BorderSide(color: Colors.grey.shade300),
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Box 1: Total Carts
                  Container(
                    width: 120,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.shade400, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white,
                    ),
                    child: Text(
                      _calculateGrandTotalCarts(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Box 2: Total Barrels
                  Container(
                    width: 150,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.shade400, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white,
                    ),
                    child: Text(
                      _calculateGrandTotalBarrels(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _calculateGrandTotalCarts() {
    int total = 0;
    for (var e in _productionEntries) {
      total += int.tryParse((e['cart_count'] as TextEditingController).text) ?? 0;
    }
    return total.toString();
  }

  String _calculateGrandTotalBarrels() {
    int grandTotal = 0;
    for (var e in _productionEntries) {
      final cartCount = int.tryParse((e['cart_count'] as TextEditingController).text) ?? 0;
      final fustType = e['fust_type'] as String?;
      if (fustType != null) {
        final typeMap = _savedBarrelTypes.firstWhere((t) => t['name'] == fustType, orElse: () => {'multiplier': 0});
        final multiplier = typeMap['multiplier'] as int? ?? 0;
        grandTotal += cartCount * multiplier;
      }
    }
    // Format with comma
    return grandTotal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},'
    );
  }

  Widget _tableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    );
  }

  Widget _timeTableInput(TextEditingController controller, {VoidCallback? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _TimeTableInputWidget(controller: controller, onChanged: onChanged),
    );
  }

  Widget _incrementButton(TextEditingController controller, int amount, {bool isLarge = false, AppStrings? s}) {
    return IconButton(
      onPressed: () async {
        if (isLarge && s != null) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(s.t('confirm')),
              content: Text(s.t('confirmAddLargeAmount')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.t('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(s.t('confirm')),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
        }

        setState(() {
          int current = int.tryParse(controller.text) ?? 0;
          controller.text = (current + amount).toString();
          _triggerDraftSave();
        });
      },
      icon: Container(
        width: isLarge ? 34 : 30,
        height: isLarge ? 34 : 30,
        decoration: BoxDecoration(
          color: isLarge ? Colors.red : (amount == 5 ? Colors.orange : Colors.green),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '+$amount',
          style: TextStyle(
            fontSize: isLarge ? 11 : 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      constraints: const BoxConstraints(),
      tooltip: '+$amount',
    );
  }

  Widget _buildProductionTimeDisplay(Map<String, dynamic> controllers) {
    final startStr = (controllers['start_time'] as TextEditingController).text;
    final endStr = (controllers['end_time'] as TextEditingController).text;
    final display = TimeUtils.calculateDuration(startStr, endStr);

    return Center(
      child: Text(
        display,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  Widget _buildTotalBarrelsDisplay(Map<String, dynamic> controllers) {
    final cartCount = int.tryParse((controllers['cart_count'] as TextEditingController).text) ?? 0;
    final fustType = controllers['fust_type'] as String?;
    
    int total = 0;
    if (fustType != null) {
      final typeMap = _savedBarrelTypes.firstWhere((t) => t['name'] == fustType, orElse: () => {'multiplier': 0});
      final multiplier = typeMap['multiplier'] as int? ?? 0;
      total = cartCount * multiplier;
    }

    final formatted = total.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},'
    );

    return Center(
      child: Text(
        formatted,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tableInput(TextEditingController controller, {String? hint, List<TextInputFormatter>? formatters, double vPadding = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: vPadding),
      child: TextFormField(
        controller: controller,
        onChanged: (_) => _triggerDraftSave(),
        textAlign: TextAlign.center, // Wyrównanie poziome do środka
        style: const TextStyle(
          fontSize: 16, // Powiększona czcionka
          fontWeight: FontWeight.bold, // Pogrubienie
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          isDense: true,
          contentPadding: EdgeInsets.zero, // Minimalizacja paddingu dla lepszego wyrównania pionowego
        ),
        keyboardType: TextInputType.number,
        inputFormatters: formatters,
      ),
    );
  }

  bool _isTimeUnlocked(String time) {
    if (_selectedShift?.contains('Ochtend') ?? false) {
      return ['08:00', '11:00', '14:00'].contains(time);
    } else if (_selectedShift?.contains('Middag') ?? false) {
      return ['15:00', '17:00', '20:00'].contains(time);
    } else if (_selectedShift?.contains('Nacht') ?? false) {
      return ['23:00', '02:00', '05:00'].contains(time);
    }
    return true;
  }

  Widget _buildChlorineTable(AppStrings s) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200), // Dopasowano do tabeli produkcji
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('chlorineMeasurement'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(), // Pozwala kolumnom rosnąć naturalnie
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: _chlorineTimes.map((t) => Container(
                      width: 1200 / _chlorineTimes.length, // Równomierny rozkład na 1200px
                      child: _tableHeader(t),
                    )).toList(),
                  ),
                  TableRow(
                    children: _chlorineTimes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final time = entry.value;
                      final isUnlocked = _isTimeUnlocked(time);
                      
                      if (!isUnlocked) {
                        return CustomPaint(
                          painter: _CrossPainter(),
                          child: Container(
                            height: 60, // Match the height of unlocked cells
                            color: Colors.grey.shade50.withOpacity(0.5),
                          ),
                        );
                      }
                      
                      return _tableInput(_chlorineControllers[idx], vPadding: 16);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklist(AppStrings s) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200), // Dopasowano do szerokości tabel
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('END OF SHIFT CHECKLIST', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Rozmieszczenie na całej szerokości
              children: [
                _checklistRow(s.t('barrelsEmpty'), _barrelsEmpty, (v) {
                  setState(() => _barrelsEmpty = v!);
                  _triggerDraftSave();
                }),
                _checklistRow(s.t('machineClean'), _machineClean, (v) {
                  setState(() => _machineClean = v!);
                  _triggerDraftSave();
                }),
                _checklistRow(s.t('nozzlesPierced'), _nozzlesPierced, (v) {
                  setState(() => _nozzlesPierced = v!);
                  _triggerDraftSave();
                }),
                const SizedBox(width: 0), // Dodatkowy punkt odniesienia dla wyrównania do prawej krawędzi
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _checklistRow(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 1.2, // Lekkie powiększenie checkboxa
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), // Zwiększona czcionka z 13 na 16
      ],
    );
  }

  Widget _buildComments(AppStrings s) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200), // Dopasowano do tabeli produkcji
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('commentsAndDetails'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.t('doubleWashForbidden'),
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentsController,
              maxLines: 3,
              onChanged: (_) => _triggerDraftSave(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
