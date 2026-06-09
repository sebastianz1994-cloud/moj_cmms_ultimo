import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import '../utils/time_utils.dart';
import 'package:intl/intl.dart';

class CurrentFailuresScreen extends StatefulWidget {
  const CurrentFailuresScreen({super.key, required this.strings, required this.currentUsername});
  final AppStrings strings;
  final String currentUsername;

  @override
  State<CurrentFailuresScreen> createState() => _CurrentFailuresScreenState();
}

class _CurrentFailuresScreenState extends State<CurrentFailuresScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  List<Map<String, dynamic>> _openReports = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOpenReports();
  }

  Future<void> _loadOpenReports({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _isLoading = true);
    try {
      final reports = await _dbHelper.getFailureReports();
      final query = _searchController.text.toLowerCase();
      
      setState(() {
        _openReports = reports.where((r) {
          final isOpen = r['status'] == 'OTWARTY';
          if (!isOpen) return false;
          
          if (query.isEmpty) return true;
          
          return (r['unique_id']?.toString().toLowerCase().contains(query) ?? false) ||
              (r['linia']?.toString().toLowerCase().contains(query) ?? false) ||
              (r['lokalizacja']?.toString().toLowerCase().contains(query) ?? false) ||
              (r['opis']?.toString().toLowerCase().contains(query) ?? false);
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeFailureDialog(Map<String, dynamic> report) async {
    final s = AppStrings.of(context);
    final formKey = GlobalKey<FormState>();
    final coNaprawionoController = TextEditingController();
    final ktoNaprawilController = TextEditingController(text: widget.currentUsername);
    DateTime startNaprawy = DateTime.now().subtract(const Duration(hours: 1));
    DateTime koniecNaprawy = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(s.t('closeFailure'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('ID: ${TimeUtils.simplifyFaultId(report['unique_id'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDateTimePicker(s.t('repairStart'), startNaprawy, (dt) => setDialogState(() => startNaprawy = dt)),
                  _buildDateTimePicker(s.t('repairEnd'), koniecNaprawy, (dt) => setDialogState(() => koniecNaprawy = dt)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ktoNaprawilController,
                    decoration: InputDecoration(
                      labelText: s.t('whoFixed'),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? s.t('requiredField') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: coNaprawionoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: s.t('whatFixed'),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? s.t('requiredField') : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final diff = koniecNaprawy.difference(startNaprawy);
                  final minutes = diff.inMinutes;
                  
                  final days = diff.inDays;
                  final hours = diff.inHours % 24;
                  final mins = diff.inMinutes % 60;
                  
                  String durationStr = '';
                  if (days > 0) durationStr += '$days ${s.t('days')} ';
                  if (hours > 0) durationStr += '$hours ${s.t('hours')} ';
                  if (mins > 0) durationStr += '$mins ${s.t('minutes')}';

                  await _dbHelper.updateFailureReport(report['id'], {
                    'status': 'ZAMKNIĘTY',
                    'czy_rozwiazane': 1,
                    'co_naprawiono': coNaprawionoController.text.trim(),
                    'kto_naprawil': ktoNaprawilController.text.trim(),
                    'data_rozpoczecia_naprawy': startNaprawy.toIso8601String(),
                    'data_zakonczenia_naprawy': koniecNaprawy.toIso8601String(),
                    'czas_trwania': durationStr.trim(),
                    'downtime_minutes': minutes,
                  });

                  // Update corresponding task status
                  await _dbHelper.updateTaskByFailureId(report['id'], {
                    'status': 'Zrealizowane',
                  });
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadOpenReports();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(s.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime initial, Function(DateTime) onPicked) {
    final format = DateFormat('yyyy-MM-dd HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (date != null) {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial),
            );
            if (time != null) {
              onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
            }
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(format.format(initial), style: const TextStyle(fontSize: 13)),
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CurrentFailuresScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadOpenReports();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('search'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: s.t('filterHint'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) => _loadOpenReports(showLoader: false),
                      ),
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, size: 18, color: Colors.white),
                      onPressed: () => _loadOpenReports(showLoader: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 36,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white),
                      onPressed: () {
                        _searchController.clear();
                        _loadOpenReports(showLoader: false);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_openReports.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(child: Text(s.t('emptyList'), style: const TextStyle(color: Colors.grey))),
          )
        else
          Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade100),
              verticalInside: BorderSide(color: Colors.grey.shade100),
            ),
            columnWidths: const {
              0: FixedColumnWidth(100),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(3),
              4: FixedColumnWidth(100),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: [
                  _buildHeaderCell('ID'),
                  _buildHeaderCell(s.t('lineName').toUpperCase()),
                  _buildHeaderCell(s.t('location').toUpperCase()),
                  _buildHeaderCell(s.t('description').toUpperCase()),
                  _buildHeaderCell(s.t('status').toUpperCase(), textAlign: TextAlign.center),
                ],
              ),
              ..._openReports.map((report) {
                final createdAt = DateTime.tryParse(report['created_at']?.toString() ?? '') ?? DateTime.now();
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(TimeUtils.simplifyFaultId(report['unique_id']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(report['linia'] ?? '-', style: const TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(report['lokalizacja'] ?? '-', style: const TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: InkWell(
                        onTap: () => _closeFailureDialog(report),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report['opis'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(DateFormat('yyyy-MM-dd HH:mm').format(createdAt), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Center(
                        child: InkWell(
                          onTap: () => _closeFailureDialog(report),
                          child: Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text(s.t('open').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9))),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign textAlign = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87),
      ),
    );
  }
}
