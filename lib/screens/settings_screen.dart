import 'package:flutter/material.dart';
import '../app_strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.currentLanguage,
    required this.currentUiScale,
    required this.isPcMode,
    required this.onToggleThemeMode,
    required this.onChangeLanguage,
    required this.onChangeUiScale,
    required this.onTogglePcMode,
    required this.isAdmin,
    required this.canManageUsers,
    required this.onOpenUsers,
    this.isEmbedded = false,
  });

  final ThemeMode currentThemeMode;
  final AppLanguage currentLanguage;
  final AppUiScale currentUiScale;
  final bool isPcMode;
  final VoidCallback onToggleThemeMode;
  final Function(AppLanguage) onChangeLanguage;
  final Function(AppUiScale) onChangeUiScale;
  final Function(bool) onTogglePcMode;
  final bool isAdmin;
  final bool canManageUsers;
  final VoidCallback onOpenUsers;
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    
    Widget body = ListView(
      children: [
        _buildLanguageSection(context, strings),
        const Divider(),
        _buildThemeSection(context, strings),
        const Divider(),
        _buildScaleSection(context, strings),
        const Divider(),
        _buildPcModeSection(context, strings),
        if (isAdmin || canManageUsers) ...[
          const Divider(),
          _buildAdminSection(context, strings),
        ],
      ],
    );

    if (isEmbedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(strings.t('settings')),
      ),
      body: body,
    );
  }

  Widget _buildLanguageSection(BuildContext context, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            strings.t('language'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...AppLanguage.values.map((lang) {
          final isSelected = currentLanguage == lang;
          return ListTile(
            leading: Text(
              AppStrings.languageLabel(lang).split(' ')[0],
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(AppStrings.languageLabel(lang).split(' ')[1]),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () => onChangeLanguage(lang),
          );
        }),
      ],
    );
  }

  Widget _buildThemeSection(BuildContext context, AppStrings strings) {
    final isDark = currentThemeMode == ThemeMode.dark;
    return ListTile(
      leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
      title: Text(strings.t('theme')),
      subtitle: Text(isDark ? strings.t('dark') : strings.t('light')),
      trailing: Switch(
        value: isDark,
        onChanged: (_) => onToggleThemeMode(),
      ),
    );
  }

  Widget _buildScaleSection(BuildContext context, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            strings.t('uiScale'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: AppUiScale.values.map((scale) {
            final isSelected = currentUiScale == scale;
            return ChoiceChip(
              label: Text(AppStrings.uiScaleLabel(scale, 'pl')),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onChangeUiScale(scale);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPcModeSection(BuildContext context, AppStrings strings) {
    return ListTile(
      leading: const Icon(Icons.computer),
      title: Text(strings.t('pcMode')),
      subtitle: Text(strings.t('pcModeInfo')),
      trailing: Switch(
        value: isPcMode,
        onChanged: (value) => _showPasswordDialog(context, value, strings),
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            strings.t('administration') ?? 'ADMINISTRATION',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: Text(strings.t('usersTile')),
          subtitle: Text(strings.t('manageUsers') ?? 'Zarządzaj użytkownikami i uprawnieniami'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenUsers,
        ),
      ],
    );
  }

  void _showPasswordDialog(BuildContext context, bool newValue, AppStrings strings) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.t('pcMode')),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: strings.t('enterAdminPass'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text == 'admin123') {
                onTogglePcMode(newValue);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.t('invalidPass'))),
                );
              }
            },
            child: Text(strings.t('save')),
          ),
        ],
      ),
    );
  }
}
