import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_strings.dart';
import '../database/db_helper.dart';
import '../utils/file_export.dart' as exporter;

import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';

class ProductionListScreen extends StatefulWidget {
  const ProductionListScreen({
    super.key,
    required this.currentUsername,
    this.isEmbedded = false,
  });

  final String currentUsername;
  final bool isEmbedded;

  @override
  State<ProductionListScreen> createState() => _ProductionListScreenState();
}

class _ProductionListScreenState extends State<ProductionListScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  String? _selectedLine;
  String? _selectedShift;
  DateTime _selectedDate = DateTime.now();
  final List<TextEditingController> _operatorControllers = [TextEditingController()];
  bool? _barrelsWithWater;
  bool? _camerasCleaned;
  int _defectiveCarts = 0;
  final TextEditingController _causesController = TextEditingController();
  
  final Map<String, int> _downtimeData = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, TextEditingController> _downtimeControllers = {};
  final Map<String, List<Map<String, dynamic>>> _reasonPhotos = {};
  final ImagePicker _imagePicker = ImagePicker();
  String _activeCategory = 'Pollution';
  bool _isLoading = false;
  bool _showHistory = false;
  DateTime _historyDate = DateTime.now();
  int _step = 0; // 0: Selection, 1: Downtime Table
  List<String> _savedNames = [];
  
  // Autosave and Status
  Timer? _autoSaveTimer;
  String _saveStatus = '';
  DateTime? _lastSaveTime;
  bool _isSaving = false;
  bool _isLocked = false;

  // History filters
  String? _filterLine;
  String? _filterShift;
  String? _filterOperator;

  final List<String> _lineOptions = [
    'LIJN 1',
    'LIJN 2',
    'LIJN 3',
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

  late final List<String> _shiftOptions;
  late final List<String> _reasons;
  late final List<String> _downtimeReasons;
  late final List<String> _pollutionReasons;
  late final List<String> _processReasons;
  late final List<String> _technicalFaultReasons;
  bool _optionsInitialized = false;
  bool _isInitialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
    _loadSavedNames();
  }

  Future<void> _loadSavedNames() async {
    final names = await _dbHelper.getSavedNames();
    if (mounted) {
      setState(() {
        _savedNames = names;
      });
    }
  }

  Future<void> _addNameDialog(List<TextEditingController> controllers, int index) async {
    final s = AppStrings.of(context);
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('addName') ?? 'Add Name'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: s.t('name')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(s.t('save'))),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _dbHelper.insertSavedName(result);
      await _loadSavedNames();
      if (mounted) {
        setState(() {
          controllers[index].text = result;
        });
        _triggerAutoSave();
      }
    }
  }

  Future<void> _manageNamesDialog() async {
    final s = AppStrings.of(context);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.people_outline, color: Colors.blueGrey),
              const SizedBox(width: 10),
              Text(s.t('manageNames') ?? 'Manage Names'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _savedNames.isEmpty
                ? Center(child: Text(s.t('listEmpty') ?? 'List is empty'))
                : ListView.separated(
                    itemCount: _savedNames.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final name = _savedNames[index];
                      return ListTile(
                        title: Text(name, style: const TextStyle(fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                              onPressed: () async {
                                final controller = TextEditingController(text: name);
                                final newName = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.t('editName') ?? 'Edit Name'),
                                    content: TextField(
                                      controller: controller,
                                      decoration: InputDecoration(hintText: s.t('name')),
                                      autofocus: true,
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, controller.text.trim()),
                                        child: Text(s.t('save')),
                                      ),
                                    ],
                                  ),
                                );

                                if (newName != null && newName.isNotEmpty && newName != name) {
                                  await _dbHelper.updateSavedName(name, newName);
                                  await _loadSavedNames();
                                  setDialogState(() {});
                                  if (mounted) setState(() {});
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.t('confirmDelete') ?? 'Confirm Delete'),
                                    content: Text('${s.t('deleteConfirmMessage') ?? 'Are you sure you want to delete'} "$name"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text(s.t('delete')),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _dbHelper.deleteSavedName(name);
                                  await _loadSavedNames();
                                  setDialogState(() {});
                                  if (mounted) setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('close'))),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitialState() async {
    final line = await _dbHelper.getGlobalSetting('lastProductionLine');
    final shift = await _dbHelper.getGlobalSetting('lastProductionShift');
    final isLocked = await _dbHelper.getGlobalSetting('lastProductionLocked');
    
    debugPrint('DEBUG: Loading initial state - Line: $line, Shift: $shift, Locked: $isLocked');

    if (mounted) {
      setState(() {
        _selectedLine = (line != null && line.isNotEmpty && line != 'LIJN ?') ? line : null;
        _selectedShift = (shift != null && shift.isNotEmpty && shift != '?') ? shift : null;
        _isLocked = isLocked == 'true';
      });

      // Crucial: Clear UI state BEFORE loading
      _resetUIState();

      // Only load if we restored valid selections
      if (_selectedLine != null && _selectedShift != null) {
        _initializeOptions(); 
        if (_optionsInitialized) {
          await _loadCurrentDowntime();
          _isInitialLoadDone = true;
        }
      }
    }
  }

  void _resetUIState() {
    setState(() {
      for (final reason in _reasons) {
        _downtimeData[reason] = 0;
        _commentControllers[reason]?.clear();
        _downtimeControllers[reason]?.text = '0';
      }
      _barrelsWithWater = null;
      _camerasCleaned = null;
      _defectiveCarts = 0;
    });
  }

  void _initializeOptions() {
    if (_optionsInitialized) return;
    
    try {
      final s = AppStrings.of(context);
      _shiftOptions = [
        s.t('shiftMorning'),
        s.t('shiftAfternoon'),
        s.t('shiftNight'),
      ];
      
      _downtimeReasons = [
        s.t('drInvoerrobotVerstoord'),
        s.t('drVallendeStapels'),
        s.t('drOntnesterVerstoord'),
        s.t('drWasmachineDefectAfval'),
        s.t('drKarrentransportVerstoord'),
        s.t('drStapelaarUitvoerrobotVerstoord'),
        s.t('drFormeertafelVerstoordAfval'),
        s.t('drVisionKooiVol'),
        s.t('drOverig'),
        s.t('drWaterniveau'),
        s.t('drVastgelopenFust'),
        s.t('drTransportbandVerstoord'),
        s.t('drVastloperOntnester'),
        s.t('drStapelaarVerstoordAfstelling'),
        s.t('drUitvoerrobotVerstoord'),
        s.t('drFormeertafelOmvallendeStapels'),
        s.t('drGeplandeReparatie'),
        s.t('drOngeplandeReparatie'),
        s.t('drInvoerrobotDefect'),
        s.t('drOntnesterDefect'),
        s.t('drWasmachineDefect'),
        s.t('drKarrentransportDefect'),
        s.t('drTransportbandDefect'),
        s.t('drStapelaarDefect'),
        s.t('drFormeertafelDefect'),
        s.t('drUitvoerrobotDefect'),
        s.t('drBesturingsprobleem'),
      ];

      _pollutionReasons = [
        'Input robot disturbed/refuse',
        'Falling piles through crooked inserts on the car',
        'Distributor disturbed/refuse',
        'Washing machine disturbed/refuse',
        'Cart transport disturbed/refuse',
        'Conveyor belt disturbed/refuse',
        'Stacker disturbed/refuse',
        'Forming table disturbed/refuse',
        'Output robot disturbed/refuse',
        'Control problem',
      ];

      _processReasons = [
        'Input robot disturbed',
        'Falling piles through crooked inserts on the car',
        'Distributor disturbed',
        'Washing machine disturbed',
        'Cart transport disturbed',
        'Conveyor belt disturbed',
        'Stacker disturbed',
        'Forming table disturbed',
        'Output robot disturbed',
        'Control problem',
      ];

      _technicalFaultReasons = [
        'Input robot defect',
        'Distributor defect',
        'Washing machine defect',
        'Cart transport defect',
        'Conveyor belt defect',
        'Stacker defect',
        'Forming table defect',
        'Output robot defect',
        'Control problem',
      ];

      _reasons = [
        ..._downtimeReasons,
        ..._pollutionReasons,
        ..._processReasons,
        ..._technicalFaultReasons,
      ];
      for (final reason in _reasons) {
        _downtimeData.putIfAbsent(reason, () => 0);
        _commentControllers.putIfAbsent(reason, () => TextEditingController());
        _downtimeControllers.putIfAbsent(reason, () => TextEditingController(text: '0'));
      }
      _optionsInitialized = true;
    } catch (e) {
      debugPrint('Strings not ready yet: $e');
    }
  }

  @override
  void dispose() {
    _causesController.dispose();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    for (final controller in _downtimeControllers.values) {
      controller.dispose();
    }
    for (final controller in _operatorControllers) {
      controller.dispose();
    }
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeOptions();
    
    // Initial data load when options are ready
    if (_optionsInitialized && !_isInitialLoadDone) {
      _loadCurrentDowntime();
      _isInitialLoadDone = true;
    }
  }

  Future<void> _loadCurrentDowntime() async {
    // DO NOT load if line or shift is not selected - this prevents loading stray data
    if (_selectedLine == null || _selectedShift == null) {
      debugPrint('DEBUG: Skipping downtime load - Line or Shift not selected');
      _resetUIState();
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    debugPrint('DEBUG: Loading downtime for Date: $dateStr, Line: $_selectedLine, Shift: $_selectedShift');
    
    setState(() => _isLoading = true);

    try {
      final operatorNames = _operatorControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .join(', ');
      final currentOp = operatorNames.isNotEmpty ? operatorNames : widget.currentUsername;

      final existing = await _dbHelper.getProductionDowntime(
        dateStr,
        operatorName: currentOp,
        lineName: _selectedLine,
        shift: _selectedShift,
        last8Hours: true, 
      );

      // Fetch photos before setState
      final reports = await _dbHelper.getFailureReports();
      final Map<String, List<Map<String, dynamic>>> fetchedPhotos = {};
      for (final reason in _reasons) {
        final syncIdPrefix = 'PL-${_selectedLine}-${dateStr}-${reason}-${_selectedShift}';
        final reasonReports = reports.where((r) => r['unique_id']?.toString().startsWith(syncIdPrefix) ?? false).toList();
        
        fetchedPhotos[reason] = reasonReports
            .where((r) => r['zdjecie_blob'] != null)
            .map((r) => {
              'id': r['id'],
              'bytes': r['zdjecie_blob'] as Uint8List,
              'description': r['opis'] as String? ?? '',
            })
            .toList();
      }

      if (mounted) {
        setState(() {
          // Initialize/Clear with default values first
          for (final reason in _reasons) {
            _downtimeData[reason] = 0;
            _commentControllers[reason]?.clear();
            _downtimeControllers[reason]?.text = '0';
            _reasonPhotos[reason] = fetchedPhotos[reason] ?? [];
          }
          
          _barrelsWithWater = null;
          _camerasCleaned = null;
          _defectiveCarts = 0;

          if (existing.isNotEmpty) {
            // Fill data from DB - if multiple entries for same reason exist (different lines/shifts), 
            // they will be merged or the latest will prevail in the view
            for (var entry in existing) {
              final reason = entry['reason'] as String;
              final minutes = entry['minutes'] as int;
              _downtimeData[reason] = (_downtimeData[reason] ?? 0) + minutes;
              
              if (_downtimeControllers.containsKey(reason)) {
                _downtimeControllers[reason]!.text = _downtimeData[reason].toString();
              }
              
              final comment = entry['causes'] as String? ?? '';
              if (comment.isNotEmpty && _commentControllers.containsKey(reason)) {
                _commentControllers[reason]!.text = comment;
              }
            }
            
            final first = existing.first;
            _barrelsWithWater = (first['barrels_water'] ?? 0) == 1;
            _camerasCleaned = (first['cameras_cleaned'] ?? 0) == 1;
            _defectiveCarts = (first['defective_carts'] ?? 0);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG Error loading downtime: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autoFinalizeOldSession(List<Map<String, dynamic>> oldData) async {
    // This is no longer used as the 12h window is handled by DB query
    debugPrint('DEBUG: _autoFinalizeOldSession called (legacy)');
  }

  Future<void> _addMinute(String reason) async {
    if (_isLocked) return;
    
    setState(() {
      _downtimeData[reason] = (_downtimeData[reason] ?? 0) + 1;
      _downtimeControllers[reason]?.text = _downtimeData[reason].toString();
    });
    
    // Auto-sync with Downtime Register immediately for any added minutes
    await _saveDowntimeEntry(reason, 1); 
    _triggerAutoSave();
  }

  Future<void> _removeMinute(String reason) async {
    if (_isLocked) return;
    
    final currentMinutes = _downtimeData[reason] ?? 0;
    if (currentMinutes <= 0) return;

    setState(() {
      _downtimeData[reason] = currentMinutes - 1;
      _downtimeControllers[reason]?.text = _downtimeData[reason].toString();
    });
    
    // Auto-sync with Downtime Register immediately
    await _saveDowntimeEntry(reason, -1); 
    _triggerAutoSave();
  }

  Future<void> _handleManualDowntimeChange(String reason, String value) async {
    if (_isLocked) return;
    
    final int? newVal = int.tryParse(value);
    if (newVal == null || newVal < 0) return;

    final int oldVal = _downtimeData[reason] ?? 0;
    if (newVal == oldVal) return;

    setState(() {
      _downtimeData[reason] = newVal;
    });

    // Save the difference to the database to keep registers in sync
    final diff = newVal - oldVal;
    await _saveDowntimeEntry(reason, diff);
    _triggerAutoSave();
  }

  Future<void> _updateOtherFields({bool instant = false}) async {
    if (instant) {
      await _manualSave();
    } else {
      _triggerAutoSave();
    }
  }

  Future<String> _generateFaultId() async {
    final now = DateTime.now();
    final year = now.year;
    
    // ISO week number calculation
    final dayOfYear = int.parse(DateFormat('D').format(now));
    final week = ((dayOfYear - now.weekday + 10) / 7).floor();
    
    // Get count of reports for the current year
    final reports = await _dbHelper.getFailureReports();
    final currentYearReports = reports.where((r) {
      final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '');
      return createdAt?.year == year;
    }).length;
    
    final count = currentYearReports + 1;
    final paddedCount = count.toString().padLeft(3, '0');
    
    return '$paddedCount/W$week/$year';
  }

  void _showFullImage(String currentReason) {
    // Refresh photoReasons based on CURRENT state of _reasonPhotos
    final photoReasons = _reasons.where((r) => _reasonPhotos[r]?.isNotEmpty ?? false).toList();
    
    if (photoReasons.isEmpty) {
      // If we don't have photos in memory, it might be a reason we just added a photo to
      // but state wasn't updated correctly. We check currentReason specifically.
      if (_reasonPhotos[currentReason]?.isNotEmpty ?? false) {
        photoReasons.add(currentReason);
      } else {
        return;
      }
    }

    int currentReasonIndex = photoReasons.indexOf(currentReason);
    if (currentReasonIndex == -1) currentReasonIndex = 0;
    
    // Tracking current photo within the current reason
    int currentPhotoIndex = 0;
    
    // Position and Scale for the comment frame
    Offset commentOffset = const Offset(20, 100); // Initial bottom-left-ish
    double commentScale = 1.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentReasonStr = photoReasons[currentReasonIndex];
          // Ensure we have the latest list from the parent state
          final photos = _reasonPhotos[currentReasonStr] ?? [];
          
          if (photos.isEmpty) {
            return Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("No photos available for this reason."),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Safety check for index
           if (currentPhotoIndex >= photos.length) {
             currentPhotoIndex = photos.length - 1;
           }
           if (currentPhotoIndex < 0) currentPhotoIndex = 0;

           final s = AppStrings.of(context);

           return Dialog(
             backgroundColor: Colors.black.withOpacity(0.9),
             insetPadding: EdgeInsets.zero,
             child: Stack(
               children: [
                 // Image Viewer
                 Center(
                   child: InteractiveViewer(
                     key: ValueKey('${currentReasonStr}_${currentPhotoIndex}'),
                     child: Image.memory(
                       photos[currentPhotoIndex]['bytes'],
                       fit: BoxFit.contain,
                     ),
                   ),
                 ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.black45,
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentReasonStr,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Photo ${currentPhotoIndex + 1} of ${photos.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // Delete current photo button
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 30),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Photo'),
                                      content: const Text('Are you sure you want to delete this photo?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true), 
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    final photoId = photos[currentPhotoIndex]['id'];
                                    if (photoId != null) {
                                      await _dbHelper.deleteFailureReport(photoId);
                                    }

                                    setState(() {
                                      _reasonPhotos[currentReasonStr]!.removeAt(currentPhotoIndex);
                                      if (_reasonPhotos[currentReasonStr]!.isEmpty) {
                                        _reasonPhotos.remove(currentReasonStr);
                                      }
                                    });
                                    
                                    if (_reasonPhotos[currentReasonStr] == null) {
                                      Navigator.pop(context);
                                    } else {
                                      setDialogState(() {
                                        if (currentPhotoIndex >= _reasonPhotos[currentReasonStr]!.length) {
                                          currentPhotoIndex = _reasonPhotos[currentReasonStr]!.length - 1;
                                        }
                                      });
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Description Overlay with Drag and Resize
                if (_activeCategory != 'TechnicalFaults' && (photos[currentPhotoIndex]['description']?.isNotEmpty ?? false))
                  Positioned(
                    left: commentOffset.dx,
                    bottom: commentOffset.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setDialogState(() {
                          commentOffset += Offset(details.delta.dx, -details.delta.dy);
                          // Basic screen bounds check
                          if (commentOffset.dy < 20) commentOffset = Offset(commentOffset.dx, 20);
                          if (commentOffset.dx < 0) commentOffset = Offset(0, commentOffset.dy);
                        });
                      },
                      child: Transform.scale(
                        scale: commentScale,
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          width: 280, // Base width
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.yellow.shade600, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.comment_outlined, color: Colors.yellow.shade600, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        s.t('comments').toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.yellow.shade600,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Drag indicator icon
                                  Icon(Icons.drag_indicator, color: Colors.white.withOpacity(0.3), size: 16),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                photos[currentPhotoIndex]['description'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                // Resize Slider Overlay
                if (_activeCategory != 'TechnicalFaults' && (photos[currentPhotoIndex]['description']?.isNotEmpty ?? false))
                  Positioned(
                    right: 20,
                    bottom: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in, color: Colors.yellow, size: 20),
                        SizedBox(
                          height: 150,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: commentScale,
                              min: 0.5,
                              max: 2.0,
                              activeColor: Colors.yellow.shade600,
                              inactiveColor: Colors.white24,
                              onChanged: (v) => setDialogState(() => commentScale = v),
                            ),
                          ),
                        ),
                        const Icon(Icons.zoom_out, color: Colors.yellow, size: 20),
                      ],
                    ),
                  ),

                // navigation for multiple photos within same reason
                if (photos.length > 1)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 40),
                          onPressed: () {
                            setDialogState(() {
                              currentPhotoIndex = (currentPhotoIndex - 1 + photos.length) % photos.length;
                            });
                          },
                        ),
                        const SizedBox(width: 40),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
                          onPressed: () {
                            setDialogState(() {
                              currentPhotoIndex = (currentPhotoIndex + 1) % photos.length;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // Navigation between reasons
                if (photoReasons.length > 1)
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Button
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 30),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              currentReasonIndex = (currentReasonIndex - 1 + photoReasons.length) % photoReasons.length;
                              currentPhotoIndex = 0; // Reset photo index when changing reason
                            });
                          },
                        ),
                        // Right Button
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 30),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              currentReasonIndex = (currentReasonIndex + 1) % photoReasons.length;
                              currentPhotoIndex = 0; // Reset photo index when changing reason
                            });
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _triggerAutoSave() {
    _autoSaveTimer?.cancel();
    setState(() {
      _saveStatus = 'saving';
    });
    _autoSaveTimer = Timer(const Duration(seconds: 1), () async {
      if (mounted) {
        await _manualSave();
      }
    });
  }

  Future<void> _pickImageAndOpenReport(String reason, {ImageSource source = ImageSource.camera}) async {
    // Limit to 5 photos per reason
    final currentPhotos = _reasonPhotos[reason] ?? [];
    if (currentPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maksymalna liczba zdjęć (5) została osiągnięta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (mounted) {
        // Open editor before report
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageEditorScreen(
              imageBytes: bytes,
              initialDescription: reason,
              showDescription: _activeCategory != 'TechnicalFaults',
            ),
          ),
        );
        
        if (result != null && result is Map && mounted) {
          final editedBytes = result['image'] as Uint8List;
          final description = result['description'] as String;

          setState(() {
            final photoData = {
              'bytes': editedBytes,
              'description': description,
            };
            if (_reasonPhotos[reason] == null) {
              _reasonPhotos[reason] = [photoData];
            } else {
              _reasonPhotos[reason]!.add(photoData);
            }
          });
          
          // Show feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo added to "$reason". Total: ${_reasonPhotos[reason]!.length}'),
              duration: const Duration(seconds: 2),
            ),
          );

          if (_activeCategory == 'TechnicalFaults') {
            _showDetailedFaultReportDialog(reason, editedBytes);
          } else {
            // Just save photo without adding minutes
            await _savePhotoOnly(reason, editedBytes, description: description);
          }
        }
      }
    }
  }

  Future<void> _savePhotoOnly(String reason, Uint8List photoBytes, {String? description}) async {
    // Save to DB with photo but NO minute addition
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final minutes = _downtimeData[reason] ?? 0;

    // Use a unique ID for each photo so they don't overwrite each other
    final photoSyncId = 'PL-${_selectedLine}-${dateStr}-${reason}-${_selectedShift}-${DateTime.now().millisecondsSinceEpoch}';

    // Sync to failure register with current minutes and new photo
    await _syncToFailureRegister(reason, minutes, dateStr, photoBytes: photoBytes, description: description, overrideSyncId: photoSyncId);
    
    // Refresh local photos list from DB to ensure count is correct
    final reports = await _dbHelper.getFailureReports();
    final syncIdPrefix = 'PL-${_selectedLine}-${dateStr}-${reason}-${_selectedShift}';
    final reasonReports = reports.where((r) => r['unique_id']?.toString().startsWith(syncIdPrefix) ?? false).toList();
    
    final newPhotos = reasonReports
        .where((r) => r['zdjecie_blob'] != null)
        .map((r) => {
          'id': r['id'],
          'bytes': r['zdjecie_blob'] as Uint8List,
          'description': r['opis'] as String? ?? '',
        })
        .toList();

    // Also update production_downtime entry to persist the fact that we have data
    await _saveDowntimeEntry(reason, minutes);
    
    if (mounted) {
      setState(() {
        _reasonPhotos[reason] = newPhotos;
      });
      _triggerAutoSave();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo saved successfully'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _showDetailedFaultReportDialog(String reason, Uint8List photoBytes) async {
    final s = AppStrings.of(context);
    final faultId = await _generateFaultId();
    final now = DateTime.now();
    
    // Custom options lists
    List<String> locations = await _dbHelper.getFaultOptions('location');
    List<String> priorities = await _dbHelper.getFaultOptions('priority');
    List<String> rootCauses = await _dbHelper.getFaultOptions('root_cause');
    List<String> repairedByOptions = await _dbHelper.getFaultOptions('repaired_by');

    // Controllers for editable fields
    final descController = TextEditingController();
    final reporterController = TextEditingController(text: widget.currentUsername);
    
    String? selectedLocation;
    String? selectedPriority;
    String? selectedRootCause;
    String? selectedRepairedBy;
    bool isFixed = false;
    
    DateTime regDate = now;
    TimeOfDay regTime = TimeOfDay.now();
    DateTime startDate = now;
    DateTime endDate = now;
    
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Calculate downtime
          int calculateDowntime() {
            if (!isFixed) return 0;
            final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
            final end = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute);
            final diff = end.difference(start).inMinutes;
            return diff > 0 ? diff : 0;
          }

          final downtime = calculateDowntime();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 16,
            child: Container(
              width: 650,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade800, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.report_problem_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FAULT REPORT'.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                faultId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Auto-generated info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final DateTime? d = await _showModernDatePicker(regDate, Colors.blue.shade700);
                                      if (d != null) {
                                        final TimeOfDay? t = await _showModernTimePicker(regTime, Colors.blue.shade700);
                                        if (t != null) {
                                          setDialogState(() {
                                            regDate = d;
                                            regTime = t;
                                          });
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildInfoItem(
                                      'REGISTRATION DATE', 
                                      '${DateFormat('yyyy-MM-dd').format(regDate)} ${regTime.hour.toString().padLeft(2, '0')}:${regTime.minute.toString().padLeft(2, '0')}', 
                                      Icons.calendar_today_outlined
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 30, color: Colors.grey.shade300),
                                Expanded(child: _buildInfoItem('LINE', _selectedLine ?? '-', Icons.settings_input_component_outlined)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Description
                          _buildModernTextField(
                            controller: descController,
                            label: 'DESCRIPTION OF THE FAULT',
                            icon: Icons.description_outlined,
                            color: Colors.blue.shade700,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          
                          // Location Dropdown
                          _buildModernDropdown(
                            label: 'LOCATION',
                            value: selectedLocation,
                            items: locations,
                            icon: Icons.location_on_outlined,
                            onChanged: (v) => setDialogState(() => selectedLocation = v),
                            onAddNew: () async {
                              final newLoc = await _showAddNewOptionDialog('LOCATION');
                              if (newLoc != null && newLoc.isNotEmpty) {
                                await _dbHelper.insertFaultOption('location', newLoc);
                                final updated = await _dbHelper.getFaultOptions('location');
                                setDialogState(() {
                                  locations = updated;
                                  selectedLocation = newLoc;
                                });
                              }
                            },
                            onDelete: (val) async {
                              final confirm = await _showDeleteOptionConfirmation('LOCATION', val);
                              if (confirm == true) {
                                await _dbHelper.deleteFaultOption('location', val);
                                final updated = await _dbHelper.getFaultOptions('location');
                                setDialogState(() {
                                  locations = updated;
                                  if (selectedLocation == val) selectedLocation = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Root Cause
                          _buildModernDropdown(
                            label: 'ROOT CAUSE',
                            value: selectedRootCause,
                            items: rootCauses,
                            icon: Icons.help_outline_rounded,
                            onChanged: (v) => setDialogState(() => selectedRootCause = v),
                            onAddNew: () async {
                              final newCause = await _showAddNewOptionDialog('ROOT CAUSE');
                              if (newCause != null && newCause.isNotEmpty) {
                                await _dbHelper.insertFaultOption('root_cause', newCause);
                                final updated = await _dbHelper.getFaultOptions('root_cause');
                                setDialogState(() {
                                  rootCauses = updated;
                                  selectedRootCause = newCause;
                                });
                              }
                            },
                            onDelete: (val) async {
                              final confirm = await _showDeleteOptionConfirmation('ROOT CAUSE', val);
                              if (confirm == true) {
                                await _dbHelper.deleteFaultOption('root_cause', val);
                                final updated = await _dbHelper.getFaultOptions('root_cause');
                                setDialogState(() {
                                  rootCauses = updated;
                                  if (selectedRootCause == val) selectedRootCause = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Priority & Reporter
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernDropdown(
                                  label: 'PRIORITY',
                                  value: selectedPriority,
                                  items: priorities,
                                  icon: Icons.priority_high_rounded,
                                  onChanged: (v) => setDialogState(() => selectedPriority = v),
                                  color: _getPriorityColor(selectedPriority),
                                  onAddNew: () async {
                                    final newPri = await _showAddNewOptionDialog('PRIORITY');
                                    if (newPri != null && newPri.isNotEmpty) {
                                      await _dbHelper.insertFaultOption('priority', newPri);
                                      final updated = await _dbHelper.getFaultOptions('priority');
                                      setDialogState(() {
                                        priorities = updated;
                                        selectedPriority = newPri;
                                      });
                                    }
                                  },
                                  onDelete: (val) async {
                                    final confirm = await _showDeleteOptionConfirmation('PRIORITY', val);
                                    if (confirm == true) {
                                      await _dbHelper.deleteFaultOption('priority', val);
                                      final updated = await _dbHelper.getFaultOptions('priority');
                                      setDialogState(() {
                                        priorities = updated;
                                        if (selectedPriority == val) selectedPriority = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildModernTextField(
                                  controller: reporterController,
                                  label: 'REPORTING PERSON',
                                  icon: Icons.person_outline_rounded,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Status Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isFixed ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isFixed ? Colors.green.shade100 : Colors.red.shade100),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CURRENT STATUS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: isFixed ? Colors.green : Colors.red,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: (isFixed ? Colors.green : Colors.red).withOpacity(0.3),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          isFixed ? 'CLOSED' : 'OPEN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isFixed ? Colors.green.shade700 : Colors.red.shade700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      isFixed ? 'MARK AS OPEN' : 'MARK AS CLOSED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Transform.scale(
                                      scale: 0.85,
                                      child: Switch(
                                        value: isFixed,
                                        activeColor: Colors.green,
                                        onChanged: (v) => setDialogState(() => isFixed = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Repair info Section (Only visible when status is CLOSED)
                          if (isFixed) ...[
                            Row(
                              children: [
                                Text(
                                  'REPAIR DETAILS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildModernDateTimePicker(
                                    label: 'REPAIR START',
                                    date: startDate,
                                    time: startTime,
                                    color: Colors.blue.shade600,
                                    icon: Icons.play_arrow_rounded,
                                    onTap: () async {
                                      final DateTime? d = await _showModernDatePicker(startDate, Colors.blue);
                                      if (d != null) {
                                        final TimeOfDay? t = await _showModernTimePicker(startTime, Colors.blue);
                                        if (t != null) {
                                          setDialogState(() {
                                            startDate = d;
                                            startTime = t;
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildModernDateTimePicker(
                                    label: 'REPAIR END',
                                    date: endDate,
                                    time: endTime,
                                    color: Colors.green.shade600,
                                    icon: Icons.check_circle_outline_rounded,
                                    onTap: () async {
                                      final DateTime? d = await _showModernDatePicker(endDate, Colors.green);
                                      if (d != null) {
                                        final TimeOfDay? t = await _showModernTimePicker(endTime, Colors.green);
                                        if (t != null) {
                                          setDialogState(() {
                                            endDate = d;
                                            endTime = t;
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            _buildModernDropdown(
                              label: 'REPAIRED BY',
                              value: selectedRepairedBy,
                              items: repairedByOptions,
                              icon: Icons.engineering_outlined,
                              onChanged: (v) => setDialogState(() => selectedRepairedBy = v),
                              color: Colors.blueGrey.shade700,
                              onAddNew: () async {
                                final newRepairer = await _showAddNewOptionDialog('REPAIRED BY');
                                if (newRepairer != null && newRepairer.isNotEmpty) {
                                  await _dbHelper.insertFaultOption('repaired_by', newRepairer);
                                  final updated = await _dbHelper.getFaultOptions('repaired_by');
                                  setDialogState(() {
                                    repairedByOptions = updated;
                                    selectedRepairedBy = newRepairer;
                                  });
                                }
                              },
                              onDelete: (val) async {
                                final confirm = await _showDeleteOptionConfirmation('REPAIRED BY', val);
                                if (confirm == true) {
                                  await _dbHelper.deleteFaultOption('repaired_by', val);
                                  final updated = await _dbHelper.getFaultOptions('repaired_by');
                                  setDialogState(() {
                                    repairedByOptions = updated;
                                    if (selectedRepairedBy == val) selectedRepairedBy = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // Total Downtime Footer
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined, color: Colors.blue.shade700, size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      'TOTAL DOWNTIME',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$downtime min',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(s.t('cancel'), style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 20),
                          onPressed: () async {
                            if (descController.text.isEmpty || selectedLocation == null || selectedPriority == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Description, Location and Priority are required'), backgroundColor: Colors.red),
                              );
                              return;
                            }
                            // Save to failure_reports
                            final reportData = {
                              'unique_id': faultId,
                              'opis': descController.text,
                              'lokalizacja': selectedLocation,
                              'linia': _selectedLine ?? '-',
                              'powod': selectedRootCause ?? '',
                              'priorytet': selectedPriority ?? 'Medium',
                              'status': isFixed ? 'CLOSED' : 'OPEN',
                              'czy_rozwiazane': isFixed ? 1 : 0,
                              'data_rozpoczecia_naprawy': '${DateFormat('yyyy-MM-dd').format(startDate)} ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                              'data_zakonczenia_naprawy': isFixed ? '${DateFormat('yyyy-MM-dd').format(endDate)} ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}' : null,
                              'downtime_minutes': downtime,
                              'created_by': reporterController.text,
                              'kto_naprawil': selectedRepairedBy ?? '',
                              'zdjecie_blob': photoBytes,
                              'created_at': DateTime(regDate.year, regDate.month, regDate.day, regTime.hour, regTime.minute).toIso8601String(),
                            };
                            
                            final failureId = await _dbHelper.insertFailureReport(reportData);
                            
                            // Refresh local photos to get the one we just added with its ID
                            final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
                            final reports = await _dbHelper.getFailureReports();
                            final syncIdPrefix = 'PL-${_selectedLine}-${dateStr}-${reason}-${_selectedShift}';
                            final reasonReports = reports.where((r) => r['unique_id']?.toString().startsWith(syncIdPrefix) ?? false).toList();
                            
                            final newPhotos = reasonReports
                                .where((r) => r['zdjecie_blob'] != null)
                                .map((r) => {
                                  'id': r['id'],
                                  'bytes': r['zdjecie_blob'] as Uint8List,
                                  'description': r['opis'] as String? ?? '',
                                })
                                .toList();

                            // Also insert a task for this failure
                            await _dbHelper.insertTask({
                              'title': _selectedLine ?? '-',
                              'status': isFixed ? 'Zrealizowane' : 'W toku',
                              'type': 'Technical Fault: ${descController.text}',
                              'priority': selectedPriority,
                              'date_start': startDate.toIso8601String(),
                              'label': reporterController.text,
                              'created_at': now.toIso8601String(),
                              'created_by': widget.currentUsername,
                              'failure_id': failureId,
                            });

                            // Update the local state for the production list
                            if (downtime > 0) {
                              await _saveDowntimeEntry(reason, downtime, absoluteMinutes: (_downtimeData[reason] ?? 0) + downtime);
                              if (mounted) {
                                setState(() {
                                  _downtimeData[reason] = (_downtimeData[reason] ?? 0) + downtime;
                                  _downtimeControllers[reason]?.text = _downtimeData[reason].toString();
                                  _reasonPhotos[reason] = newPhotos;
                                });
                              }
                            } else {
                              if (mounted) {
                                setState(() {
                                  _reasonPhotos[reason] = newPhotos;
                                });
                              }
                            }
                            
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: Colors.blue.withOpacity(0.5),
                          ),
                          label: Text(s.t('save').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Modern UI Helper Methods
  Widget _buildModernDateTimePicker({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${DateFormat('yyyy-MM-dd').format(date)} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    Color? color,
    VoidCallback? onAddNew,
    Function(String)? onDelete,
  }) {
    final effectiveColor = color ?? Colors.blue.shade700;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (onAddNew != null)
                InkWell(
                  onTap: onAddNew,
                  child: Icon(Icons.add_circle_outline_rounded, size: 18, color: effectiveColor),
                ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              hint: Text('SELECT $label', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
              items: items.map((l) => DropdownMenuItem(
                value: l, 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: () => onDelete(l),
                        child: Icon(Icons.remove_circle_outline, color: Colors.red.shade300, size: 18),
                      ),
                  ],
                )
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String? priority) {
    if (priority == null) return Colors.blue.shade600;
    switch (priority.toLowerCase()) {
      case 'low': return Colors.green.shade600;
      case 'medium': return Colors.blue.shade600;
      case 'high': return Colors.orange.shade700;
      case 'critical': return Colors.red.shade700;
      default: return Colors.blue.shade600;
    }
  }

  Future<String?> _showAddNewOptionDialog(String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ADD NEW $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter new $label name...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteOptionConfirmation(String label, String value) async {
    final s = AppStrings.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('confirmDelete').toUpperCase()),
        content: Text('${s.t('deleteElementConfirm')} ("$value")'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('cancel').toUpperCase()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(s.t('delete').toUpperCase()),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _showModernDatePicker(DateTime initialDate, Color primaryColor) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<TimeOfDay?> _showModernTimePicker(TimeOfDay initialTime, Color primaryColor) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onSurface: Colors.black87,
            ),
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              hourMinuteColor: primaryColor.withOpacity(0.05),
              hourMinuteTextColor: Colors.black87,
              hourMinuteTextStyle: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(0),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
  }

  Future<void> _manualSave({bool force = false, bool isFinalizing = false}) async {
    if (_isLocked) return;
    
    // Check if we are already saving to prevent concurrent writes, unless forced
    if (_isSaving && !force) return;

    _autoSaveTimer?.cancel();
    if (mounted) {
      setState(() {
        _isSaving = true;
        _saveStatus = 'saving';
      });
    }
    
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      final operatorNames = _operatorControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .join(', ');
      final finalOperatorName = operatorNames.isNotEmpty ? operatorNames : widget.currentUsername;

      // We always save under the CURRENTLY SELECTED line and shift
      // If none selected, we use default placeholders
      final line = _selectedLine ?? 'LIJN ?';
      final shift = _selectedShift ?? '?';
      
      final List<Map<String, dynamic>> entries = [];
      final Map<String, dynamic> reportData = {
        'operator_name': finalOperatorName,
        'date': dateStr,
        'line_name': line,
        'shift': shift,
        'barrels_water': _barrelsWithWater ?? false,
        'cameras_cleaned': _camerasCleaned ?? false,
        'defective_carts': _defectiveCarts,
        'downtime_entries': {},
      };
      
      for (final reason in _reasons) {
        final minutes = _downtimeData[reason] ?? 0;
        final comment = _commentControllers[reason]?.text ?? '';
        
        if (minutes > 0 || comment.isNotEmpty) {
          entries.add({
            'line_name': line,
            'operator_name': finalOperatorName,
            'date': dateStr,
            'reason': reason,
            'minutes': minutes,
            'shift': shift,
            'barrels_water': _barrelsWithWater == true ? 1 : 0,
            'cameras_cleaned': _camerasCleaned == true ? 1 : 0,
            'defective_carts': _defectiveCarts,
            'causes': comment,
            'created_at': now.toIso8601String(),
          });
          
          (reportData['downtime_entries'] as Map)[reason] = {
            'minutes': minutes,
            'comment': comment,
          };
        }
      }

      if (entries.isNotEmpty) {
        await _dbHelper.batchInsertOrUpdateProductionDowntime(entries);
        
        // SYNC: Generate reports for all entries with minutes > 0
        for (final reason in _reasons) {
          final minutes = _downtimeData[reason] ?? 0;
          if (minutes > 0) {
            await _syncToFailureRegister(reason, minutes, dateStr);
          }
        }
      }

      // If finalizing, save to finalized_production_lists and clear active table
      if (isFinalizing) {
        await _dbHelper.insertFinalizedProductionList({
          'operator_name': finalOperatorName,
          'date': dateStr,
          'line_name': line,
          'shift': shift,
          'report_data': jsonEncode(reportData),
          'created_at': now.toIso8601String(),
        });
        
        // Clear persistent downtime entries from the active table after finalization
        // 1. Clear the specific session
        await _dbHelper.clearActiveProductionDowntime(
          dateStr, 
          line, 
          shift,
          finalOperatorName
        );
        
        // 2. Also clear any "stray" entries for this operator/date that might have default values
        // This ensures no old data "leaks" back into the next session
        if (line != 'LIJN ?') {
          await _dbHelper.clearActiveProductionDowntime(dateStr, 'LIJN ?', '?', finalOperatorName);
        }
      }
      
      if (mounted) {
        if (isFinalizing) {
          // Clear persistent settings outside setState
          await _dbHelper.saveGlobalSetting('lastProductionLine', '');
          await _dbHelper.saveGlobalSetting('lastProductionShift', '');
        }

        setState(() {
          _lastSaveTime = DateTime.now();
          _saveStatus = 'saved';
          
          if (isFinalizing) {
              // Pełne czyszczenie UI
              _resetUIState();
              
              for (var controller in _operatorControllers) {
                controller.clear();
                if (_operatorControllers.indexOf(controller) > 0) {
                  controller.dispose();
                }
              }
              if (_operatorControllers.length > 1) {
                _operatorControllers.removeRange(1, _operatorControllers.length);
              }
              
              _selectedLine = null;
              _selectedShift = null;
              _selectedDate = DateTime.now();
              _step = 0;
              _activeCategory = 'Pollution'; 
            
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppStrings.of(context).t('reportFinalized') ?? 'Raport sfinalizowany i zapisany w dokumentach.'),
                  backgroundColor: Colors.green,
                ),
              );

              if (!widget.isEmbedded) {
                Navigator.pop(context);
              }
            }
        });
      }
    } catch (e) {
      debugPrint('Manual save error: $e');
      if (mounted) setState(() => _saveStatus = 'error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    
    // Reset status after a while
    Timer(const Duration(seconds: 3), () {
      if (mounted && _saveStatus == 'saved') {
        setState(() => _saveStatus = '');
      }
    });
  }

  Future<void> _saveDowntimeEntry(String reason, int minutesToADD, {int? absoluteMinutes}) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      final operatorNames = _operatorControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .join(', ');

      final Map<String, dynamic> data = {
        'line_name': _selectedLine ?? 'LIJN ?',
        'operator_name': operatorNames.isNotEmpty ? operatorNames : widget.currentUsername,
        'date': dateStr,
        'reason': reason,
        'minutes': minutesToADD, 
        'shift': _selectedShift ?? '?',
        'barrels_water': _barrelsWithWater == true ? 1 : 0,
        'cameras_cleaned': _camerasCleaned == true ? 1 : 0,
        'defective_carts': _defectiveCarts,
        'causes': _commentControllers[reason]?.text ?? '',
        'created_at': now.toIso8601String(),
      };

      if (absoluteMinutes != null) {
        data['absolute_minutes'] = absoluteMinutes;
      }
      
      await _dbHelper.insertOrUpdateProductionDowntime(data);

      // Integrate with Downtime Register (failure_reports)
      final totalMinutesForReason = _downtimeData[reason] ?? 0;
      if (totalMinutesForReason > 0) {
        await _syncToFailureRegister(reason, totalMinutesForReason, dateStr);
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  Future<void> _syncToFailureRegister(String reason, int totalMinutes, String dateStr, {Uint8List? photoBytes, String? description, String? overrideSyncId}) async {
    // Generate a unique ID for this downtime event to prevent duplicates
    // Pattern: PL-[Line]-[Date]-[Reason]-[Shift]
    final syncId = overrideSyncId ?? 'PL-${_selectedLine}-${dateStr}-${reason}-${_selectedShift}';
    
    debugPrint('DEBUG: Syncing to Failure Register. SyncID: $syncId, Total Minutes: $totalMinutes');

    try {
      // Check if this report already exists in failure_reports
      final reports = await _dbHelper.getFailureReports();
      final existing = reports.cast<Map<String, dynamic>>().firstWhere(
        (r) => r['unique_id'] == syncId,
        orElse: () => {},
      );

      final Map<String, dynamic> updateData = {
        'downtime_minutes': totalMinutes,
        'opis': description ?? 'Storing List Downtime: $reason',
        'status': 'ZAMKNIĘTY',
        'czy_rozwiazane': 1,
      };

      if (photoBytes != null) {
        updateData['zdjecie_blob'] = photoBytes;
      }

      if (existing.isNotEmpty) {
        debugPrint('DEBUG: Updating existing failure report ID: ${existing['id']}');
        // Update existing record's downtime to match current total
        final failureId = existing['id'] as int;
        await _dbHelper.updateFailureReport(failureId, updateData);

        // Also update corresponding task
        await _dbHelper.updateTaskByFailureId(failureId, {
          'title': _selectedLine ?? '-',
          'status': 'Zrealizowane',
          'type': 'Storing List Downtime: $reason',
        });
      } else {
        debugPrint('DEBUG: Creating new failure report');
        // Create new failure report
        final Map<String, dynamic> insertData = {
          'unique_id': syncId,
          'opis': description ?? 'Storing List Downtime: $reason',
          'lokalizacja': _selectedLine,
          'linia': _selectedLine,
          'powod': reason,
          'priorytet': 'Medium',
          'czy_rozwiazane': 1,
          'status': 'ZAMKNIĘTY',
          'downtime_minutes': totalMinutes,
          'created_by': widget.currentUsername,
          'created_at': DateTime.now().toIso8601String(),
          'kto_naprawil': widget.currentUsername,
        };

        if (photoBytes != null) {
          insertData['zdjecie_blob'] = photoBytes;
        }

        final failureId = await _dbHelper.insertFailureReport(insertData);

        // Also add to Tasks table
        await _dbHelper.insertTask({
          'title': _selectedLine ?? '-',
          'status': 'Zrealizowane',
          'type': 'Storing List Downtime: $reason',
          'priority': 'Medium',
          'date_start': DateTime.now().toIso8601String(),
          'label': widget.currentUsername,
          'created_at': DateTime.now().toIso8601String(),
          'created_by': widget.currentUsername,
          'failure_id': failureId,
        });
      }
    } catch (e) {
      debugPrint('DEBUG Sync Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    if (_showHistory) {
      return _buildHistoryView(s);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        // We always allow pop now, but ensure data is saved
        
        // If we are popping, cancel timer and flush save
        if (_autoSaveTimer?.isActive ?? false) {
          _autoSaveTimer?.cancel();
          await _manualSave();
        }
      },
      child: _buildProductionListView(s),
    );
  }

  Widget _buildProductionListView(AppStrings s) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    Widget body = AbsorbPointer(
      absorbing: _isLocked,
      child: SingleChildScrollView(
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
              // 1. Unified Header (Operator, Date, Selections)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Column 1: Operator, Date and Checklist
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Operator Selection
                              Row(
                                children: [
                                  Text(s.t('operator').toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _operatorControllers.add(TextEditingController());
                                      });
                                      _triggerAutoSave();
                                    },
                                    icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.blue),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Add another operator',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _addNameDialog(_operatorControllers, _operatorControllers.length - 1),
                                    icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.orange, size: 22),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Add new name to database',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _manageNamesDialog,
                                    icon: const Icon(Icons.info_outline, color: Colors.blueGrey, size: 22),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Manage names list',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._operatorControllers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final controller = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    s.t('operator').toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey.shade500,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Autocomplete<String>(
                                                key: ValueKey('autocomplete_operator_${index}_${_savedNames.length}'),
                                                initialValue: TextEditingValue(text: controller.text),
                                                optionsBuilder: (TextEditingValue textEditingValue) {
                                                  if (textEditingValue.text.isEmpty) {
                                                    return _savedNames;
                                                  }
                                                  return _savedNames.where((String option) {
                                                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                                  });
                                                },
                                                onSelected: (String selection) {
                                                  controller.text = selection;
                                                  _triggerAutoSave();
                                                },
                                                fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                                                  if (textController.text != controller.text) {
                                                    textController.text = controller.text;
                                                  }
                                                  return TextField(
                                                    controller: textController,
                                                    focusNode: focusNode,
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                    decoration: const InputDecoration(
                                                      isDense: true,
                                                      contentPadding: EdgeInsets.zero,
                                                      border: InputBorder.none,
                                                    ),
                                                    onChanged: (v) {
                                                      controller.text = v;
                                                      _triggerAutoSave();
                                                    },
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (index > 0)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text(s.t('confirmDelete').toUpperCase()),
                                                content: Text(s.t('deleteElementConfirm')),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: Text(s.t('cancel').toUpperCase()),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red.shade700,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                    child: Text(s.t('delete').toUpperCase()),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              setState(() {
                                                _operatorControllers[index].dispose();
                                                _operatorControllers.removeAt(index);
                                                _triggerAutoSave();
                                              });
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              
                              const SizedBox(height: 24),
                              
                              // Date Selection
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null && picked != _selectedDate) {
                                    setState(() => _selectedDate = picked);
                                    _loadCurrentDowntime();
                                  }
                                },
                                child: Container(
                                  width: 180,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 6),
                                          Text(
                                            s.t('date').toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade500,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),

                              // Checklist Row (Now under Date)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.t('iceWater').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                      const SizedBox(height: 8),
                                      ToggleButtons(
                                        isSelected: [_barrelsWithWater == true, _barrelsWithWater == false],
                                        onPressed: (index) {
                                          setState(() => _barrelsWithWater = index == 0);
                                          _updateOtherFields(instant: true);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        constraints: const BoxConstraints(minHeight: 36, minWidth: 60),
                                        selectedColor: Colors.black,
                                        fillColor: Colors.grey.shade200,
                                        children: [
                                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(s.t('yes'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(s.t('no'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 32),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.t('camerasCleaned').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                      const SizedBox(height: 8),
                                      ToggleButtons(
                                        isSelected: [_camerasCleaned == true, _camerasCleaned == false],
                                        onPressed: (index) {
                                          setState(() => _camerasCleaned = index == 0);
                                          _updateOtherFields(instant: true);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        constraints: const BoxConstraints(minHeight: 36, minWidth: 60),
                                        selectedColor: Colors.black,
                                        fillColor: Colors.grey.shade200,
                                        children: [
                                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(s.t('yes'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(s.t('no'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 48),
                        
                        // Column 2: Line and Shift
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Spacer to align Production Line with Date
                              // Height of Operator section (~78) + its bottom spacer (24)
                              const SizedBox(height: 102),

                              // Line Selection
                              Text(s.t('lineName').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              ToggleButtons(
                                isSelected: _lineOptions.map((l) => _selectedLine == l).toList(),
                                onPressed: (index) async {
                                  final line = _lineOptions[index];
                                  final newLine = _selectedLine == line ? null : line;
                                  setState(() => _selectedLine = newLine);
                                  _dbHelper.saveGlobalSetting('lastProductionLine', _selectedLine ?? '');
                                  await _manualSave(force: true);
                                },
                                borderRadius: BorderRadius.circular(8),
                                constraints: const BoxConstraints(minHeight: 36, minWidth: 60),
                                selectedColor: Colors.black,
                                fillColor: Colors.grey.shade300,
                                children: _lineOptions.map((l) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(l.replaceAll('LIJN ', ''), style: const TextStyle(fontWeight: FontWeight.bold)),
                                )).toList(),
                              ),
                              
                              // Spacer to align Shift with Checklist
                              // Matches the height of Date section (~60) + its bottom spacer (24)
                              // Minus Line selection height (~60)
                              const SizedBox(height: 24),

                              // Shift Selection
                              Text(s.t('shift').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              ToggleButtons(
                                isSelected: _shiftOptions.map((sh) => _selectedShift == sh).toList(),
                                onPressed: (index) async {
                                  final shift = _shiftOptions[index];
                                  final newShift = _selectedShift == shift ? null : shift;
                                  setState(() => _selectedShift = newShift);
                                  _dbHelper.saveGlobalSetting('lastProductionShift', _selectedShift ?? '');
                                  await _manualSave(force: true);
                                },
                                borderRadius: BorderRadius.circular(8),
                                constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
                                selectedColor: Colors.black,
                                fillColor: Colors.grey.shade300,
                                children: _shiftOptions.map((sh) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(sh, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 48),
                        
                        // Column 3: Total Counter
                        Padding(
                          padding: const EdgeInsets.only(top: 40.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s.t('totalDowntimeMinutes').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                const SizedBox(height: 8),
                                Text(
                                  _downtimeData.values.fold(0, (a, b) => a + b).toString(),
                                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Category Tabs
              Container(
                color: Colors.white,
                child: Row(
                  children: [
                    _buildCategoryTab('Pollution', s.t('pollution') ?? 'Pollution'),
                    _buildCategoryTab('Process', s.t('process') ?? 'Process'),
                    _buildCategoryTab('TechnicalFaults', s.t('technicalFaults') ?? 'Technical Faults'),
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
                  0: FlexColumnWidth(2.2),
                  1: FixedColumnWidth(64),
                  2: FixedColumnWidth(50),
                  3: FlexColumnWidth(4),
                  4: FixedColumnWidth(90),
                  5: FixedColumnWidth(80),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    children: [
                      _buildHeaderCell(s.t('name')),
                      _buildHeaderCell(''),
                      _buildHeaderCell('', textAlign: TextAlign.center),
                      _buildHeaderCell(s.t('comments')),
                      _buildHeaderCell('', textAlign: TextAlign.center),
                      _buildHeaderCell(s.t('totalDowntimeMinutesShort'), textAlign: TextAlign.center),
                    ],
                  ),
                  ...(_activeCategory == 'Pollution' 
                          ? _pollutionReasons 
                          : _activeCategory == 'Process'
                              ? _processReasons
                              : _technicalFaultReasons).map((reason) {
                    final minutes = _downtimeData[reason] ?? 0;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          child: Text(reason, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _pickImageAndOpenReport(reason, source: ImageSource.camera),
                                  icon: const Icon(
                                    Icons.add_a_photo_outlined, 
                                    color: Colors.blue, 
                                    size: 20
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Take photo',
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _pickImageAndOpenReport(reason, source: ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_outlined, 
                                    color: Colors.blue, 
                                    size: 20
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Pick from gallery',
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Photo Preview column
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Center(
                            child: _reasonPhotos[reason]?.isNotEmpty ?? false
                                ? GestureDetector(
                                    onTap: () => _showFullImage(reason),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade200),
                                            image: DecorationImage(
                                              image: MemoryImage(_reasonPhotos[reason]!.first['bytes']),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        if (_reasonPhotos[reason]!.length > 1)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.4),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '+${_reasonPhotos[reason]!.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    shadows: [
                                                      Shadow(
                                                        blurRadius: 4,
                                                        color: Colors.black,
                                                        offset: Offset(0, 1),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey.shade100,
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Icon(Icons.image_outlined, size: 18, color: Colors.grey.shade400),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: _commentControllers[reason],
                            style: const TextStyle(fontSize: 11),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
                              ),
                              fillColor: Colors.grey.shade50,
                              filled: true,
                            ),
                            onChanged: (v) => _updateOtherFields(),
                          ),
                        ),
                        // Plus/Minus Buttons column (Only for Pollution and Process)
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: _activeCategory != 'TechnicalFaults' 
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () => _removeMinute(reason),
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _addMinute(reason),
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 22),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: SizedBox(
                              width: 50,
                              child: TextField(
                                controller: _downtimeControllers[reason],
                                style: TextStyle(
                                  fontSize: 13, 
                                  fontWeight: FontWeight.bold,
                                  color: minutes > 0 ? Colors.blue.shade900 : Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: minutes > 0 ? Colors.blue.shade200 : Colors.grey.shade200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: minutes > 0 ? Colors.blue.shade100 : Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: minutes > 0 ? Colors.blue : Colors.blue.shade300, width: 1.5),
                                  ),
                                  fillColor: minutes > 0 ? Colors.blue.shade50 : Colors.grey.shade50,
                                  filled: true,
                                ),
                                onChanged: (v) {
                                  // Remove leading zeros and handle empty input
                                  String cleanValue = v.replaceFirst(RegExp(r'^0+'), '');
                                  if (cleanValue.isEmpty && v.isNotEmpty) {
                                    cleanValue = '0';
                                  }
                                  
                                  if (v != cleanValue) {
                                    _downtimeControllers[reason]?.value = TextEditingValue(
                                      text: cleanValue,
                                      selection: TextSelection.collapsed(offset: cleanValue.length),
                                    );
                                  }

                                  final val = int.tryParse(cleanValue) ?? 0;
                                  setState(() {
                                    _downtimeData[reason] = val;
                                  });
                                },
                                onSubmitted: (v) => _handleManualDowntimeChange(reason, v),
                                onEditingComplete: () {
                                  if (_downtimeControllers[reason] != null) {
                                    _handleManualDowntimeChange(reason, _downtimeControllers[reason]!.text);
                                  }
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              const Divider(height: 1),

              // 3. Footer (Summary, Buttons)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
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
        title: Text(s.t('productionList'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isLocked = !_isLocked);
              _dbHelper.saveGlobalSetting('lastProductionLocked', _isLocked.toString());
            },
            icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
            tooltip: _isLocked ? s.t('unlock') : s.t('lock'),
            color: _isLocked ? Colors.red : null,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: (_isLocked || _isSaving) ? null : () => _manualSave(isFinalizing: true),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(s.t('finalize') ?? 'Finalizuj'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildCategoryTab(String category, String label) {
    final isActive = _activeCategory == category;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeCategory = category),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
            color: isActive ? Colors.blue.withOpacity(0.05) : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.blue.shade700 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
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

  Widget _buildHistoryView(AppStrings s) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('downtimeHistory')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showHistory = false),
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(_historyDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(DateFormat('MM-dd').format(_historyDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _historyDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _historyDate = picked);
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text(s.t('filterByLine')),
                        value: _filterLine,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Lines')),
                          ..._lineOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))),
                        ],
                        onChanged: (v) => setState(() => _filterLine = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text(s.t('filterByShift')),
                        value: _filterShift,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Shifts')),
                          ..._shiftOptions.map((sh) => DropdownMenuItem(value: sh, child: Text(sh))),
                        ],
                        onChanged: (v) => setState(() => _filterShift = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _dbHelper.getProductionDowntime(
                DateFormat('yyyy-MM-dd').format(_historyDate),
                lineName: _filterLine,
                shift: _filterShift,
                operatorName: _filterOperator,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return Center(child: Text(s.t('noDowntimeData')));
                }

                // Group by line and shift
                final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
                for (final item in data) {
                  final line = item['line_name'] as String;
                  final shift = item['shift'] as String? ?? 'N/A';
                  grouped.putIfAbsent(line, () => {}).putIfAbsent(shift, () => []).add(item);
                }

                return ListView(
                  children: grouped.entries.map((lineEntry) {
                    final line = lineEntry.key;
                    final shifts = lineEntry.value;

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(line, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                // We don't have shift/date here yet, we'll add the button inside the shift loop
                              ],
                            ),
                          ),
                          ...shifts.entries.map((shiftEntry) {
                            final shift = shiftEntry.key;
                            final items = shiftEntry.value;
                            final total = items.fold(0, (sum, item) => sum + (item['minutes'] as int));
                            final first = items.first;
                            final date = first['date'] as String;
                            final barrels = first['barrels_water'] == 1;
                            final cameras = first['cameras_cleaned'] == 1;
                            final defective = first['defective_carts'] ?? 0;
                            final causes = first['causes'] ?? '';
                            final op = first['operator_name'] ?? 'Unknown';

                            return _DowntimeShiftTile(
                              line: line,
                              shift: shift,
                              date: date,
                              totalMinutes: total,
                              items: items,
                              barrels: barrels,
                              cameras: cameras,
                              defective: defective,
                              causes: causes,
                              operatorName: op,
                              onDeleteReport: () => _confirmDeleteCompleteReport(line, shift, date),
                              s: s,
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteEntry(int id) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('delete')),
        content: Text(s.t('deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.deleteProductionDowntime(id);
      setState(() {}); // Refresh history view
    }
  }

  Future<void> _confirmDeleteCompleteReport(String line, String shift, String date) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('deleteCompleteReport') ?? 'Delete Complete Report'),
        content: Text(s.t('deleteCompleteReportConfirm') ?? 'Are you sure you want to delete the complete report for this line and shift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.deleteCompleteProductionReport(line, shift, date);
      setState(() {}); // Refresh history view
    }
  }
}

class _DowntimeShiftTile extends StatefulWidget {
  final String line;
  final String shift;
  final String date;
  final int totalMinutes;
  final List<Map<String, dynamic>> items;
  final bool barrels;
  final bool cameras;
  final int defective;
  final String causes;
  final String operatorName;
  final VoidCallback onDeleteReport;
  final AppStrings s;

  const _DowntimeShiftTile({
    required this.line,
    required this.shift,
    required this.date,
    required this.totalMinutes,
    required this.items,
    required this.barrels,
    required this.cameras,
    required this.defective,
    required this.causes,
    required this.operatorName,
    required this.onDeleteReport,
    required this.s,
  });

  @override
  State<_DowntimeShiftTile> createState() => _DowntimeShiftTileState();
}

class _DowntimeShiftTileState extends State<_DowntimeShiftTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(widget.shift, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: widget.onDeleteReport,
                  tooltip: widget.s.t('deleteCompleteReport') ?? 'Delete Complete Report',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                Text('${widget.totalMinutes} min', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.only(left: 48.0, right: 16.0, bottom: 16.0, top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.s.t('operator')}: ${widget.operatorName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(widget.barrels ? Icons.check_circle : Icons.cancel, size: 16, color: widget.barrels ? Colors.grey.shade400 : Colors.grey),
                    const SizedBox(width: 4),
                    Text('${widget.s.t('barrelsWithWaterIce')}: ${widget.barrels ? widget.s.t('yes') : widget.s.t('no')}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(widget.cameras ? Icons.check_circle : Icons.cancel, size: 16, color: widget.cameras ? Colors.grey.shade400 : Colors.grey),
                    const SizedBox(width: 4),
                    Text('${widget.s.t('camerasCleaned')}: ${widget.cameras ? widget.s.t('yes') : widget.s.t('no')}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                if (widget.defective > 0) ...[
                  const SizedBox(height: 4),
                  Text('${widget.s.t('defectiveCartsCount')}: ${widget.defective}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
                if (widget.causes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${widget.s.t('causes')}: ${widget.causes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                ...widget.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item['reason'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${item['minutes']} min',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class ImageEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String? initialDescription;
  final bool showDescription;

  const ImageEditorScreen({
    super.key, 
    required this.imageBytes,
    this.initialDescription,
    this.showDescription = true,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<_DrawnPath> _paths = [];
  Color _currentColor = Colors.red;
  double _currentWidth = 4.0;
  bool _isEraser = false;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Edit Image'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _paths.isNotEmpty ? () => setState(() => _paths.removeLast()) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear All',
            onPressed: () => setState(() => _paths.clear()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _paths.add(_DrawnPath(
                          path: Path()..moveTo(details.localPosition.dx, details.localPosition.dy),
                          color: _isEraser ? Colors.transparent : _currentColor,
                          width: _currentWidth,
                          isEraser: _isEraser,
                        ));
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        if (_paths.isNotEmpty) {
                          _paths.last.path.lineTo(details.localPosition.dx, details.localPosition.dy);
                        }
                      });
                    },
                    child: Stack(
                      children: [
                        Image.memory(widget.imageBytes, fit: BoxFit.contain),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DrawingPainter(paths: _paths),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Drawing Tools
          Container(
            color: Colors.grey.shade900,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _colorPicker(Colors.red),
                _colorPicker(Colors.blue),
                _colorPicker(Colors.green),
                _colorPicker(Colors.yellow),
                IconButton(
                  icon: Icon(Icons.auto_fix_normal, color: _isEraser ? Colors.white : Colors.grey),
                  onPressed: () => setState(() => _isEraser = !_isEraser),
                ),
                _widthPicker(2.0),
                _widthPicker(4.0),
                _widthPicker(8.0),
              ],
            ),
          ),
          // Description Field
          if (widget.showDescription)
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
              controller: _descriptionController,
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: s.t('description'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.edit_note_rounded, color: Colors.blue.shade400, size: 28),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.blue.withOpacity(0.3), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          // Modern Action Buttons
          Container(
            color: Colors.grey.shade900,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: Text(s.t('cancel').toUpperCase()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAndExit,
                    icon: const Icon(Icons.check_circle_outline, size: 24),
                    label: Text(s.t('confirm').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: Colors.green.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorPicker(Color color) {
    bool isSelected = _currentColor == color && !_isEraser;
    return GestureDetector(
      onTap: () => setState(() {
        _currentColor = color;
        _isEraser = false;
      }),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
          boxShadow: [if (isSelected) BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
        ),
      ),
    );
  }

  Widget _widthPicker(double width) {
    bool isSelected = _currentWidth == width;
    return GestureDetector(
      onTap: () => setState(() => _currentWidth = width),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.white24 : Colors.transparent,
        ),
        child: Center(
          child: Container(
            width: width + 2,
            height: width + 2,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndExit() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        if (mounted) {
          Navigator.pop(context, {
            'image': byteData.buffer.asUint8List(),
            'description': _descriptionController.text.trim(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error saving edited image: $e');
    }
  }
}

class _DrawnPath {
  final Path path;
  final Color color;
  final double width;
  final bool isEraser;

  _DrawnPath({required this.path, required this.color, required this.width, this.isEraser = false});
}

class _DrawingPainter extends CustomPainter {
  final List<_DrawnPath> paths;
  _DrawingPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    for (var item in paths) {
      final paint = Paint()
        ..color = item.color
        ..strokeWidth = item.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (item.isEraser) {
        paint.blendMode = BlendMode.clear;
      }

      canvas.drawPath(item.path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
