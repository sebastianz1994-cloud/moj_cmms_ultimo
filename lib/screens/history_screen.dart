import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.strings});
  final AppStrings strings;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  List<Map<String, dynamic>> _allReports = [];
  List<Map<String, dynamic>> _filteredReports = [];
  bool _isLoading = true;
  
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPriority = 'All';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final reports = await _dbHelper.getFailureReports();
    setState(() {
      // Show ONLY closed failures in history
      _allReports = reports.where((r) => r['status'] == 'ZAMKNIĘTY').toList();
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReports = _allReports.where((r) {
        final matchesSearch = (r['unique_id']?.toString().toLowerCase().contains(query) ?? false) ||
            (r['linia']?.toString().toLowerCase().contains(query) ?? false) ||
            (r['lokalizacja']?.toString().toLowerCase().contains(query) ?? false) ||
            (r['opis']?.toString().toLowerCase().contains(query) ?? false);

        final matchesPriority = _selectedPriority == 'All' || r['priorytet'] == _selectedPriority;
        
        bool matchesDate = true;
        if (_startDate != null || _endDate != null) {
          final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '');
          if (createdAt != null) {
            if (_startDate != null && createdAt.isBefore(_startDate!)) matchesDate = false;
            if (_endDate != null && createdAt.isAfter(_endDate!.add(const Duration(days: 1)))) matchesDate = false;
          }
        }

        return matchesSearch && matchesPriority && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null 
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterPanel(s),
        const Divider(height: 1),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredReports.isEmpty)
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
              ..._filteredReports.map((report) {
                final createdAt = DateTime.tryParse(report['created_at']?.toString() ?? '') ?? DateTime.now();
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(report['unique_id'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report['opis'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(DateFormat('yyyy-MM-dd HH:mm').format(createdAt), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Center(
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade500,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text(s.t('closed').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9))),
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

  Widget _buildFilterPanel(AppStrings s) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
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
                              onChanged: (_) => _applyFilters(),
                              decoration: InputDecoration(
                                hintText: s.t('filterHint'),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: InputBorder.none,
                                isDense: true,
                              ),
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
                            onPressed: _applyFilters,
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
                              _applyFilters();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('customRange').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _selectDateRange,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _startDate != null && _endDate != null 
                                  ? '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}'
                                  : s.t('all'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_startDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _clearDateRange,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('priority').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPriority,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold),
                          items: ['All', 'Low', 'Medium', 'High', 'Critical'].map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(p == 'All' ? s.t('all') : (s.t(p.toLowerCase()))),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedPriority = val!);
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
