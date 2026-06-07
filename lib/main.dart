import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_strings.dart';
import 'database/db_helper.dart';
import 'models/app_user.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    // Initialize FFI for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const CmmsUltimoApp());
}

class CmmsUltimoApp extends StatefulWidget {
  const CmmsUltimoApp({super.key});

  @override
  State<CmmsUltimoApp> createState() => _CmmsUltimoAppState();
}

class _CmmsUltimoAppState extends State<CmmsUltimoApp> {
  static const String _adminUsername = 'admin';
  static const String _adminPassword = 'admin123';

  final DBHelper _dbHelper = DBHelper.instance;
  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _language = AppLanguage.en;
  AppUiScale _uiScale = AppUiScale.normal;
  bool _isPcMode = false;
  AppUser? _loggedUser;
  bool _isLoadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadGlobalPrefs();
  }

  Future<void> _loadGlobalPrefs() async {
    // 1. Try loading from Database first
    String? theme = await _dbHelper.getGlobalSetting('globalTheme');
    String? langCode = await _dbHelper.getGlobalSetting('globalLanguage');
    String? scale = await _dbHelper.getGlobalSetting('globalUiScale');
    String? pcModeStr = await _dbHelper.getGlobalSetting('globalPcMode');
    String? lastUser = await _dbHelper.getGlobalSetting('lastUser');

    // 2. Fallback to SharedPreferences if DB is empty (migration)
    final prefs = await SharedPreferences.getInstance();
    if (theme == null) {
      theme = prefs.getString('globalTheme');
      if (theme != null) await _dbHelper.saveGlobalSetting('globalTheme', theme);
    }
    if (langCode == null) {
      langCode = prefs.getString('globalLanguage');
      if (langCode != null) await _dbHelper.saveGlobalSetting('globalLanguage', langCode);
    }
    if (scale == null) {
      scale = prefs.getString('globalUiScale');
      if (scale != null) await _dbHelper.saveGlobalSetting('globalUiScale', scale);
    }
    if (pcModeStr == null) {
      final pcMode = prefs.getBool('globalPcMode');
      if (pcMode != null) {
        pcModeStr = pcMode.toString();
        await _dbHelper.saveGlobalSetting('globalPcMode', pcModeStr);
      }
    }
    if (lastUser == null) {
      lastUser = prefs.getString('lastUser');
      if (lastUser != null) await _dbHelper.saveGlobalSetting('lastUser', lastUser);
    }

    setState(() {
      _isPcMode = pcModeStr == 'true';
      if (lastUser != null && lastUser == _adminUsername) {
        _loggedUser = const AppUser(
          username: _adminUsername,
          password: _adminPassword,
          isAdmin: true,
          canManageUsers: true,
          canManageAssets: true,
          canReportFailure: true,
        );
      }
      if (theme == 'dark') {
        _themeMode = ThemeMode.dark;
      }
      if (langCode != null) {
        _language = AppStrings.supportedLanguageLocales.entries
                .firstWhere(
                  (e) => e.value.languageCode == langCode,
                  orElse: () =>
                      const MapEntry(AppLanguage.en, Locale('en')),
                )
                .key;
      }
      if (scale == 'large') {
        _uiScale = AppUiScale.large;
      } else if (scale == 'largest') {
        _uiScale = AppUiScale.largest;
      }
      _isLoadingPrefs = false;
    });

    if (_loggedUser == null && lastUser != null) {
      final existing = await _dbHelper.getUserByUsername(lastUser);
      if (!mounted || existing == null) {
        return;
      }
      setState(() {
        _loggedUser = existing;
      });
    }
  }

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    _saveUserPrefs();
  }

  void _changeLanguage(AppLanguage language) {
    setState(() {
      _language = language;
    });
    _saveUserPrefs();
  }

  void _changeUiScale(AppUiScale scale) {
    setState(() {
      _uiScale = scale;
    });
    _saveUserPrefs();
  }

  void _togglePcMode(bool enabled) {
    setState(() {
      _isPcMode = enabled;
    });
    _saveUserPrefs();
  }

  Future<bool> _login(String username, String password) async {
    if (username == _adminUsername && password == _adminPassword) {
      setState(() {
        _loggedUser = const AppUser(
          username: _adminUsername,
          password: _adminPassword,
          isAdmin: true,
          canManageUsers: true,
          canManageAssets: true,
          canReportFailure: true,
        );
      });
      await _saveUserPrefs();
      return true;
    }

    final existing = await _dbHelper.getUserByUsername(username);
    if (existing == null || existing.password != password) {
      return false;
    }

    setState(() {
      _loggedUser = existing;
    });
    await _saveUserPrefs();
    return true;
  }

  void _logout() {
    setState(() {
      _loggedUser = null;
    });
    _saveUserPrefs(clearUser: true);
  }

  Future<void> _saveUserPrefs({bool clearUser = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (clearUser) {
      await prefs.remove('lastUser');
      await _dbHelper.saveGlobalSetting('lastUser', '');
    } else {
      if (_loggedUser != null) {
        await prefs.setString('lastUser', _loggedUser!.username);
        await _dbHelper.saveGlobalSetting('lastUser', _loggedUser!.username);
      }
    }
    
    final themeStr = _themeMode == ThemeMode.dark ? 'dark' : 'light';
    await prefs.setString('globalTheme', themeStr);
    await _dbHelper.saveGlobalSetting('globalTheme', themeStr);

    final locale = AppStrings.supportedLanguageLocales[_language]!;
    await prefs.setString('globalLanguage', locale.languageCode);
    await _dbHelper.saveGlobalSetting('globalLanguage', locale.languageCode);

    await prefs.setBool('globalPcMode', _isPcMode);
    await _dbHelper.saveGlobalSetting('globalPcMode', _isPcMode.toString());

    final scaleStr = _uiScale == AppUiScale.normal
        ? 'normal'
        : _uiScale == AppUiScale.large
            ? 'large'
            : 'largest';
    await prefs.setString('globalUiScale', scaleStr);
    await _dbHelper.saveGlobalSetting('globalUiScale', scaleStr);
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppStrings.supportedLanguageLocales[_language]!;
    final strings = AppStrings(locale);

    if (_isLoadingPrefs) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    double textScaleFactor;
    switch (_uiScale) {
      case AppUiScale.normal:
        textScaleFactor = 1.0;
        break;
      case AppUiScale.large:
        textScaleFactor = 1.15;
        break;
      case AppUiScale.largest:
        textScaleFactor = 1.3;
        break;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: strings.t('appTitle'),
      locale: locale,
      supportedLocales: AppStrings.supportedLocales(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: Typography.englishLike2018.apply(
          fontSizeFactor: textScaleFactor,
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: Typography.englishLike2018.apply(
          fontSizeFactor: textScaleFactor,
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      themeMode: _themeMode,
      home: _loggedUser == null
          ? LoginScreen(
              strings: strings,
              currentThemeMode: _themeMode,
              currentLanguage: _language,
              currentUiScale: _uiScale,
              onToggleThemeMode: _toggleThemeMode,
              onChangeLanguage: _changeLanguage,
              onChangeUiScale: _changeUiScale,
              onLogin: _login,
            )
          : HomeScreen(
              strings: strings,
              currentUsername: _loggedUser!.username,
              isAdmin: _loggedUser!.isAdmin,
              canManageUsers: _loggedUser!.canManageUsers,
              canReportFailure: _loggedUser!.canReportFailure,
              onLogout: _logout,
              currentThemeMode: _themeMode,
              currentLanguage: _language,
              currentUiScale: _uiScale,
              isPcMode: _isPcMode,
              onToggleThemeMode: _toggleThemeMode,
              onChangeLanguage: _changeLanguage,
              onChangeUiScale: _changeUiScale,
              onTogglePcMode: _togglePcMode,
            ),
    );
  }
}
