import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';
import '../models/asset.dart';
import 'add_asset_screen.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key, required this.strings, this.isEmbedded = false});
  final AppStrings strings;
  final bool isEmbedded;

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  List<Asset> _assets = [];
  List<Asset> _filteredAssets = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    final assets = await _dbHelper.getAssets();
    setState(() {
      _assets = assets;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAssets = _assets.where((asset) {
        return asset.nazwa.toLowerCase().contains(query) ||
               asset.kod.toLowerCase().contains(query) ||
               asset.lokalizacja.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _openAddScreen([Asset? asset]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAssetScreen(
          strings: widget.strings,
          asset: asset,
        ),
      ),
    );

    if (result == true) {
      _loadAssets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;

    Widget body = SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (Add button & Search)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade50 : Colors.grey.shade900,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openAddScreen(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(s.t('addMachine'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            Text(s.t('searchMachine'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                                      onChanged: (_) => _applyFilter(),
                                      decoration: InputDecoration(
                                        hintText: s.t('searchHintAssets'),
                                        hintStyle: TextStyle(color: Colors.grey.shade400),
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

            // The Table
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredAssets.isEmpty)
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
                  0: FixedColumnWidth(120), // Kod
                  1: FlexColumnWidth(2),    // Nazwa
                  2: FlexColumnWidth(1.5),  // Lokalizacja
                  3: FixedColumnWidth(100), // Akcje
                },
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade50 : Colors.grey.shade900),
                    children: [
                      _buildHeaderCell(s.t('code').toUpperCase()),
                      _buildHeaderCell(s.t('name').toUpperCase()),
                      _buildHeaderCell(s.t('location').toUpperCase()),
                      _buildHeaderCell(s.t('actions').toUpperCase(), textAlign: TextAlign.center),
                    ],
                  ),
                  // Data Rows
                  ..._filteredAssets.map((asset) {
                      final textColor = Theme.of(context).textTheme.bodyMedium?.color;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                            child: Text(asset.kod, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                            child: Text(asset.nazwa, style: TextStyle(fontSize: 11, color: textColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                            child: Text(asset.lokalizacja, style: TextStyle(fontSize: 11, color: textColor?.withOpacity(0.6))),
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
                                  onPressed: () => _openAddScreen(asset),
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
                                        title: Text(s.t('deleteMachine')),
                                        content: Text('${s.t('deleteConfirm')} (${asset.nazwa})'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text(s.t('delete'), style: const TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _dbHelper.deleteAsset(asset.id!);
                                      _loadAssets();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.t('machinesTile'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.black,
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
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.titleSmall?.color ?? Colors.grey.shade600,
        ),
      ),
    );
  }
}
