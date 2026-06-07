import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import 'add_warehouse_item_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key, required this.strings, this.isEmbedded = false});
  final AppStrings strings;
  final bool isEmbedded;

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await _dbHelper.getWarehouseItems();
    setState(() {
      _items = items;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        return item['name'].toString().toLowerCase().contains(query) ||
               item['code'].toString().toLowerCase().contains(query) ||
               item['category'].toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _openAddScreen([Map<String, dynamic>? item]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWarehouseItemScreen(
          strings: widget.strings,
          item: item,
        ),
      ),
    );

    if (result == true) {
      _loadItems();
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
            // 1. Header (Add button & Search)
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
                        onPressed: () => _openAddScreen(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(s.t('addPart'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                      const Spacer(),
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
                            Text('SZUKAJ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
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
                                      onChanged: (_) => _applyFilter(),
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
                                  child: const Icon(Icons.search, size: 18, color: Colors.white),
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
                                      _applyFilter();
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
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('Brak przedmiotów w magazynie', style: TextStyle(color: Colors.grey))),
              )
            else
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey.shade100),
                  verticalInside: BorderSide(color: Colors.grey.shade100),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(100), // Kod
                  1: FlexColumnWidth(2),    // Nazwa
                  2: FlexColumnWidth(1.5),  // Kategoria
                  3: FlexColumnWidth(1.5),  // Lokalizacja
                  4: FixedColumnWidth(100), // Stan
                  5: FixedColumnWidth(100), // Akcje
                },
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    children: [
                      _buildHeaderCell(s.t('code').toUpperCase()),
                      _buildHeaderCell(s.t('name').toUpperCase()),
                      _buildHeaderCell(s.t('category').toUpperCase()),
                      _buildHeaderCell(s.t('location').toUpperCase()),
                      _buildHeaderCell(s.t('quantity').toUpperCase(), textAlign: TextAlign.center),
                      _buildHeaderCell(''),
                    ],
                  ),
                  // Data Rows
                  ..._filteredItems.map((item) {
                    final bool isLow = (item['quantity'] as int) <= (item['min_quantity'] as int);
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(item['code'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(item['name'] ?? '-', style: const TextStyle(fontSize: 11)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(item['category'] ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(item['location'] ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLow ? Colors.red.shade400 : Colors.green.shade500,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${item['quantity']}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _openAddScreen(item),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final current = item['quantity'] as int;
                                  if (current > 0) {
                                    await _dbHelper.updateWarehouseItemQuantity(item['id'], current - 1);
                                    _loadItems();
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final current = item['quantity'] as int;
                                  await _dbHelper.updateWarehouseItemQuantity(item['id'], current + 1);
                                  _loadItems();
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Usuń przedmiot'),
                                      content: Text('Czy na pewno chcesz usunąć ${item['name']}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Usuń', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _dbHelper.deleteWarehouseItem(item['id']);
                                    _loadItems();
                                  }
                                },
                              ),
                            ],
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
        title: Text(s.t('warehouse'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
}
