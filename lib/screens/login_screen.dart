import 'package:flutter/material.dart';

import '../app_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.strings,
    required this.currentThemeMode,
    required this.currentLanguage,
    required this.currentUiScale,
    required this.onToggleThemeMode,
    required this.onChangeLanguage,
    required this.onChangeUiScale,
    required this.onLogin,
  });

  final AppStrings strings;
  final ThemeMode currentThemeMode;
  final AppLanguage currentLanguage;
  final AppUiScale currentUiScale;
  final VoidCallback onToggleThemeMode;
  final ValueChanged<AppLanguage> onChangeLanguage;
  final ValueChanged<AppUiScale> onChangeUiScale;
  final Future<bool> Function(String username, String password) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _loginError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final success = await widget.onLogin(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (!success) {
      setState(() {
        _loginError = widget.strings.t('loginFailed');
      });
      return;
    }
    setState(() {
      _loginError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = widget.currentThemeMode == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('loginTitle')),
        actions: [
          IconButton(
            onPressed: widget.onToggleThemeMode,
            tooltip: '${s.t('theme')}: ${isDark ? s.t('dark') : s.t('light')}',
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
          ),
          PopupMenuButton<AppUiScale>(
            tooltip: s.t('uiScale'),
            onSelected: widget.onChangeUiScale,
            itemBuilder: (context) {
              return AppUiScale.values
                  .map(
                    (scale) => PopupMenuItem<AppUiScale>(
                          value: scale,
                          child: Text(
                            AppStrings.uiScaleLabel(
                              scale,
                              s.locale.languageCode,
                            ),
                          ),
                        ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.text_fields),
          ),
          PopupMenuButton<AppLanguage>(
            tooltip: s.t('language'),
            onSelected: widget.onChangeLanguage,
            itemBuilder: (context) {
              return AppLanguage.values
                  .map(
                    (lang) => PopupMenuItem<AppLanguage>(
                          value: lang,
                          child: Text(AppStrings.languageLabel(lang)),
                        ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.45),
              colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 12,
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final logoSize = (constraints.maxWidth * 0.62)
                                  .clamp(180.0, 260.0);
                              return SizedBox(
                                width: logoSize,
                                height: logoSize,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Image.asset(
                                    'assets/images/logo_lcs.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.precision_manufacturing,
                                        color: colorScheme.primary,
                                        size: 52,
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.t('loginTitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: s.t('username'),
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return s.t('enterUsername');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: s.t('password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return s.t('enterPassword');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _submit();
                            },
                            icon: const Icon(Icons.login),
                            label: Text(s.t('login')),
                          ),
                        ),
                        if (_loginError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _loginError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
