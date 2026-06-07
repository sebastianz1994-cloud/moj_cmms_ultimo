import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../app_strings.dart';
import '../database/db_helper.dart';

class StoringslogScreen extends StatefulWidget {
  const StoringslogScreen({
    super.key,
    required this.currentUsername,
    this.isEmbedded = false,
  });

  final String currentUsername;
  final bool isEmbedded;

  @override
  State<StoringslogScreen> createState() => _StoringslogScreenState();
}

class _StoringslogScreenState extends State<StoringslogScreen> {
  String _selectedCategory = 'pollution';
  final DBHelper _dbHelper = DBHelper.instance;
  final ImagePicker _picker = ImagePicker();

  // Pollution state
  final Map<String, TextEditingController> _pollutionControllers = {};
  final Map<String, File?> _pollutionImages = {};

  // Process state
  final Map<String, TextEditingController> _processControllers = {};
  final Map<String, File?> _processImages = {};

  // Others state
  final TextEditingController _otherCommentController = TextEditingController();
  File? _otherImage;

  // Finalization state
  final List<Map<String, dynamic>> _collectedEntries = [];
  bool _isFinalizing = false;

  bool _isSending = false;

  // Technology state
  final TextEditingController _techPartController = TextEditingController();
  final TextEditingController _techWhoFixedController = TextEditingController();
  final TextEditingController _techDurationController = TextEditingController();
  String? _techIsFixed;
  File? _techImage;

  @override
  void initState() {
    super.initState();
    _initPollutionState();
  }

  void _initPollutionState() {
    final pollutionKeys = [
      'pollutionInvoerrobot',
      'pollutionVallendeStapels',
      'pollutionOntnester',
      'pollutionWasmachine',
      'pollutionStapelaar'
    ];
    for (var key in pollutionKeys) {
      _pollutionControllers[key] = TextEditingController();
      _pollutionImages[key] = null;
    }

    final processKeys = [
      'processLijnVerstopt',
      'processWachtenOpOperator',
      'processSensorVervuild',
      'processInstellingFout',
      'processProductieStop'
    ];
    for (var key in processKeys) {
      _processControllers[key] = TextEditingController();
      _processImages[key] = null;
    }
  }

