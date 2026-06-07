import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_strings.dart';
import '../database/db_helper.dart';
import '../models/task.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({
    super.key,
    required this.currentUsername,
    this.task,
  });

  final String currentUsername;
  final Task? task;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _userController = TextEditingController();
  
  final DBHelper _dbHelper = DBHelper.instance;
  
  String _selectedStatus = 'Zaplanowane';
  DateTime? _selectedDate;
  List<String> _availableLocations = [];
  bool _isLoadingLocations = true;

  final List<String> _statusOptions = [
    'Zaplanowane',
    'Zrealizowane',
    'Anulowane'
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
    if (widget.task != null) {
      _locationController.text = widget.task!.title;
      _descriptionController.text = widget.task!.type;
      _userController.text = widget.task!.label ?? '';
      _selectedStatus = widget.task!.status;
      if (widget.task!.dateStart != null) {
        _selectedDate = DateTime.parse(widget.task!.dateStart!);
      }
    } else {
      _userController.text = widget.currentUsername;
    }
  }

  Future<void> _loadLocations() async {
    try {
      final assets = await _dbHelper.getAssets();
      setState(() {
        _availableLocations = assets.map((e) => e.lokalizacja).toSet().toList();
        _availableLocations.sort();
        _isLoadingLocations = false;
      });
    } catch (e) {
      debugPrint('Error loading locations: $e');
      setState(() => _isLoadingLocations = false);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _userController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final taskModel = Task(
      id: widget.task?.id,
      title: _locationController.text.trim(),
      status: _selectedStatus,
      type: _descriptionController.text.trim(),
      priority: widget.task?.priority ?? 'Standardowy',
      label: _userController.text.trim(),
      dateStart: _selectedDate?.toIso8601String(),
      dateEnd: _selectedDate?.toIso8601String(),
      createdAt: widget.task?.createdAt ?? DateTime.now().toIso8601String(),
      createdBy: widget.task?.createdBy ?? widget.currentUsername,
      progress: widget.task?.progress ?? 0.0,
      failureId: widget.task?.failureId,
    );

    try {
      debugPrint('DEBUG: Attempting to save task: ${taskModel.toMap()}');
      if (widget.task == null) {
        final id = await _dbHelper.insertTask(taskModel.toMap());
        debugPrint('DEBUG: Task saved successfully with ID: $id');
      } else {
        await _dbHelper.updateTask(widget.task!.id!, taskModel.toMap());
        debugPrint('DEBUG: Task updated successfully');
      }
      
      if (mounted) {
        final s = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('reportSaved'))),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('DEBUG: Critical Error saving task: $e');
      if (mounted) {
        final s = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.t('errorSaving')} $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.task == null ? s.t('addTask') : s.t('editTask'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Location Dropdown or TextField
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _availableLocations.isNotEmpty
                            ? DropdownButtonFormField<String>(
                                value: _availableLocations.contains(_locationController.text) ? _locationController.text : null,
                                decoration: InputDecoration(
                                  labelText: s.t('location'),
                                  prefixIcon: const Icon(Icons.location_on_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                items: _availableLocations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _locationController.text = val);
                                },
                                validator: (value) => _locationController.text.isEmpty ? s.t('requiredField') : null,
                              )
                            : _buildField(s.t('location'), _locationController, Icons.location_on_outlined),
                      ),
                      if (_availableLocations.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            // Clear and let user type manually if not in list
                            showDialog(
                              context: context,
                              builder: (context) {
                                final controller = TextEditingController(text: _locationController.text);
                                return AlertDialog(
                                  title: Text(s.t('location')),
                                  content: TextField(controller: controller, decoration: InputDecoration(hintText: s.t('location'))),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
                                    TextButton(
                                      onPressed: () {
                                        setState(() => _locationController.text = controller.text);
                                        Navigator.pop(context);
                                      },
                                      child: Text(s.t('save')),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
                
                _buildField(s.t('description'), _descriptionController, Icons.description_outlined, maxLines: 3),
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: s.t('status'),
                      prefixIcon: const Icon(Icons.info_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: _statusOptions.map((String value) {
                      String label = value;
                      if (value == 'Zaplanowane') label = s.t('planned');
                      if (value == 'Zrealizowane') label = s.t('completed');
                      if (value == 'Anulowane') label = s.t('cancelled');
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (newValue) => setState(() => _selectedStatus = newValue!),
                  ),
                ),

                _buildField(s.t('username'), _userController, Icons.person_outline),

                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDateTime(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('executionDate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDate != null 
                                ? DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate!)
                                : s.t('selectDateTime'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saveTask,
                  icon: const Icon(Icons.save),
                  label: Text(s.t('save'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (value) => value == null || value.trim().isEmpty ? s.t('requiredField') : null,
      ),
    );
  }
}
