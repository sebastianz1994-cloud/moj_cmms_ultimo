import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({
    super.key,
    required this.strings,
    required this.currentUsername,
    this.isEmbedded = false,
  });

  final AppStrings strings;
  final String currentUsername;
  final bool isEmbedded;

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _isLoading = true);
    try {
      final allNotes = await _dbHelper.getNotes(widget.currentUsername);
      final query = _searchController.text.toLowerCase();
      
      if (mounted) {
        setState(() {
          if (query.isEmpty) {
            _notes = allNotes;
          } else {
            _notes = allNotes.where((n) => 
              (n['title'] as String).toLowerCase().contains(query) || 
              (n['content'] as String).toLowerCase().contains(query)
            ).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditNote([Map<String, dynamic>? existingNote]) async {
    final s = widget.strings;
    final titleController = TextEditingController(text: existingNote?['title']);
    final contentController = TextEditingController(text: existingNote?['content']);
    
    final List<Color> noteColors = [
      Colors.yellow.shade200,
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.pink.shade100,
      Colors.purple.shade100,
    ];
    
    Color selectedColor = existingNote != null 
        ? Color(int.parse(existingNote['color_hex'], radix: 16)) 
        : noteColors[0];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existingNote == null ? s.t('addNote') : s.t('editNote')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: s.t('noteTitle'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: s.t('noteContent'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: noteColors.map((color) => GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = color),
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == color ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                final noteData = {
                  'username': widget.currentUsername,
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'created_at': existingNote?['created_at'] ?? DateTime.now().toIso8601String(),
                  'color_hex': selectedColor.value.toRadixString(16),
                };

                if (existingNote != null) {
                  await _dbHelper.updateNote(existingNote['id'], noteData);
                } else {
                  await _dbHelper.insertNote(noteData);
                }
                if (context.mounted) Navigator.pop(context);
                _loadNotes();
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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

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
            // Header
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
                        onPressed: () => _addOrEditNote(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(s.t('addNote'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                      color: Theme.of(context).cardColor,
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                                      decoration: InputDecoration(
                                        hintText: s.t('searchHintNotes'),
                                        hintStyle: TextStyle(color: Colors.grey.shade400),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                      onSubmitted: (_) => _loadNotes(showLoader: false),
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
                                    onPressed: () => _loadNotes(showLoader: false),
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
                                      _loadNotes(showLoader: false);
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
                1: FlexColumnWidth(3),
                2: FixedColumnWidth(100),
                3: FixedColumnWidth(120),
                4: FixedColumnWidth(48),
              },
              children: [
                // Header Row
                TableRow(
                  decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade50 : Colors.grey.shade900),
                  children: [
                    _buildHeaderCell(s.t('noteTitle').toUpperCase()),
                    _buildHeaderCell(s.t('noteContent').toUpperCase()),
                    _buildHeaderCell(s.t('category').toUpperCase()),
                    _buildHeaderCell(s.t('date').toUpperCase()),
                    _buildHeaderCell(''),
                  ],
                ),
                // Data Rows
                if (!_isLoading && _notes.isNotEmpty)
                  ..._notes.map((note) {
                    final createdAt = DateTime.tryParse(note['created_at']) ?? DateTime.now();
                    final colorHex = note['color_hex'] as String? ?? 'FFFFFF';
                    final color = Color(int.parse(colorHex, radix: 16));
                    const textColor = Colors.black87;

                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(note['title'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(
                            note['content'] ?? '-', 
                            style: const TextStyle(fontSize: 11, color: textColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Center(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(createdAt),
                            style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                          ),
                        ),
                        Center(
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                _addOrEditNote(note);
                              } else if (val == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.t('deleteNote')),
                                    content: Text(s.t('deleteConfirm')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('delete'), style: const TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _dbHelper.deleteNote(note['id']);
                                  _loadNotes();
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 18), const SizedBox(width: 8), Text(s.t('edit'))])),
                              PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size: 18, color: Colors.red), const SizedBox(width: 8), Text(s.t('delete'), style: const TextStyle(color: Colors.red))])),
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
            else if (_notes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text(s.t('noNotesDisplay'), style: const TextStyle(color: Colors.grey))),
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
        title: Text(s.t('notebook'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