  @override
  void dispose() {
    for (var controller in _pollutionControllers.values) {
      controller.dispose();
    }
    for (var controller in _processControllers.values) {
      controller.dispose();
    }
    _techPartController.dispose();
    _techWhoFixedController.dispose();
    _techDurationController.dispose();
    _otherCommentController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(String key) async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _pollutionImages[key] = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      final s = AppStrings.of(context);
      final List<Map<String, dynamic>> entries = [];
      final now = DateTime.now().toIso8601String();

      if (_selectedCategory == 'pollution') {
        for (var entry in _pollutionControllers.entries) {
          final minutes = int.tryParse(entry.value.text) ?? 0;
          if (minutes > 0 || _pollutionImages[entry.key] != null) {
            entries.add({
              'category': _selectedCategory,
              'reason_key': entry.key,
              'minutes': minutes,
              'image_path': _pollutionImages[entry.key]?.path,
              'username': widget.currentUsername,
              'created_at': now,
            });
          }
        }
      } else if (_selectedCategory == 'process') {
        for (var entry in _processControllers.entries) {
          final minutes = int.tryParse(entry.value.text) ?? 0;
          if (minutes > 0 || _processImages[entry.key] != null) {
            entries.add({
              'category': _selectedCategory,
              'reason_key': entry.key,
              'minutes': minutes,
              'image_path': _processImages[entry.key]?.path,
              'username': widget.currentUsername,
              'created_at': now,
            });
          }
        }
      } else if (_selectedCategory == 'technology') {
        final part = _techPartController.text.trim();
        final who = _techWhoFixedController.text.trim();
        final duration = int.tryParse(_techDurationController.text) ?? 0;
        
        if (part.isNotEmpty || who.isNotEmpty || duration > 0 || _techImage != null) {
          entries.add({
            'category': _selectedCategory,
            'tech_part': part,
            'is_fixed': _techIsFixed,
            'who_fixed': who,
            'duration': duration,
            'image_path': _techImage?.path,
            'username': widget.currentUsername,
            'created_at': now,
          });
        }
      } else if (_selectedCategory == 'other') {
        final comment = _otherCommentController.text.trim();
        if (comment.isNotEmpty || _otherImage != null) {
          entries.add({
            'category': _selectedCategory,
            'comment': comment,
            'image_path': _otherImage?.path,
            'username': widget.currentUsername,
            'created_at': now,
          });
        }
      }

      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('noDataToSave'))),
        );
        setState(() => _isSending = false);
        return;
      }

      // Collect entries for final report
      setState(() {
        _collectedEntries.addAll(entries);
      });

      // Backup per-send to database storage
      for (var entry in entries) {
        await _dbHelper.saveModuleBackup(
          'storingslog', 
          'send_${DateTime.now().millisecondsSinceEpoch}.json', 
          jsonEncode(entry)
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.t('saveSuccess')),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        setState(() {
          for (var controller in _pollutionControllers.values) {
            controller.clear();
          }
          for (var key in _pollutionImages.keys) {
        _pollutionImages[key] = null;
      }

      // Clear process form
      for (var controller in _processControllers.values) {
        controller.clear();
      }
      for (var key in _processImages.keys) {
        _processImages[key] = null;
      }

      // Clear technology form
      _techPartController.clear();
      _techWhoFixedController.clear();
      _techDurationController.clear();
      _techIsFixed = null;
      _techImage = null;

      // Clear other form
      _otherCommentController.clear();
      _otherImage = null;
      
      _isSending = false;
        });
      }
    } catch (e) {
      debugPrint('Error sending storingslog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _handleFinalize() async {
    if (_isFinalizing || _collectedEntries.isEmpty) return;

    setState(() => _isFinalizing = true);

    try {
      final s = AppStrings.of(context);
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final fileName = "storingslog_report_${dateStr}_${now.millisecondsSinceEpoch}.json";

      final reportData = {
        'type': 'storingslog_report',
        'operator': widget.currentUsername,
        'date': dateStr,
        'timestamp': now.toIso8601String(),
        'entries': _collectedEntries,
      };

      final jsonContent = jsonEncode(reportData);

      // Save to database/documents via module helper
      await _dbHelper.saveModuleBackup('storingslog', fileName, jsonContent);

      // Register in global documents table
      // Note: We use a simplified document registration for storingslog
      // using raw database query as we don't have a specific report_id from production_reports
      final db = await _dbHelper.database;
      await db.insert('production_documents', {
        'report_id': 0, // 0 indicates it's a standalone storingslog report
        'file_name': 'Storingslog - $dateStr',
        'file_path': fileName, // Store the filename/path
        'created_at': now.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.t('reportGenerated')),
            backgroundColor: Colors.blue,
          ),
        );

        setState(() {
          _collectedEntries.clear();
          _isFinalizing = false;
        });
      }
    } catch (e) {
      debugPrint('Error finalizing storingslog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isFinalizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('storingslogInspiratie')),
        leading: SizedBox(
          width: 120, // Zwiększona szerokość dla dwóch ikon
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8), // Padding od lewej
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (widget.isEmbedded) {
                    // W trybie PC używamy Navigator.maybePop dla bezpieczeństwa, 
                    // ale zazwyczaj to HomeScreen zarządza stanem
                    Navigator.of(context).maybePop();
                  } else {
                    Navigator.pop(context);
                  }
                },
                tooltip: s.t('back') ?? 'Back',
              ),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 120, // Musi być zgodne z szerokością SizedBox w leading
        actions: [
          if (_collectedEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isFinalizing ? null : _handleFinalize,
                icon: _isFinalizing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.done_all, color: Colors.white),
                label: Text(
                  s.t('finalizeStoringslog'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      s.t('storingslogInspiratie').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.cleaning_services_outlined,
              label: s.t('pollution'),
              category: 'pollution',
            ),
            _buildDrawerItem(
              icon: Icons.sync_alt,
              label: s.t('process'),
              category: 'process',
            ),
            _buildDrawerItem(
              icon: Icons.biotech_outlined,
              label: s.t('technology'),
              category: 'technology',
            ),
            _buildDrawerItem(
              icon: Icons.more_horiz,
              label: s.t('other_category'),
              category: 'other',
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'v1.0.0',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: _buildCategoryContent(s),
    );
  }

  Widget _buildPollutionList(AppStrings s) {
    final keys = [
      'pollutionInvoerrobot',
      'pollutionVallendeStapels',
      'pollutionOntnester',
      'pollutionWasmachine',
      'pollutionStapelaar'
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Category Title
          Text(
            s.t('pollution'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 1,
                child: Text(
                  s.t('timeLostMin'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // List Items
          Expanded(
            child: ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    children: [
                      // Bullet and Text
                      Expanded(
                        flex: 3,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.circle, size: 8, color: Colors.black),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.t(key),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Camera Icon
                      IconButton(
                        onPressed: () => _takePhoto(key),
                        icon: Icon(
                          _pollutionImages[key] != null ? Icons.check_circle : Icons.camera_alt_outlined,
                          color: _pollutionImages[key] != null ? Colors.green : Colors.grey.shade700,
                        ),
                        tooltip: 'Photo',
                      ),
                      const SizedBox(width: 16),
                      // Time Input
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _pollutionControllers[key],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Send Button
          const SizedBox(height: 24),
          _buildSendButton(s, width: 250),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProcessList(AppStrings s) {
    final keys = [
      'processLijnVerstopt',
      'processWachtenOpOperator',
      'processSensorVervuild',
      'processInstellingFout',
      'processProductieStop'
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Category Title
          Text(
            s.t('process'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 1,
                child: Text(
                  s.t('timeLostMin'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // List Items
          Expanded(
            child: ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    children: [
                      // Bullet and Text
                      Expanded(
                        flex: 3,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.circle, size: 8, color: Colors.black),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.t(key),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Camera Icon
                      IconButton(
                        onPressed: () async {
                          final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                          if (photo != null) {
                            setState(() {
                              _processImages[key] = File(photo.path);
                            });
                          }
                        },
                        icon: Icon(
                          _processImages[key] != null ? Icons.check_circle : Icons.camera_alt_outlined,
                          color: _processImages[key] != null ? Colors.green : Colors.grey.shade700,
                        ),
                        tooltip: 'Photo',
                      ),
                      const SizedBox(width: 16),
                      // Time Input
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _processControllers[key],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Send Button
          const SizedBox(height: 24),
          _buildSendButton(s, width: 250),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTechnologyList(AppStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Title
          Center(
            child: Text(
              s.t('technology'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          _buildTechQuestion(s.t('techPartBroken'), _techPartController),
          const SizedBox(height: 24),
          _buildTechQuestion(s.t('techFixed'), null, isDropdown: true, dropdownValue: _techIsFixed, 
            onDropdownChanged: (v) => setState(() => _techIsFixed = v),
            dropdownItems: [s.t('yes'), s.t('no')]),
          const SizedBox(height: 24),
          _buildTechQuestion(s.t('techWhoFixed'), _techWhoFixedController),
          const SizedBox(height: 24),
          _buildTechQuestion(s.t('techStopDuration'), _techDurationController, isNumeric: true),
          const SizedBox(height: 24),
          Text(
            s.t('techUploadPicture'),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Center(
            child: IconButton(
              onPressed: () async {
                final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                if (photo != null) {
                  setState(() => _techImage = File(photo.path));
                }
              },
              icon: Icon(
                _techImage != null ? Icons.check_circle : Icons.camera_alt_outlined,
                size: 48,
                color: _techImage != null ? Colors.green : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 48),
          // Send Button
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  s.t('send'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _isSending ? null : _handleSend,
                  child: Container(
                    height: 2,
                    width: 200,
                    color: Colors.black,
                  ),
                ),
                if (_isSending)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechQuestion(String question, TextEditingController? controller, {
    bool isDropdown = false,
    String? dropdownValue,
    List<String>? dropdownItems,
    Function(String?)? onDropdownChanged,
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: isDropdown 
                ? DropdownButtonFormField<String>(
                    value: dropdownValue,
                    items: dropdownItems?.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                    onChanged: onDropdownChanged,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2)),
                    ),
                  )
                : TextField(
                    controller: controller,
                    keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                    inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : [],
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2)),
                    ),
                  ),
            ),
            if (isDropdown) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_downward, size: 20),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildOthersList(AppStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            s.t('other_category'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Large Text Box
              Expanded(
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: TextField(
                    controller: _otherCommentController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Camera Icon to the right
              IconButton(
                onPressed: () async {
                  final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                  if (photo != null) {
                    setState(() => _otherImage = File(photo.path));
                  }
                },
                icon: Icon(
                  _otherImage != null ? Icons.check_circle : Icons.camera_alt_outlined,
                  size: 32,
                  color: _otherImage != null ? Colors.green : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSendButton(s, width: 200),
        ],
      ),
    );
  }

  Widget _buildSendButton(AppStrings s, {double width = 200}) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: width,
        height: 45,
        child: ElevatedButton.icon(
          onPressed: _isSending ? null : _handleSend,
          icon: _isSending 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded),
          label: Text(
            s.t('send').toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required String category,
  }) {
    final isSelected = _selectedCategory == category;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : null,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
        Navigator.pop(context); // Close drawer
      },
    );
  }

  Widget _buildCategoryContent(AppStrings s) {
    if (_selectedCategory == 'pollution') {
      return _buildPollutionList(s);
    }
    if (_selectedCategory == 'process') {
      return _buildProcessList(s);
    }
    if (_selectedCategory == 'technology') {
      return _buildTechnologyList(s);
    }
    if (_selectedCategory == 'other') {
      return _buildOthersList(s);
    }

    String title;
    IconData icon;
    
    switch (_selectedCategory) {
      case 'pollution':
        title = s.t('pollution');
        icon = Icons.cleaning_services_outlined;
        break;
      case 'process':
        title = s.t('process');
        icon = Icons.sync_alt;
        break;
      case 'technology':
        title = s.t('technology');
        icon = Icons.biotech_outlined;
        break;
      case 'other':
      default:
        title = s.t('other_category');
        icon = Icons.more_horiz;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            s.t('soonAvailable'),
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
