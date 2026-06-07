import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../app_strings.dart';
import '../database/db_helper.dart';
import '../models/asset.dart';
import '../widgets/pc_sidebar.dart';
import 'users_screen.dart';
import 'dashboard_screen.dart';
import 'warehouse_screen.dart';
import 'schedule_screen.dart';
import 'notebook_screen.dart';
import 'failures_screen.dart';
import 'settings_screen.dart';
import 'production_list_screen.dart';
import 'production_report_screen.dart';
import 'task_list_screen.dart';
import 'planning_screen.dart';
import 'assets_screen.dart';
import 'emergency_numbers_screen.dart';
import 'documents_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.strings,
    required this.currentUsername,
    required this.isAdmin,
    required this.canManageUsers,
    required this.canReportFailure,
    required this.onLogout,
    required this.currentThemeMode,
    required this.currentLanguage,
    required this.currentUiScale,
    required this.isPcMode,
    required this.onToggleThemeMode,
    required this.onChangeLanguage,
    required this.onChangeUiScale,
    required this.onTogglePcMode,
  });

  final AppStrings strings;
  final String currentUsername;
  final bool isAdmin;
  final bool canManageUsers;
  final bool canReportFailure;
  final VoidCallback onLogout;
  final ThemeMode currentThemeMode;
  final AppLanguage currentLanguage;
  final AppUiScale currentUiScale;
  final bool isPcMode;
  final VoidCallback onToggleThemeMode;
  final Function(AppLanguage) onChangeLanguage;
  final Function(AppUiScale) onChangeUiScale;
  final Function(bool) onTogglePcMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DBHelper _dbHelper = DBHelper.instance;
  List<Asset> _assets = <Asset>[];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedRoute = 'home';
  Map<String, bool> _tileVisibility = {};
  List<String> _tileOrder = [];

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _loadTileSettings();
    _selectedRoute = widget.isPcMode ? 'home' : 'menu';
  }

  Future<void> _loadTileSettings() async {
    final visibility = await _dbHelper.getAllTileVisibility();
    final orderMap = await _dbHelper.getAllTileOrder();
    
    // Default tiles
    final defaultTiles = [
      'production_report',
      'production_list',
      'failures',
      'assets',
      'tasks',
      'planning',
      'schedule',
      'dashboard',
      'warehouse',
      'notebook',
      'emergency',
      'documents',
      'settings',
    ];

    // Sort existing tiles based on saved order
    List<String> sortedTiles = List.from(defaultTiles);
    if (orderMap.isNotEmpty) {
      sortedTiles.sort((a, b) {
        final orderA = orderMap[a] ?? 999;
        final orderB = orderMap[b] ?? 999;
        return orderA.compareTo(orderB);
      });
    }

    setState(() {
      _tileVisibility = visibility;
      _tileOrder = sortedTiles;
    });
  }

  Future<void> _toggleTileVisibility(String tileId, bool current) async {
    await _dbHelper.setTileVisibility(tileId, !current);
    _loadTileSettings();
  }

  Future<void> _updateTileOrder(int oldIndex, int newIndex) async {
    setState(() {
      final String item = _tileOrder.removeAt(oldIndex);
      _tileOrder.insert(newIndex, item);
    });

    final Map<String, int> newOrderMap = {};
    for (int i = 0; i < _tileOrder.length; i++) {
      newOrderMap[_tileOrder[i]] = i;
    }
    await _dbHelper.updateTileOrder(newOrderMap);
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final assets = await _dbHelper.getAssets();
      if (!mounted) {
        return;
      }

      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _getScreenByRoute(String route) {
    final s = widget.strings;
    switch (route) {
      case 'home':
        return _buildHomeContent(s);
      case 'menu':
        return _buildGridMenu(s);
      case 'tasks':
        return TaskListScreen(currentUsername: widget.currentUsername, isEmbedded: true);
      case 'failures':
        return FailuresScreen(strings: s, currentUsername: widget.currentUsername, isEmbedded: true);
      case 'assets':
        return AssetsScreen(strings: s, isEmbedded: true);
      case 'planning':
        return PlanningScreen(currentUsername: widget.currentUsername, isEmbedded: true);
      case 'production_report':
        return ProductionReportScreen(currentUsername: widget.currentUsername, isEmbedded: true);
      case 'production':
        return ProductionListScreen(currentUsername: widget.currentUsername, isEmbedded: true);
      case 'schedule':
        return ScheduleScreen(strings: s, isEmbedded: true);
      case 'warehouse':
        return WarehouseScreen(strings: s, isEmbedded: true);
      case 'notebook':
        return NotebookScreen(strings: s, currentUsername: widget.currentUsername, isEmbedded: true);
      case 'emergency':
        return EmergencyNumbersScreen(currentUsername: widget.currentUsername, isEmbedded: true);
      case 'documents':
        return DocumentsScreen(strings: s, currentUsername: widget.currentUsername, isEmbedded: true);
      case 'users':
        return UsersScreen(strings: s, isEmbedded: true);
      case 'settings':
        return SettingsScreen(
          currentThemeMode: widget.currentThemeMode,
          currentLanguage: widget.currentLanguage,
          currentUiScale: widget.currentUiScale,
          isPcMode: widget.isPcMode,
          onToggleThemeMode: widget.onToggleThemeMode,
          onChangeLanguage: widget.onChangeLanguage,
          onChangeUiScale: widget.onChangeUiScale,
          onTogglePcMode: widget.onTogglePcMode,
          isAdmin: widget.isAdmin,
          canManageUsers: widget.canManageUsers,
          onOpenUsers: () {
            if (widget.isPcMode) {
              setState(() => _selectedRoute = 'users');
            } else {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => UsersScreen(strings: s),
                ),
              );
            }
          },
          isEmbedded: true,
        );
      case 'dashboard':
      default:
        return _buildHomeContent(s);
    }
  }

  String _getBreadcrumbLabel(String route) {
    final s = widget.strings;
    switch (route) {
      case 'home': return s.t('homeTitle');
      case 'menu': return s.t('menuTitle');
      case 'tasks': return s.t('tasksTile');
      case 'failures': return s.t('reportFailureTile');
      case 'assets': return s.t('machinesTile');
      case 'planning': return s.t('planningTile');
      case 'production_report': return 'Production List';
      case 'production': return s.t('productionTile');
      case 'schedule': return s.t('scheduleTile');
      case 'warehouse': return s.t('warehouseTile');
      case 'notebook': return s.t('notebookTile');
      case 'emergency': return s.t('emergencyTile');
      case 'documents': return s.t('documentation');
      case 'users': return s.t('usersTile');
      case 'settings': return s.t('settings');
      default: return 'HOME';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    if (widget.isPcMode) {
      return Scaffold(
        body: Row(
          children: [
            PcSidebar(
              strings: s,
              currentUsername: widget.currentUsername,
              isAdmin: widget.isAdmin,
              selectedRoute: _selectedRoute,
              onRouteSelected: (route) => setState(() => _selectedRoute = route),
              onLogout: widget.onLogout,
              tileVisibility: _tileVisibility,
            ),
            Expanded(
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Row(
                      children: [
                        if (_selectedRoute != 'home')
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: IconButton(
                              onPressed: () => setState(() => _selectedRoute = 'home'),
                              icon: const Icon(Icons.arrow_back),
                              tooltip: s.t('homeTitle'),
                              color: Colors.blue.shade700,
                            ),
                          ),
                        Icon(
                          _selectedRoute == 'home' ? Icons.home_outlined : Icons.chevron_left,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                        Text(
                          _getBreadcrumbLabel(_selectedRoute).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  // Main Content
                  Expanded(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: _getScreenByRoute(_selectedRoute),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getBreadcrumbLabel(_selectedRoute)),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            tooltip: s.t('logout'),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorContent(s)
              : _getScreenByRoute(_selectedRoute),
      floatingActionButton: _buildChatFAB(context, s),
    );
  }

  Widget _buildErrorContent(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.t('dbErrorTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(AppStrings s) {
    return DashboardContent(strings: s, isScrollable: true);
  }

  Widget _buildGridMenu(AppStrings s) {
    final isDesktop = widget.isPcMode || MediaQuery.of(context).size.width >= 900;

    bool isVisible(String id) => _tileVisibility[id] ?? true;

    Widget buildTile(String id) {
      switch (id) {
        case 'production_report':
          return (widget.isAdmin || isVisible('production_report'))
              ? _ActionTile(
                  key: const ValueKey('production_report'),
                  title: 'Production List',
                  iconPath: 'assets/images/checklist.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('production_report'),
                  onToggleVisibility: () => _toggleTileVisibility('production_report', isVisible('production_report')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'production_report');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ProductionReportScreen(
                            currentUsername: widget.currentUsername,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('production_report_hidden'));
        case 'production_list':
          return (widget.isAdmin || isVisible('production_list'))
              ? _ActionTile(
                  key: const ValueKey('production_list'),
                  title: s.t('productionTile'),
                  iconPath: 'assets/images/checklist.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('production_list'),
                  onToggleVisibility: () => _toggleTileVisibility('production_list', isVisible('production_list')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'production');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ProductionListScreen(
                            currentUsername: widget.currentUsername,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('production_list_hidden'));
        case 'failures':
          return (widget.isAdmin || isVisible('failures'))
              ? _ActionTile(
                  key: const ValueKey('failures'),
                  title: s.t('reportFailureTile'),
                  iconPath: 'assets/images/click.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('failures'),
                  onToggleVisibility: () => _toggleTileVisibility('failures', isVisible('failures')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'failures');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => FailuresScreen(
                            strings: s,
                            currentUsername: widget.currentUsername,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('failures_hidden'));
        case 'assets':
          return (widget.isAdmin || isVisible('assets'))
              ? _ActionTile(
                  key: const ValueKey('assets'),
                  title: s.t('machinesTile'),
                  icon: Icons.settings_applications_outlined,
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('assets'),
                  onToggleVisibility: () => _toggleTileVisibility('assets', isVisible('assets')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'assets');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AssetsScreen(
                            strings: s,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('assets_hidden'));
        case 'tasks':
          return (widget.isAdmin || isVisible('tasks'))
              ? _ActionTile(
                  key: const ValueKey('tasks'),
                  title: s.t('tasksTile'),
                  iconPath: 'assets/images/target.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('tasks'),
                  onToggleVisibility: () => _toggleTileVisibility('tasks', isVisible('tasks')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'tasks');
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => TaskListScreen(
                                  currentUsername: widget.currentUsername)));
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('tasks_hidden'));
        case 'planning':
          return (widget.isAdmin || isVisible('planning'))
              ? _ActionTile(
                  key: const ValueKey('planning'),
                  title: s.t('planningTile'),
                  iconPath: 'assets/images/calendar.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('planning'),
                  onToggleVisibility: () => _toggleTileVisibility('planning', isVisible('planning')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'planning');
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => PlanningScreen(
                                  currentUsername: widget.currentUsername)));
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('planning_hidden'));
        case 'schedule':
          return (widget.isAdmin || isVisible('schedule'))
              ? _ActionTile(
                  key: const ValueKey('schedule'),
                  title: s.t('scheduleTile'),
                  iconPath: 'assets/images/calendar.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('schedule'),
                  onToggleVisibility: () => _toggleTileVisibility('schedule', isVisible('schedule')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'schedule');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ScheduleScreen(
                            strings: s,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('schedule_hidden'));
        case 'dashboard':
          return (widget.isAdmin || isVisible('dashboard'))
              ? _ActionTile(
                  key: const ValueKey('dashboard'),
                  title: s.t('dashboardTitle'),
                  iconPath: 'assets/images/line-chart.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('dashboard'),
                  onToggleVisibility: () => _toggleTileVisibility('dashboard', isVisible('dashboard')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'dashboard');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => DashboardScreen(strings: s),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('dashboard_hidden'));
        case 'warehouse':
          return (widget.isAdmin || isVisible('warehouse'))
              ? _ActionTile(
                  key: const ValueKey('warehouse'),
                  title: s.t('warehouseTile'),
                  iconPath: 'assets/images/target.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('warehouse'),
                  onToggleVisibility: () => _toggleTileVisibility('warehouse', isVisible('warehouse')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'warehouse');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => WarehouseScreen(
                            strings: s,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('warehouse_hidden'));
        case 'notebook':
          return (widget.isAdmin || isVisible('notebook'))
              ? _ActionTile(
                  key: const ValueKey('notebook'),
                  title: s.t('notebookTile'),
                  iconPath: 'assets/images/notebook.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('notebook'),
                  onToggleVisibility: () => _toggleTileVisibility('notebook', isVisible('notebook')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'notebook');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => NotebookScreen(
                            strings: s,
                            currentUsername: widget.currentUsername,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('notebook_hidden'));
        case 'emergency':
          return (widget.isAdmin || isVisible('emergency'))
              ? _ActionTile(
                  key: const ValueKey('emergency'),
                  title: s.t('emergencyTile'),
                  iconPath: 'assets/images/phone.png',
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('emergency'),
                  onToggleVisibility: () => _toggleTileVisibility('emergency', isVisible('emergency')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'emergency');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => EmergencyNumbersScreen(
                            currentUsername: widget.currentUsername,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('emergency_hidden'));
        case 'documents':
          return (widget.isAdmin || isVisible('documents'))
              ? _ActionTile(
                  key: const ValueKey('documents'),
                  title: s.t('documentation'),
                  icon: Icons.description_outlined,
                  isAdmin: widget.isAdmin,
                  isVisible: isVisible('documents'),
                  onToggleVisibility: () => _toggleTileVisibility('documents', isVisible('documents')),
                  onTap: () {
                    if (widget.isPcMode) {
                      setState(() => _selectedRoute = 'documents');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => DocumentsScreen(
                            strings: s,
                            currentUsername: widget.currentUsername,
                          ),
                        ),
                      );
                    }
                  },
                )
              : const SizedBox.shrink(key: ValueKey('documents_hidden'));
        case 'settings':
          return _ActionTile(
            key: const ValueKey('settings'),
            title: s.t('settings'),
            icon: Icons.settings_outlined,
            isAdmin: false,
            isVisible: true,
            onToggleVisibility: () {},
            onTap: () {
              if (widget.isPcMode) {
                setState(() => _selectedRoute = 'settings');
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(
                      currentThemeMode: widget.currentThemeMode,
                      currentLanguage: widget.currentLanguage,
                      currentUiScale: widget.currentUiScale,
                      isPcMode: widget.isPcMode,
                      onToggleThemeMode: widget.onToggleThemeMode,
                      onChangeLanguage: widget.onChangeLanguage,
                      onChangeUiScale: widget.onChangeUiScale,
                      onTogglePcMode: widget.onTogglePcMode,
                      isAdmin: widget.isAdmin,
                      canManageUsers: widget.canManageUsers,
                      onOpenUsers: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => UsersScreen(strings: s),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            },
          );
        default:
          return const SizedBox.shrink();
      }
    }

    // Filter out tiles that should be hidden for non-admins and are not visible
    final List<String> visibleTileIds = _tileOrder.where((id) {
      if (id == 'settings') return true;
      if (widget.isAdmin) return true;
      return isVisible(id);
    }).toList();

    return ReorderableGridView.count(
      padding: const EdgeInsets.all(12),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: isDesktop ? 1.5 : 1.35,
      onReorder: _updateTileOrder,
      children: visibleTileIds.map((id) => buildTile(id)).toList(),
    );
  }

  Widget _buildChatFAB(BuildContext context, AppStrings s) {
    return FloatingActionButton.extended(
      onPressed: () => _showOnlineUsers(context, s),
      icon: Image.asset('assets/images/phone.png', width: 24, height: 24),
      label: Text(s.t('chat')),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
    );
  }

  void _showOnlineUsers(BuildContext context, AppStrings s) async {
    final users = await _dbHelper.getOnlineUsers();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.t('onlineUsers'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.circle, color: Colors.green, size: 12),
              ],
            ),
            const SizedBox(height: 16),
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text(s.t('noUsers'))),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user['username'][0].toUpperCase()),
                      ),
                      title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${s.t('role')}: ${user['rola'] ?? s.t('user')}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.message_outlined, color: Colors.blue),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${s.t('chat')} ${user['username']} - ${s.t('soonAvailable')}')),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDocsDialog(Asset asset) {
    final s = widget.strings;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${s.t('documentation')}: ${asset.nazwa}'),
        content: asset.dokumentacja != null && asset.dokumentacja!.isNotEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 48, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(asset.dokumentacja!, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                ],
              )
            : Text(s.t('emptyList')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
        ],
      ),
    );
  }

  void _addDocsDialog(Asset asset) {
    final s = widget.strings;
    final controller = TextEditingController(text: asset.dokumentacja);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('addDocumentation')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: s.t('linkPath'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              await _dbHelper.updateAssetDocumentation(asset.id!, controller.text.trim());
              if (context.mounted) {
                Navigator.pop(context);
                _loadAssets();
              }
            },
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.title,
    this.iconPath,
    this.icon,
    required this.onTap,
    this.isAdmin = false,
    this.isVisible = true,
    this.onToggleVisibility,
  }) : assert(iconPath != null || icon != null, 'Either iconPath or icon must be provided');

  final String title;
  final String? iconPath;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isAdmin;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isVisible 
                  ? Theme.of(context).colorScheme.primaryContainer 
                  : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconPath != null)
                      Opacity(
                        opacity: isVisible ? 1.0 : 0.4,
                        child: Image.asset(iconPath!, width: 32, height: 32),
                      )
                    else if (icon != null)
                      Icon(icon, size: 32, color: (isVisible ? Theme.of(context).colorScheme.primary : Colors.grey).withOpacity(isVisible ? 1.0 : 0.4)),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isVisible ? null : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isAdmin && onToggleVisibility != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onToggleVisibility,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isVisible ? Colors.green.shade600 : Colors.red.shade600,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isVisible ? 'ON' : 'OFF',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                      size: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
