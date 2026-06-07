import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';

class EmergencyNumbersScreen extends StatefulWidget {
  const EmergencyNumbersScreen({
    super.key,
    required this.currentUsername,
    this.isEmbedded = false,
  });

  final String currentUsername;
  final bool isEmbedded;

  @override
  State<EmergencyNumbersScreen> createState() => _EmergencyNumbersScreenState();
}

class _EmergencyNumbersScreenState extends State<EmergencyNumbersScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  List<Map<String, dynamic>> _numbers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNumbers();
  }

  Future<void> _loadNumbers({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _isLoading = true);
    try {
      final data = await _dbHelper.getEmergencyNumbers(query: _searchController.text);
      if (mounted) {
        setState(() {
          _numbers = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditNumber([Map<String, dynamic>? existing]) async {
    final s = AppStrings.of(context);
    final nameController = TextEditingController(text: existing?['name']);
    final numberController = TextEditingController(text: existing?['number']);
    final categoryController = TextEditingController(text: existing?['category']);
    String selectedPriority = existing?['priority'] ?? 'Medium';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? s.t('addNumber') : s.t('editNumber')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: s.t('emergencyName'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberController,
                  decoration: InputDecoration(
                    labelText: s.t('phoneNumber'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: s.t('emergencyCategory'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: InputDecoration(
                    labelText: s.t('priority'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(s.t(p.toLowerCase())))).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedPriority = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || numberController.text.trim().isEmpty) return;
                
                final data = {
                  'name': nameController.text.trim(),
                  'number': numberController.text.trim(),
                  'category': categoryController.text.trim(),
                  'priority': selectedPriority,
                  'created_at': existing?['created_at'] ?? DateTime.now().toIso8601String(),
                  'created_by': widget.currentUsername,
                };

                if (existing != null) {
                  await _dbHelper.updateEmergencyNumber(existing['id'], data);
                } else {
                  await _dbHelper.insertEmergencyNumber(data);
                }
                if (context.mounted) Navigator.pop(context);
                _loadNumbers();
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High': return Colors.red.shade400;
      case 'Medium': return Colors.orange.shade400;
      case 'Low': return Colors.green.shade400;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    Widget body = SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _addOrEditNumber(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(s.t('addNumber'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
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
                                      decoration: InputDecoration(
                                        hintText: s.t('searchHintNumbers'),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                      onSubmitted: (_) => _loadNumbers(showLoader: false),
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
                                    onPressed: () => _loadNumbers(showLoader: false),
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
                                      _loadNumbers(showLoader: false);
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
                ],
              ),
            ),

            const Divider(height: 1),

            // 2. The Table
            Table(
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade100),
                verticalInside: BorderSide(color: Colors.grey.shade100),
              ),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FixedColumnWidth(100),
                4: FixedColumnWidth(48),
              },
              children: [
                // Header Row
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    _buildHeaderCell(s.t('emergencyName').toUpperCase()),
                    _buildHeaderCell(s.t('phoneNumber').toUpperCase()),
                    _buildHeaderCell(s.t('category').toUpperCase()),
                    _buildHeaderCell(s.t('priority').toUpperCase(), textAlign: TextAlign.center),
                    _buildHeaderCell(''),
                  ],
                ),
                // Data Rows
                if (!_isLoading && _numbers.isNotEmpty)
                  ..._numbers.map((num) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(num['name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(num['number'], style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(num['category'] ?? '-', style: const TextStyle(fontSize: 11)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Center(child: _buildPriorityBadge(num['priority'] ?? 'Medium')),
                        ),
                        Center(
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                _addOrEditNumber(num);
                              } else if (val == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.t('deleteNumber')),
                                    content: Text(s.t('deleteNumberConfirm')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('deleteTask'), style: const TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _dbHelper.deleteEmergencyNumber(num['id']);
                                  _loadNumbers();
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 18), const SizedBox(width: 8), Text(s.t('editNote'))])),
                              PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size: 18, color: Colors.red), const SizedBox(width: 8), Text(s.t('deleteTask'), style: const TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
              ],
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_numbers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text(s.t('noNumbers'), style: const TextStyle(color: Colors.grey))),
              ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.t('emergencyNumbers'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: body,
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

  Widget _buildPriorityBadge(String priority) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          priority.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
        ),
      ),
    );
  }
}
