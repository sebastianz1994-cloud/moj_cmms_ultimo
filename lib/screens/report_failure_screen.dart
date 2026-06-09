import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../app_strings.dart';
import '../database/db_helper.dart';
import '../utils/time_utils.dart';
import '../widgets/loading_overlay.dart';

class ReportFailureScreen extends StatefulWidget {
  const ReportFailureScreen({
    super.key,
    required this.strings,
    required this.currentUsername,
  });

  final AppStrings strings;
  final String currentUsername;

  @override
  State<ReportFailureScreen> createState() => _ReportFailureScreenState();
}

class _ReportFailureScreenState extends State<ReportFailureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _opisController = TextEditingController();
  final _lokalizacjaManualController = TextEditingController();
  final _liniaManualController = TextEditingController();
  final _powodController = TextEditingController();
  final _naprawaController = TextEditingController();
  final _ktoController = TextEditingController();
  final _reporterController = TextEditingController();
  
  final DBHelper _dbHelper = DBHelper.instance;
  final ImagePicker _picker = ImagePicker();
  
  XFile? _image;
  int _currentStep = 0; // 0: Photo, 1: Form
  bool _czyRozwiazane = false;
  String _priority = 'Medium';
  DateTime? _startNaprawy;
  DateTime? _koniecNaprawy;
  String _uniqueId = '';

  String? _selectedLinia;
  String? _selectedLokalizacja;

  final List<String> _liniaOptions = [
    'LIJN 1',
    'LIJN 2',
    'LIJN 3',
    'Compressor (Atlas Copco)',
    'Water Pump (SiBoost Smart 3HELIX VE608-WMS-DST-S)',
    'CONNEXX (chlorine)',
    'CONNEXX (soap)',
    'Other',
  ];

  final List<String> _lokalizacjaOptions = [
    'Kartransport',
    'Rekjesband',
    'Invoerrobot',
    'Ontnester spoor 1',
    'Ontnester spoor 2',
    'Whashing Machine spoor 1',
    'Whashing Machine spoor 2',
    'Stapelaar spoor 1',
    'Stapelaar spoor 2',
    'Uitvoerrobot',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _reporterController.text = widget.currentUsername;
    _generateUniqueId();
    _liniaManualController.addListener(_generateUniqueId);
  }

  Future<void> _generateUniqueId() async {
    final now = DateTime.now();
    final year = now.year;
    
    // Get count of reports for the current year
    final reports = await _dbHelper.getFailureReports();
    final currentYearReports = reports.where((r) {
      final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '');
      return createdAt?.year == year;
    }).length;
    
    final count = currentYearReports + 1;
    
    final effectiveLine = _selectedLinia == 'Other' ? _liniaManualController.text.trim() : _selectedLinia;
    
    setState(() {
      _uniqueId = TimeUtils.formatFaultId(
        line: effectiveLine,
        count: count,
        date: now,
      );
    });
  }

  @override
  void dispose() {
    _liniaManualController.removeListener(_generateUniqueId);
    _opisController.dispose();
    _lokalizacjaManualController.dispose();
    _liniaManualController.dispose();
    _powodController.dispose();
    _naprawaController.dispose();
    _ktoController.dispose();
    _reporterController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _image = pickedFile;
          _currentStep = 1; // Move to form after picking photo
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  String _calculateDowntime() {
    if (_startNaprawy == null || _koniecNaprawy == null) return '0';
    final diff = _koniecNaprawy!.difference(_startNaprawy!);
    if (diff.isNegative) return '0';
    
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    
    List<String> parts = [];
    if (days > 0) parts.add('$days ${widget.strings.t('days')}');
    if (hours > 0) parts.add('$hours ${widget.strings.t('hours')}');
    if (minutes > 0) parts.add('$minutes ${widget.strings.t('minutes')}');
    
    return parts.isEmpty ? '0' : parts.join(' ');
  }

  int _calculateDowntimeMinutes() {
    if (_startNaprawy == null || _koniecNaprawy == null) return 0;
    final diff = _koniecNaprawy!.difference(_startNaprawy!);
    return diff.inMinutes > 0 ? diff.inMinutes : 0;
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          final result = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startNaprawy = result;
          } else {
            _koniecNaprawy = result;
          }
        });
      }
    }
  }

  Future<void> _saveReport() async {
    final s = widget.strings;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    LoadingOverlay.show(context, message: 'Saving report...');

    try {
      final downtimeStr = _calculateDowntime();
      final downtimeMin = _calculateDowntimeMinutes();

      final linia = _selectedLinia == 'Other' ? _liniaManualController.text.trim() : _selectedLinia;
      final lokalizacja = _selectedLokalizacja == 'Other' ? _lokalizacjaManualController.text.trim() : _selectedLokalizacja;

      Uint8List? imageBlob;
      if (_image != null) {
        imageBlob = await _image!.readAsBytes();
      }

      final failureId = await _dbHelper.insertFailureReport({
        'unique_id': _uniqueId,
        'opis': _opisController.text.trim(),
        'lokalizacja': lokalizacja,
        'linia': linia,
        'powod': _powodController.text.trim(),
        'priorytet': _priority,
        'czy_rozwiazane': _czyRozwiazane ? 1 : 0,
        'status': _czyRozwiazane ? 'ZAMKNIĘTY' : 'OTWARTY',
        'czas_trwania': downtimeStr,
        'downtime_minutes': downtimeMin,
        'co_naprawiono': _naprawaController.text.trim(),
        'kto_naprawil': _ktoController.text.trim(),
        'zdjecie_sciezka': _image?.path ?? '',
        'zdjecie_blob': imageBlob,
        'created_by': _reporterController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'data_rozpoczecia_naprawy': _startNaprawy?.toIso8601String(),
        'data_zakonczenia_naprawy': _koniecNaprawy?.toIso8601String(),
      });

      // Also add to Tasks table so it shows up in Task List
      await _dbHelper.insertTask({
        'title': lokalizacja ?? '-',
        'status': _czyRozwiazane ? 'Zrealizowane' : 'Zaplanowane',
        'type': _opisController.text.trim(),
        'priority': _priority,
        'date_start': DateTime.now().toIso8601String(),
        'label': widget.currentUsername,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': widget.currentUsername,
        'failure_id': failureId,
      });

      if (!mounted) {
        LoadingOverlay.hide(context);
        return;
      }
      if (mounted) {
        LoadingOverlay.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('reportSaved'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        LoadingOverlay.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == 0 ? s.t('photoStep') : s.t('formStep')),
      ),
      body: _currentStep == 0 ? _buildPhotoStep(s, colorScheme) : _buildFormStep(s, colorScheme),
    );
  }

  Widget _buildPhotoStep(AppStrings s, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 80, color: colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: Text(s.t('takePhoto')),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: Text(s.t('pickPhoto')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: Text(s.t('cancel').toUpperCase()), // Skip photo
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormStep(AppStrings s, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ID Display
            Card(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ID:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_uniqueId, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Photo Preview (if exists)
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(
                          _image!.path,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(_image!.path),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              ),

            // Form Fields
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedLinia,
                decoration: InputDecoration(
                  labelText: s.t('lineName'),
                  prefixIcon: const Icon(Icons.factory_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _liniaOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value == 'Other' ? (s.t('other')) : value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedLinia = newValue;
                  });
                  _generateUniqueId();
                },
                validator: (value) => value == null ? s.t('requiredField') : null,
              ),
            ),
            if (_selectedLinia == 'Other')
              _buildField(s.t('lineName'), _liniaManualController, Icons.edit_note_outlined),

            _buildField(s.t('whatHappened'), _opisController, Icons.description_outlined, maxLines: 3),

            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedLokalizacja,
                decoration: InputDecoration(
                  labelText: s.t('location'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _lokalizacjaOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value == 'Other' ? (s.t('other')) : value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedLokalizacja = newValue;
                  });
                },
                validator: (value) => value == null ? s.t('requiredField') : null,
              ),
            ),
            if (_selectedLokalizacja == 'Other')
              _buildField(s.t('location'), _lokalizacjaManualController, Icons.edit_location_alt_outlined),

            _buildField(s.t('reason'), _powodController, Icons.question_mark_outlined),
            
            // Priority Dropdown
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: InputDecoration(
                  labelText: s.t('priority'),
                  prefixIcon: const Icon(Icons.priority_high),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Low', 'Medium', 'High', 'Critical'].map((p) {
                  return DropdownMenuItem(value: p, child: Text(s.t(p.toLowerCase())));
                }).toList(),
                onChanged: (val) => setState(() => _priority = val!),
              ),
            ),

            _buildField(s.t('reporter'), _reporterController, Icons.person_outline),

            // Status Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text('${s.t('status')}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _czyRozwiazane ? s.t('closed') : s.t('open'),
                    style: TextStyle(
                      color: _czyRozwiazane ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      decoration: _czyRozwiazane ? null : TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),

            SwitchListTile(
              title: Text(s.t('resolvedQuestion')),
              value: _czyRozwiazane,
              activeThumbColor: Colors.green,
              onChanged: (value) => setState(() => _czyRozwiazane = value),
            ),

            if (_czyRozwiazane) ...[
              const Divider(height: 32),
              _buildDateTimePicker(s.t('repairStart'), _startNaprawy, true),
              _buildDateTimePicker(s.t('repairEnd'), _koniecNaprawy, false),
              
              if (_startNaprawy != null && _koniecNaprawy != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: Text(
                    '${s.t('downtime')}: ${_calculateDowntime()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),

              _buildField(s.t('whoFixed'), _ktoController, Icons.engineering_outlined),
              _buildField(s.t('whatFixed'), _naprawaController, Icons.build_outlined, maxLines: 2),
            ],

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveReport,
              icon: const Icon(Icons.save),
              label: Text(s.t('save')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) => value == null || value.trim().isEmpty ? widget.strings.t('requiredField') : null,
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime? value, bool isStart) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectDateTime(context, isStart),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(value != null ? dateFormat.format(value) : 'Select date/time'),
        ),
      ),
    );
  }
}
