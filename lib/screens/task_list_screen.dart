import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_strings.dart';
import '../database/db_helper.dart';
import '../models/task.dart';
import 'add_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, required this.currentUsername, this.isEmbedded = false});

  final String currentUsername;
  final bool isEmbedded;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> with SingleTickerProviderStateMixin {
  final DBHelper _dbHelper = DBHelper.instance;
  List<Task> _tasks = [];
  bool _isLoading = true;
  String _statusFilter = 'Wszystkie';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<String> get _currentStatusOptions {
    if (_tabController.index == 0) {
      return ['Wszystkie', 'Zaplanowane'];
    } else {
      return ['Wszystkie', 'Zrealizowane', 'Anulowane'];
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _statusFilter = 'Wszystkie';
        });
        _loadTasks();
      }
    });
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _isLoading = true);
    try {
      debugPrint('DEBUG: TaskListScreen._loadTasks called with filter: $_statusFilter');
      
      String? tabStatus;
      if (_tabController.index == 0) {
        // "Bieżące zadania" - exclusion of history
        tabStatus = 'active'; 
      } else {
        // "Historia zadań" - exclusion of active
        tabStatus = 'history';
      }

      final taskMaps = await _dbHelper.getTasks(
        status: _statusFilter == 'Wszystkie' ? tabStatus : _statusFilter,
        query: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _tasks = taskMaps.map((map) {
            try {
              return Task.fromMap(map);
            } catch (e) {
              debugPrint('DEBUG: Error parsing task map: $e, map: $map');
              rethrow;
            }
          }).toList();
          _isLoading = false;
        });
        debugPrint('DEBUG: TaskListScreen loaded ${_tasks.length} tasks into state');
      }
    } catch (e) {
      debugPrint('DEBUG: Error loading tasks into UI: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Zaplanowane':
        return Colors.purple.shade400;
      case 'Do akceptacji':
        return Colors.red.shade400;
      case 'W realizacji':
        return Colors.blue.shade400;
      case 'Zrealizowane':
        return Colors.green.shade500;
      case 'Anulowane':
        return Colors.grey.shade400;
      default:
        return Colors.grey;
    }
  }

  void _openAddTaskScreen([Task? task]) {
    Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AddTaskScreen(
          currentUsername: widget.currentUsername,
          task: task,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadTasks(showLoader: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    Widget content = TabBarView(
      controller: _tabController,
      children: [
        _buildTaskTab(s, isHistory: false),
        _buildTaskTab(s, isHistory: true),
      ],
    );

    if (widget.isEmbedded) {
      return Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: s.t('currentTasksTab')),
              Tab(text: s.t('historyTasksTab')),
            ],
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue.shade700,
            indicatorWeight: 3,
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(s.t('taskList'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.t('currentTasksTab')),
            Tab(text: s.t('historyTasksTab')),
          ],
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade700,
          indicatorWeight: 3,
        ),
      ),
      body: content,
    );
  }

  Widget _buildTaskTab(AppStrings s, {required bool isHistory}) {
    return RefreshIndicator(
      onRefresh: () => _loadTasks(showLoader: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
              // 1. Header (Add button, filters, search)
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
                        if (!isHistory)
                          ElevatedButton.icon(
                            onPressed: () => _openAddTaskScreen(),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(s.t('addTask'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                          ),
                        if (isHistory)
                          const SizedBox(height: 48), // Zachowanie wysokości nagłówka
                        const Spacer(),
                        // Status Filter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('status').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
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
                                  value: _currentStatusOptions.contains(_statusFilter) ? _statusFilter : 'Wszystkie',
                                  dropdownColor: Theme.of(context).cardColor,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: _currentStatusOptions.map((v) {
                                    String label = v;
                                    if (v == 'Wszystkie') label = s.t('all');
                                    if (v == 'Zaplanowane') label = s.t('planned');
                                    if (v == 'Zrealizowane') label = s.t('completed');
                                    if (v == 'Anulowane') label = s.t('cancelled');
                                    return DropdownMenuItem(value: v, child: Text(label));
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _statusFilter = v);
                                      _loadTasks();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodyMedium?.color,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: s.t('filterHint'),
                                          hintStyle: TextStyle(color: Colors.grey.shade400),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        onSubmitted: (_) => _loadTasks(showLoader: false),
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
                                      onPressed: () => _loadTasks(showLoader: false),
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
                                        _loadTasks(showLoader: false);
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
              else if (_tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(child: Text(s.t('noTasks'), style: const TextStyle(color: Colors.grey))),
                )
              else
                Table(
                  border: TableBorder(
                    horizontalInside: BorderSide(color: Colors.grey.shade100),
                    verticalInside: BorderSide(color: Colors.grey.shade100),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(3),
                    2: FixedColumnWidth(130),
                    3: FixedColumnWidth(100),
                    4: FixedColumnWidth(100),
                    5: FixedColumnWidth(48),
                  },
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade50),
                      children: [
                        _buildHeaderCell(s.t('location').toUpperCase()),
                        _buildHeaderCell(s.t('description').toUpperCase()),
                        _buildHeaderCell(s.t('status').toUpperCase(), textAlign: TextAlign.center),
                        _buildHeaderCell(s.t('date').toUpperCase()),
                        _buildHeaderCell(s.t('username').toUpperCase()),
                        _buildHeaderCell(''),
                      ],
                    ),
                    // Data Rows
                    ..._tasks.map((task) {
                      final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                            child: Text(task.title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                            child: Text(task.type, style: TextStyle(fontSize: 11, color: textColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Center(child: _buildStatusBadge(task.status)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: _buildDateCell(task),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                            child: Text(task.label ?? '-', style: TextStyle(fontSize: 11, color: textColor)),
                          ),
                          Center(
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  _openAddTaskScreen(task);
                                } else if (val == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(s.t('deleteTask')),
                                      content: Text(s.t('deleteTaskConfirm')),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('deleteTask'), style: const TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _dbHelper.deleteTask(task.id!);
                                    _loadTasks();
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 18), const SizedBox(width: 8), Text(s.t('edit'))])),
                                PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size: 18, color: Colors.red), const SizedBox(width: 8), Text(s.t('deleteTask'), style: const TextStyle(color: Colors.red))])),
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
      ),
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign textAlign = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: Theme.of(context).textTheme.titleSmall?.color ?? Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = AppStrings.of(context);
    String label = status;
    if (status == 'Zaplanowane') label = s.t('planned');
    if (status == 'Zrealizowane') label = s.t('completed');
    if (status == 'Anulowane') label = s.t('cancelled');

    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
        ),
      ),
    );
  }

  Widget _buildDateCell(Task task) {
    if (task.dateStart == null) return const Text('-');
    final date = DateTime.parse(task.dateStart!);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(fontSize: 11, color: Colors.red)),
        Text(DateFormat('HH:mm').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
