import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import 'production_report_screen.dart';
import '../utils/pdf_generator.dart';
import '../utils/time_utils.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    required this.strings,
    required this.currentUsername,
    this.isEmbedded = false,
  });

  final AppStrings strings;
  final String currentUsername;
  final bool isEmbedded;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  
  // Reports for Storing List (finalized_production_lists)
  List<Map<String, dynamic>> _storingReports = [];
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupedStoringReports = {};
  
  // Reports for Production List (production_reports)
  List<Map<String, dynamic>> _productionReports = [];
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupedProductionReports = {};
  
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0: Production List, 1: Storing List
  final TextEditingController _storingSearchController = TextEditingController();
  final TextEditingController _productionSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  Future<void> _loadAllReports({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _isLoading = true);
    try {
      // Fetch Storing List reports
      final storingReports = await _dbHelper.getFinalizedProductionLists();
      
      // Fetch Production List reports
      final productionReports = await _dbHelper.getProductionReports();

      if (mounted) {
        setState(() {
          _storingReports = storingReports;
          _productionReports = productionReports;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final storingQuery = _storingSearchController.text.trim().toLowerCase();
    final productionQuery = _productionSearchController.text.trim().toLowerCase();

    setState(() {
      // Filter and Group Storing List
      List<Map<String, dynamic>> filteredStoring;
      if (storingQuery.isEmpty) {
        filteredStoring = _storingReports;
      } else {
        filteredStoring = _storingReports.where((r) =>
          (r['operator_name'] as String? ?? '').toLowerCase().contains(storingQuery) ||
          (r['line_name'] as String? ?? '').toLowerCase().contains(storingQuery) ||
          (r['shift'] as String? ?? '').toLowerCase().contains(storingQuery) ||
          (r['date'] as String? ?? '').toLowerCase().contains(storingQuery)
        ).toList();
      }
      _groupedStoringReports = _groupReports(filteredStoring, isProduction: false);

      // Filter and Group Production List
      List<Map<String, dynamic>> filteredProduction;
      if (productionQuery.isEmpty) {
        filteredProduction = _productionReports;
      } else {
        filteredProduction = _productionReports.where((r) =>
          (r['operator_names'] as String? ?? '').toLowerCase().contains(productionQuery) ||
          (r['line'] as String? ?? '').toLowerCase().contains(productionQuery) ||
          (r['shift'] as String? ?? '').toLowerCase().contains(productionQuery) ||
          (r['date'] as String? ?? '').toLowerCase().contains(productionQuery)
        ).toList();
      }
      _groupedProductionReports = _groupReports(filteredProduction, isProduction: true);
    });
  }

  Map<String, Map<String, List<Map<String, dynamic>>>> _groupReports(List<Map<String, dynamic>> reports, {required bool isProduction}) {
    // Structure: { "2024-05-10": { "Morning": [reports...], "Afternoon": [...] } }
    final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    
    for (var report in reports) {
      final date = report['date'] as String;
      final shift = report['shift'] as String? ?? 'Other';
      
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(shift, () => []);
      grouped[date]![shift]!.add(report);
    }
    
    // Sort lines inside each shift (1, 2, 3)
    for (var date in grouped.keys) {
      for (var shift in grouped[date]!.keys) {
        grouped[date]![shift]!.sort((a, b) {
          final lineA = isProduction ? (a['line'] ?? '0') : (a['line_name'] ?? '0');
          final lineB = isProduction ? (b['line'] ?? '0') : (b['line_name'] ?? '0');
          
          // Extract digits only for sorting (e.g., "LIJN 1" -> 1)
          final numA = int.tryParse(lineA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final numB = int.tryParse(lineB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          
          return numA.compareTo(numB);
        });
      }
    }
    
    // Sort dates descending
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<String, Map<String, List<Map<String, dynamic>>>> sortedGrouped = {};
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  void _viewStoringReport(Map<String, dynamic> report) {
    final s = widget.strings;
    final Map<String, dynamic> reportData = jsonDecode(report['report_data']);
    final Map<String, dynamic> downtimeEntries = reportData['downtime_entries'] ?? {};
    final bool barrelsWithWater = reportData['barrels_water'] ?? false;
    final bool camerasCleaned = reportData['cameras_cleaned'] ?? false;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: 800,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('${s.t('productionTile')} - ${report['date']}'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Header info
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildStaticInfoRow(s.t('operator'), report['operator_name']),
                                        const SizedBox(height: 8),
                                        _buildStaticInfoRow(s.t('date'), report['date']),
                                        const SizedBox(height: 16),
                                        Text(s.t('productionLine').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                        const SizedBox(height: 4),
                                        _buildStaticSelector(report['line_name']),
                                        const SizedBox(height: 16),
                                        Text(s.t('shift').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                        const SizedBox(height: 4),
                                        _buildStaticSelector(report['shift']),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.blue.shade100),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(s.t('totalDowntimeMinutesShort').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                            const SizedBox(height: 4),
                                            Text(
                                              downtimeEntries.values.fold(0, (sum, entry) => sum + (entry['minutes'] as int)).toString(),
                                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.t('iceWater').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                        const SizedBox(height: 4),
                                        _buildStaticSelector(barrelsWithWater ? s.t('yes') : s.t('no')),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(s.t('camerasCleaned').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                        const SizedBox(height: 4),
                                        _buildStaticSelector(camerasCleaned ? s.t('yes') : s.t('no')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Table
                        Table(
                          border: TableBorder(
                            horizontalInside: BorderSide(color: Colors.grey.shade100),
                            verticalInside: BorderSide(color: Colors.grey.shade100),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(4),
                            2: FixedColumnWidth(80),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade50),
                              children: [
                                _buildHeaderCell(s.t('name')),
                                _buildHeaderCell(s.t('comments')),
                                _buildHeaderCell(s.t('totalDowntimeMinutesShort'), textAlign: TextAlign.center),
                              ],
                            ),
                            ...downtimeEntries.entries.map((entry) {
                              final reason = entry.key;
                              final data = entry.value as Map<String, dynamic>;
                              final minutes = data['minutes'] as int;
                              final comment = data['comment'] as String? ?? '';
                              
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                                    child: Text(reason, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(comment.isEmpty ? '-' : comment, style: const TextStyle(fontSize: 11)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Center(
                                      child: Text(
                                        minutes > 0 ? '$minutes' : '-',
                                        style: TextStyle(
                                          fontSize: 13, 
                                          fontWeight: FontWeight.bold,
                                          color: minutes > 0 ? Colors.blue.shade900 : Colors.grey,
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticInfoRow(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildStaticSelector(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Future<void> _viewProductionReport(Map<String, dynamic> report) async {
    final s = widget.strings;
    final reportId = report['id'] as int;
    final details = await _dbHelper.getProductionReportDetails(reportId);
    
    if (!mounted) return;

    final reportMeta = details['report'] as Map<String, dynamic>;
    final entries = details['entries'] as List<Map<String, dynamic>>;
    final measurements = details['measurements'] as List<Map<String, dynamic>>;

    // Parse names
    final rawOpNames = reportMeta['operator_names'] as String? ?? '-';
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

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Container(
          width: 1200,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              AppBar(
                title: Text('${s.t('productionReportTitle')} - ${reportMeta['date']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 1,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Date/Line/Shift on Left, Operators on Right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Side: Metadata
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPreviewLabel(s.t('date')),
                                _buildPreviewStaticField(reportMeta['date'], width: 150, hasCalendar: true),
                                const SizedBox(height: 16),
                                _buildPreviewLabel(s.t('productionLine')),
                                Row(
                                  children: ['1', '2', '3'].map((l) => _buildPreviewToggleButton(l, reportMeta['line'] == l)).toList(),
                                ),
                                const SizedBox(height: 16),
                                _buildPreviewLabel(s.t('shift')),
                                Row(
                                  children: [
                                    _buildPreviewToggleButton(s.t('shiftMorning'), _isShiftSelected(s.t('shiftMorning'), reportMeta['shift']), isShift: true),
                                    _buildPreviewToggleButton(s.t('shiftAfternoon'), _isShiftSelected(s.t('shiftAfternoon'), reportMeta['shift']), isShift: true),
                                    _buildPreviewToggleButton(s.t('shiftNight'), _isShiftSelected(s.t('shiftNight'), reportMeta['shift']), isShift: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                          // Right Side: Operators
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPreviewLabel(s.t('operator').toUpperCase()),
                                _buildPreviewStaticField(operators.join(", "), isFullWidth: true),
                                const SizedBox(height: 16),
                                _buildPreviewLabel('HELPOPERATOR'),
                                _buildPreviewStaticField(helpers.join(", "), isFullWidth: true),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      _buildPreviewSectionTitle(s.t('realizedProduction')),
                      
                      // Production Table
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columnWidths: const {
                            0: FlexColumnWidth(2), // Barrel Type
                            1: FlexColumnWidth(1), // Start Time
                            2: FlexColumnWidth(1), // End Time
                            3: FlexColumnWidth(1.2), // Total Production Time
                            4: FlexColumnWidth(4), // Number of Carts
                            5: FlexColumnWidth(1.5), // Total number of barrels
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade50),
                              children: [
                                _buildPreviewHeaderCell(s.t('fustType')),
                                _buildPreviewHeaderCell(s.t('startTime')),
                                _buildPreviewHeaderCell(s.t('endTime')),
                                _buildPreviewHeaderCell('Total production time'),
                                _buildPreviewHeaderCell(s.t('cartCount')),
                                _buildPreviewHeaderCell('Total number of barrels'),
                              ],
                            ),
                            ...entries.map((e) => TableRow(
                              children: [
                                _buildPreviewTableCell(e['fust_type'] ?? '-'),
                                _buildPreviewTableCell(e['start_time'] ?? '00:00'),
                                _buildPreviewTableCell(e['end_time'] ?? '00:00'),
                                _buildPreviewTableCell(TimeUtils.calculateDuration(e['start_time'], e['end_time']), isBlue: true),
                                _buildPreviewTableCell(e['cart_count']?.toString() ?? '0'),
                                _buildPreviewTableCell(e['barrel_count']?.toString() ?? '0', isBold: true),
                              ],
                            )),
                            // Total Row
                            TableRow(
                              children: [
                                const TableCell(child: SizedBox()),
                                const TableCell(child: SizedBox()),
                                const TableCell(child: SizedBox()),
                                const TableCell(child: SizedBox()),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('Total: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800)),
                                      _buildPreviewTotalBox(entries.fold(0, (sum, e) => sum + (e['cart_count'] as int? ?? 0))),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _buildPreviewTotalBox(entries.fold(0, (sum, e) => sum + (e['barrel_count'] as int? ?? 0))),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      _buildPreviewSectionTitle(s.t('chlorineMeasurement')),
                      
                      // Chlorine Horizontal Table
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                        child: Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade50),
                              children: [
                                '23:00', '02:00', '05:00', '08:00', '11:00', '14:00', '15:00', '17:00', '20:00'
                              ].map((time) => _buildPreviewHeaderCell(time)).toList(),
                            ),
                            TableRow(
                              children: [
                                '23:00', '02:00', '05:00', '08:00', '11:00', '14:00', '15:00', '17:00', '20:00'
                              ].map((time) {
                                final m = measurements.firstWhere((m) => m['measurement_time'] == time, orElse: () => {});
                                return _buildPreviewTableCell(m['chlorine_level']?.toString() ?? '', height: 40);
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      _buildPreviewSectionTitle(s.t('endOfShiftChecklist')),
                      Row(
                        children: [
                          _buildPreviewCheckItem(s.t('barrelsEmpty'), reportMeta['barrels_empty'] == 1),
                          const SizedBox(width: 40),
                          _buildPreviewCheckItem(s.t('machineClean'), reportMeta['machine_clean'] == 1),
                          const SizedBox(width: 40),
                          _buildPreviewCheckItem(s.t('nozzlesPierced'), reportMeta['nozzles_pierced'] == 1),
                        ],
                      ),

                      const SizedBox(height: 32),
                      _buildPreviewSectionTitle(s.t('commentsAndDetails')),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (reportMeta['comments'] as String? ?? '').isEmpty ? '-' : reportMeta['comments'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProductionReport(Map<String, dynamic> report) async {
    final reportId = report['id'] as int;
    final details = await _dbHelper.getProductionReportDetails(reportId);
    
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductionReportScreen(
          currentUsername: widget.currentUsername,
          initialData: details,
        ),
      ),
    );

    _loadAllReports();
  }

  Future<void> _downloadProductionPDF(Map<String, dynamic> report) async {
     final reportId = report['id'] as int;
     final details = await _dbHelper.getProductionReportDetails(reportId);
     
     if (!mounted) return;
 
     try {
       await PdfGenerator.generateProductionReportPdf(details);
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error generating PDF: $e')),
         );
       }
     }
   }

  bool _isShiftSelected(String label, dynamic storedValue) {
    if (storedValue == null) return false;
    final stored = storedValue.toString();
    final s = widget.strings;

    if (label == s.t('shiftMorning')) {
      return stored.startsWith('Ochtend') || stored == label;
    } else if (label == s.t('shiftAfternoon')) {
      return stored.startsWith('Middag') || stored == label;
    } else if (label == s.t('shiftNight')) {
      return stored.startsWith('Nacht') || stored == label;
    }
    return stored == label;
  }

  // Preview Helper Widgets
  Widget _buildPreviewLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildPreviewStaticField(String value, {double? width, bool hasCalendar = false, bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
          if (hasCalendar) Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _buildPreviewToggleButton(String label, bool isSelected, {bool isShift = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: EdgeInsets.symmetric(horizontal: isShift ? 16 : 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.grey.shade300 : Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
    );
  }

  Widget _buildPreviewSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  Widget _buildPreviewHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
    );
  }

  Widget _buildPreviewTableCell(String value, {bool isBlue = false, bool isBold = false, double? height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBlue ? Colors.blue.shade600 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTotalBox(int value) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blue.shade300, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(child: Text(value.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900))),
    );
  }

  Widget _buildPreviewCheckItem(String label, bool isChecked) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isChecked ? const Icon(Icons.check, size: 18) : null,
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
    );
  }

  Widget _buildStaticTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Center(child: Text(text, style: const TextStyle(fontSize: 11))),
    );
  }

  Widget _buildStaticChecklistRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(value ? Icons.check_box : Icons.check_box_outline_blank, color: value ? Colors.green : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    Widget body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Side Menu
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildMenuButton(
                icon: Icons.factory_outlined,
                label: 'Production List',
                index: 0,
                count: _productionReports.length,
              ),
              _buildMenuButton(
                icon: Icons.inventory_2_outlined,
                label: 'Storing List',
                index: 1,
                count: _storingReports.length,
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _selectedTabIndex == 0
                      ? _buildReportList(
                          title: 'Production List',
                          groupedReports: _groupedProductionReports,
                          isProduction: true,
                          s: s,
                          controller: _productionSearchController,
                        )
                      : _buildReportList(
                          title: 'Storing List',
                          groupedReports: _groupedStoringReports,
                          isProduction: false,
                          s: s,
                          controller: _storingSearchController,
                        ),
                ),
        ),
      ],
    );

    if (widget.isEmbedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('documentation')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => _loadAllReports(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required int index,
    required int count,
  }) {
    final isSelected = _selectedTabIndex == index;
    final color = isSelected ? Colors.blue : Colors.grey.shade600;

    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 4,
            ),
          ),
          color: isSelected ? Colors.blue.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue.shade800 : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.blue.shade800 : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList({
    required String title,
    required Map<String, Map<String, List<Map<String, dynamic>>>> groupedReports,
    required bool isProduction,
    required AppStrings s,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
            ),
            const Spacer(),
            Container(
              width: 300,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade100 : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Center(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 13),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: s.t('searchHintAssets'),
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: groupedReports.isEmpty
              ? Center(
                  child: Text(s.t('emptyList'), style: const TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: groupedReports.length,
                  itemBuilder: (context, index) {
                    final dateEntry = groupedReports.entries.elementAt(index);
                    final date = dateEntry.key;
                    final shifts = dateEntry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: index == 0,
                        title: Text(
                          date,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                        ),
                        children: shifts.entries.map((shiftEntry) {
                          final shift = shiftEntry.key;
                          final reports = shiftEntry.value;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                                child: Text(
                                  shift, 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                                child: Table(
                                  border: TableBorder(
                                    horizontalInside: BorderSide(color: Colors.grey.shade100),
                                  ),
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.5),
                                    1: FlexColumnWidth(2.5),
                                    2: FlexColumnWidth(2),
                                    3: FlexColumnWidth(1),
                                    4: FixedColumnWidth(180),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade50 : Colors.grey.shade900),
                                      children: [
                                        _buildHeaderCell(s.t('operator')),
                                        _buildHeaderCell('Helpoperator'),
                                        _buildHeaderCell('Barrel type'),
                                        _buildHeaderCell(s.t('lineName')),
                                        _buildHeaderCell(''),
                                      ],
                                    ),
                                    ...reports.asMap().entries.map((entry) {
                              final reportIndex = entry.key;
                              final report = entry.value;
                              
                              final rawOpNames = isProduction ? (report['operator_names'] ?? '-') : (report['operator_name'] ?? '-');
                              final barrelType = isProduction ? (report['barrel_types'] ?? '-') : '-';
                              final line = isProduction ? (report['line'] ?? '-') : (report['line_name'] ?? '-');

                              // Parse operator names to separate operators and helpers
                              List<String> operators = [];
                              List<String> helpers = [];
                              
                              if (isProduction) {
                                final parts = (rawOpNames as String).split(', ');
                                for (var p in parts) {
                                  if (p.startsWith('Helpoperator: ')) {
                                    helpers.add(p.replaceFirst('Helpoperator: ', ''));
                                  } else if (p.startsWith('Helper: ')) {
                                    helpers.add(p.replaceFirst('Helper: ', ''));
                                  } else {
                                    operators.add(p);
                                  }
                                }
                              } else {
                                operators.add(rawOpNames as String);
                              }

                              // Sprawdź czy to duplikat (czy w tej samej dacie i zmianie istnieje raport sfinalizowany WCZEŚNIEJ dla tej samej linii)
                              bool isDuplicate = false;
                              final currentCreatedAt = DateTime.tryParse(report['created_at'] ?? '') ?? DateTime.now();
                              
                              for (var otherReport in reports) {
                                if (otherReport == report) continue;
                                
                                final otherLine = isProduction ? (otherReport['line'] ?? '-') : (otherReport['line_name'] ?? '-');
                                if (otherLine == line) {
                                  final otherCreatedAt = DateTime.tryParse(otherReport['created_at'] ?? '') ?? DateTime.now();
                                  // Jeśli inny raport dla tej samej linii został utworzony wcześniej, to obecny jest duplikatem
                                  if (otherCreatedAt.isBefore(currentCreatedAt)) {
                                    isDuplicate = true;
                                    break;
                                  }
                                }
                              }

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: isDuplicate 
                                      ? Colors.red.withOpacity(0.1) 
                                      : (Theme.of(context).brightness == Brightness.light ? Colors.transparent : Colors.transparent),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12.0), 
                                    child: Text(
                                      operators.join(", "), 
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: isDuplicate ? Colors.red.shade900 : null,
                                        fontWeight: isDuplicate ? FontWeight.bold : FontWeight.w500,
                                      ), 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis
                                    )
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0), 
                                    child: Text(
                                      helpers.isNotEmpty ? helpers.join(", ") : '-',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDuplicate ? Colors.red.shade900 : Colors.grey.shade700,
                                        fontStyle: helpers.isNotEmpty ? FontStyle.italic : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0), 
                                    child: Text(
                                      barrelType, 
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDuplicate ? Colors.red.shade900 : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0), 
                                    child: Text(
                                      line, 
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDuplicate ? Colors.red.shade900 : null,
                                        fontWeight: isDuplicate ? FontWeight.bold : null,
                                      )
                                    )
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.visibility_outlined, size: 20, color: isDuplicate ? Colors.red.shade700 : Colors.blue),
                                        onPressed: () => isProduction ? _viewProductionReport(report) : _viewStoringReport(report),
                                        tooltip: s.t('preview'),
                                      ),
                                      if (isProduction) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.orange),
                                          onPressed: () => _editProductionReport(report),
                                          tooltip: s.t('edit'),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.red),
                                          onPressed: () => _downloadProductionPDF(report),
                                          tooltip: 'PDF',
                                        ),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: Text(s.t('deleteConfirm')),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                                                        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('delete'), style: const TextStyle(color: Colors.red))),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    if (isProduction) {
                                                      await _dbHelper.deleteProductionReport(report['id']);
                                                    } else {
                                                      await _dbHelper.deleteFinalizedProductionList(report['id']);
                                                    }
                                                    _loadAllReports();
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign? textAlign}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text.toUpperCase(), 
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey),
        textAlign: textAlign,
      ),
    );
  }
}
