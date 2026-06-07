import 'package:flutter/material.dart';
import '../app_strings.dart';

class PcSidebar extends StatelessWidget {
  final AppStrings strings;
  final String currentUsername;
  final bool isAdmin;
  final String selectedRoute;
  final Function(String) onRouteSelected;
  final VoidCallback onLogout;
  final Map<String, bool> tileVisibility;

  const PcSidebar({
    super.key,
    required this.strings,
    required this.currentUsername,
    required this.isAdmin,
    required this.selectedRoute,
    required this.onRouteSelected,
    required this.onLogout,
    required this.tileVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sidebarColor = isDark ? Colors.black : const Color(0xFF1A237E); // Deep Indigo/Blue

    bool isVisible(String id) => isAdmin || (tileVisibility[id] ?? true);

    return Container(
      width: 260,
      color: sidebarColor,
      child: Column(
        children: [
          // Logo/Branding Area
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/images/logo_lcs.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.precision_manufacturing,
                      color: Color(0xFF1A237E),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'LCS Clean',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white24, height: 1),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildCategory(strings.t('maintenance') ?? 'MAINTENANCE'),
                _buildMenuItem(
                  title: strings.t('homeTitle'),
                  icon: Icons.home_outlined,
                  route: 'home',
                ),
                if (isVisible('tasks'))
                  _buildMenuItem(
                    title: strings.t('tasksTile'),
                    icon: Icons.assignment_outlined,
                    route: 'tasks',
                  ),
                if (isVisible('failures'))
                  _buildMenuItem(
                    title: strings.t('reportFailureTile'),
                    icon: Icons.report_problem_outlined,
                    route: 'failures',
                  ),
                
                _buildCategory(strings.t('assets') ?? 'ASSETS'),
                if (isVisible('assets'))
                  _buildMenuItem(
                    title: strings.t('machinesTile'),
                    icon: Icons.settings_applications_outlined,
                    route: 'assets',
                  ),
                if (isVisible('planning'))
                  _buildMenuItem(
                    title: strings.t('planningTile'),
                    icon: Icons.event_note_outlined,
                    route: 'planning',
                  ),

                _buildCategory(strings.t('operations') ?? 'OPERATIONS'),
                if (isVisible('production_report'))
                  _buildMenuItem(
                    title: 'Production List',
                    icon: Icons.assignment_outlined,
                    route: 'production_report',
                  ),
                if (isVisible('production_list'))
                  _buildMenuItem(
                    title: strings.t('productionTile'),
                    icon: Icons.fact_check_outlined,
                    route: 'production',
                  ),
                if (isVisible('schedule'))
                  _buildMenuItem(
                    title: strings.t('scheduleTile'),
                    icon: Icons.calendar_month_outlined,
                    route: 'schedule',
                  ),
                if (isVisible('warehouse'))
                  _buildMenuItem(
                    title: strings.t('warehouseTile'),
                    icon: Icons.inventory_2_outlined,
                    route: 'warehouse',
                  ),

                _buildCategory(strings.t('tools') ?? 'TOOLS'),
                if (isVisible('notebook'))
                  _buildMenuItem(
                    title: strings.t('notebookTile'),
                    icon: Icons.note_alt_outlined,
                    route: 'notebook',
                  ),
                if (isVisible('emergency'))
                  _buildMenuItem(
                    title: strings.t('emergencyTile'),
                    icon: Icons.emergency_outlined,
                    route: 'emergency',
                  ),
                if (isVisible('documents'))
                  _buildMenuItem(
                    title: strings.t('documentation'),
                    icon: Icons.description_outlined,
                    route: 'documents',
                  ),
                
                _buildCategory(strings.t('system') ?? 'SYSTEM'),
                _buildMenuItem(
                  title: strings.t('settings'),
                  icon: Icons.settings_outlined,
                  route: 'settings',
                ),
              ],
            ),
          ),

          // User Info & Logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.black12,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Text(
                    currentUsername.isNotEmpty ? currentUsername[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentUsername,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                  tooltip: strings.t('logout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required String route,
  }) {
    final isSelected = selectedRoute == route;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        onTap: () => onRouteSelected(route),
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: Colors.white.withOpacity(0.15),
      ),
    );
  }
}
