import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_user.dart';
import '../models/asset.dart';

class DBHelper {
  DBHelper._internal();

  static final DBHelper instance = DBHelper._internal();
  static Database? _database;
  static Completer<Database>? _initCompleter;
  static String? _dbPath; // Cache path for logging

  static final List<Map<String, dynamic>> _webAssets = <Map<String, dynamic>>[];
  static final List<Map<String, dynamic>> _webUsers = <Map<String, dynamic>>[];
  static final List<Map<String, dynamic>> _webFailureReports =
      <Map<String, dynamic>>[];
  static int _webAssetId = 1;
  static int _webUserId = 1;
  static int _webFailureId = 1;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite unavailable on web');
    }
    
    if (_database != null) {
      return _database!;
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _initCompleter!.complete(_database!);
      return _database!;
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    String path;
    const dbName = 'ultimo_cmms.db';
    
    if (!kIsWeb && Platform.isWindows) {
      // On Windows, use the specific folder requested by the user on D: drive
      final newDir = Directory('D:\\Users\\CMMS LCS CLEAN\\database\\sqlite');
      if (!await newDir.exists()) {
        try {
          await newDir.create(recursive: true);
          debugPrint('DEBUG: Created database directory: ${newDir.path}');
        } catch (e) {
          debugPrint('DEBUG: Failed to create D: directory: $e. Falling back to local documents.');
          final localDir = await getApplicationDocumentsDirectory();
          path = join(localDir.path, dbName);
          return _openAndVerify(path);
        }
      }
      path = join(newDir.path, dbName);
    } else {
      // On mobile or other desktop, use standard database path
      final dbPath = await getDatabasesPath();
      path = join(dbPath, dbName);
    }
    
    return _openAndVerify(path);
  }

  Future<Database> _openAndVerify(String path) async {
    _dbPath = path;
    debugPrint('DEBUG: Opening database at: $path');
    
    final db = await openDatabase(
      path,
      version: 22,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        debugPrint('DEBUG: onCreate triggered for version $version');
        // Schema will be verified/created in _verifySchema after opening
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('DEBUG: onUpgrade triggered from $oldVersion to $newVersion');
        await _performUpgrade(db, oldVersion, newVersion);
      },
    );

    // CRITICAL: Post-initialization check to ensure ALL tables exist
    // This catches cases where onCreate/onUpgrade might have been bypassed or failed
    await _verifySchema(db);
    
    return db;
  }

  Future<void> _verifySchema(Database db) async {
    debugPrint('DEBUG: Verifying database schema...');
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tableNames = tables.map((t) => t['name'] as String).toList();
    debugPrint('DEBUG: Existing tables: $tableNames');

    if (!tableNames.contains('tasks')) {
      debugPrint('DEBUG: Table tasks MISSING! Creating now...');
      await _ensureTasksTableExists(db);
    } else {
      // Verify tasks columns
      final info = await db.rawQuery('PRAGMA table_info(tasks)');
      final columns = info.map((c) => c['name'] as String).toList();
      if (!columns.contains('failure_id')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN failure_id INTEGER');
      }
      if (!columns.contains('progress')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN progress REAL DEFAULT 0.0');
      }
    }

    if (!tableNames.contains('users')) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          is_admin INTEGER NOT NULL DEFAULT 0,
          can_manage_users INTEGER NOT NULL DEFAULT 0,
          can_manage_assets INTEGER NOT NULL DEFAULT 1,
          can_report_failure INTEGER NOT NULL DEFAULT 1,
          is_online INTEGER NOT NULL DEFAULT 0,
          rola TEXT NOT NULL DEFAULT "Użytkownik"
        )
      ''');
    }

    // Verify fault_options table
    if (!tableNames.contains('fault_options')) {
      await db.execute('''
        CREATE TABLE fault_options (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL,
          value TEXT NOT NULL,
          UNIQUE(category, value)
        )
      ''');
      // Seed initial values
      final initialOptions = [
        {'category': 'priority', 'value': 'Low'},
        {'category': 'priority', 'value': 'Medium'},
        {'category': 'priority', 'value': 'High'},
        {'category': 'priority', 'value': 'Critical'},
        {'category': 'location', 'value': 'Kartransport'},
        {'category': 'location', 'value': 'Rekjesband'},
        {'category': 'location', 'value': 'Invoerrobot'},
        {'category': 'location', 'value': 'Uitvoerrobot'},
        {'category': 'location', 'value': 'Other'},
        {'category': 'root_cause', 'value': 'Mechanical Failure'},
        {'category': 'root_cause', 'value': 'Electrical Issue'},
        {'category': 'root_cause', 'value': 'Operator Error'},
        {'category': 'root_cause', 'value': 'Wear and Tear'},
      ];
      for (var opt in initialOptions) {
        await db.insert('fault_options', opt);
      }
    }

    // Verify production_entries columns
    if (tableNames.contains('production_entries')) {
      final info = await db.rawQuery('PRAGMA table_info(production_entries)');
      final columns = info.map((c) => c['name'] as String).toList();
      if (!columns.contains('barrel_count')) {
        await db.execute('ALTER TABLE production_entries ADD COLUMN barrel_count INTEGER DEFAULT 0');
      }
    }

    // Verify saved_barrel_types columns
    if (tableNames.contains('saved_barrel_types')) {
      final info = await db.rawQuery('PRAGMA table_info(saved_barrel_types)');
      final columns = info.map((c) => c['name'] as String).toList();
      if (!columns.contains('multiplier')) {
        await db.execute('ALTER TABLE saved_barrel_types ADD COLUMN multiplier INTEGER DEFAULT 1');
      }
    }

    // Add more table checks as needed
    if (!tableNames.contains('tile_visibility')) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tile_visibility (
          tile_id TEXT PRIMARY KEY,
          is_visible INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  Future<void> _performUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 22) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tile_visibility (
          tile_id TEXT PRIMARY KEY,
          is_visible INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          is_admin INTEGER NOT NULL DEFAULT 0,
          can_manage_users INTEGER NOT NULL DEFAULT 0,
          can_manage_assets INTEGER NOT NULL DEFAULT 1,
          can_report_failure INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS failure_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          opis TEXT NOT NULL,
          lokalizacja TEXT NOT NULL,
          linia TEXT NOT NULL,
          czy_rozwiazane INTEGER NOT NULL DEFAULT 0,
          czas_trwania TEXT,
          co_naprawiono TEXT,
          kto_naprawil TEXT,
          zdjecie_sciezka TEXT,
          created_by TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE failure_reports ADD COLUMN powod TEXT');
      await db.execute('ALTER TABLE failure_reports ADD COLUMN priorytet TEXT');
      await db.execute('ALTER TABLE failure_reports ADD COLUMN status TEXT');
      await db.execute('ALTER TABLE failure_reports ADD COLUMN data_rozpoczecia_naprawy TEXT');
      await db.execute('ALTER TABLE failure_reports ADD COLUMN data_zakonczenia_naprawy TEXT');
      await db.execute('ALTER TABLE failure_reports ADD COLUMN unique_id TEXT');
      await db.execute('ALTER TABLE failure_reports ADD COLUMN downtime_minutes INTEGER');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE assets ADD COLUMN dokumentacja TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN is_online INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE users ADD COLUMN rola TEXT NOT NULL DEFAULT "Użytkownik"');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS warehouse_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          code TEXT NOT NULL UNIQUE,
          quantity INTEGER NOT NULL DEFAULT 0,
          location TEXT,
          category TEXT,
          min_quantity INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schedule_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          date TEXT NOT NULL,
          shift TEXT NOT NULL, -- Morning, Afternoon, Night
          color_hex TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL,
          color_hex TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_downtime (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          line_name TEXT NOT NULL,
          operator_name TEXT NOT NULL,
          date TEXT NOT NULL,
          reason TEXT NOT NULL,
          minutes INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
         )
       ''');
     }
     if (oldVersion < 8) {
       await db.execute('ALTER TABLE production_downtime ADD COLUMN shift TEXT');
       await db.execute('ALTER TABLE production_downtime ADD COLUMN barrels_water INTEGER DEFAULT 0');
       await db.execute('ALTER TABLE production_downtime ADD COLUMN cameras_cleaned INTEGER DEFAULT 0');
     }
     if (oldVersion < 9) {
       await db.execute('ALTER TABLE production_downtime ADD COLUMN defective_carts INTEGER DEFAULT 0');
       await db.execute('ALTER TABLE production_downtime ADD COLUMN causes TEXT');
     }
     if (oldVersion < 10) {
        await db.execute('ALTER TABLE failure_reports ADD COLUMN zdjecie_blob BLOB');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS global_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      }
      if (oldVersion < 11) {
        await db.execute('ALTER TABLE production_downtime ADD COLUMN start_time TEXT');
        await db.execute('ALTER TABLE production_downtime ADD COLUMN end_time TEXT');
      }
      if (oldVersion < 12) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            type TEXT NOT NULL,
            date_start TEXT,
            date_end TEXT,
            priority TEXT NOT NULL,
            label TEXT,
            created_at TEXT NOT NULL,
            created_by TEXT,
            progress REAL DEFAULT 0.0
          )
        ''');
      }
      if (oldVersion < 13) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS emergency_numbers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            number TEXT NOT NULL,
            category TEXT,
            priority TEXT,
            created_at TEXT NOT NULL,
            created_by TEXT
          )
        ''');
      }
      if (oldVersion < 14) {
        await db.execute('ALTER TABLE tasks ADD COLUMN failure_id INTEGER');
      }
      if (oldVersion < 15) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            line TEXT NOT NULL,
            shift TEXT NOT NULL,
            operator_names TEXT,
            barrels_empty INTEGER DEFAULT 0,
            machine_clean INTEGER DEFAULT 0,
            nozzles_pierced INTEGER DEFAULT 0,
            comments TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_id INTEGER NOT NULL,
            fust_type TEXT,
            start_time TEXT,
            end_time TEXT,
            pause_minutes INTEGER DEFAULT 0,
            cart_count INTEGER DEFAULT 0,
            FOREIGN KEY (report_id) REFERENCES production_reports (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS chlorine_measurements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_id INTEGER NOT NULL,
            measurement_time TEXT,
            chlorine_level REAL,
            FOREIGN KEY (report_id) REFERENCES production_reports (id) ON DELETE CASCADE
          )
        ''');
      }
      if (oldVersion < 16) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS saved_names (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
          )
        ''');
      }
      if (oldVersion < 17) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS saved_barrel_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
          )
        ''');
      }
      if (oldVersion < 19) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_id INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (report_id) REFERENCES production_reports (id) ON DELETE CASCADE
          )
        ''');
      }
      if (oldVersion < 20) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS finalized_production_lists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operator_name TEXT NOT NULL,
            date TEXT NOT NULL,
            line_name TEXT NOT NULL,
            shift TEXT NOT NULL,
            report_data TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      }
      if (oldVersion < 21) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_report_draft (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            draft_data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      }
    if (oldVersion < 23) {
      await db.execute('ALTER TABLE tile_visibility ADD COLUMN sort_order INTEGER DEFAULT 0');
    }
  }

  Future<void> _createTables(Database db) async {
      await db.execute('''
        CREATE TABLE assets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nazwa TEXT NOT NULL,
          kod TEXT NOT NULL,
          lokalizacja TEXT NOT NULL,
          opis TEXT,
          dokumentacja TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE work_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tytul TEXT NOT NULL,
          opis TEXT,
          status TEXT NOT NULL,
          asset_id INTEGER NOT NULL,
          FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          is_admin INTEGER NOT NULL DEFAULT 0,
          can_manage_users INTEGER NOT NULL DEFAULT 0,
          can_manage_assets INTEGER NOT NULL DEFAULT 1,
          can_report_failure INTEGER NOT NULL DEFAULT 1,
          is_online INTEGER NOT NULL DEFAULT 0,
          rola TEXT NOT NULL DEFAULT "Użytkownik"
        )
      ''');

      await db.execute('''
        CREATE TABLE failure_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          opis TEXT NOT NULL,
          lokalizacja TEXT NOT NULL,
          linia TEXT NOT NULL,
          czy_rozwiazane INTEGER NOT NULL DEFAULT 0,
          czas_trwania TEXT,
          co_naprawiono TEXT,
          kto_naprawil TEXT,
          zdjecie_sciezka TEXT,
          zdjecie_blob BLOB,
          created_by TEXT NOT NULL,
          created_at TEXT NOT NULL,
          powod TEXT,
          priorytet TEXT,
          status TEXT,
          data_rozpoczecia_naprawy TEXT,
          data_zakonczenia_naprawy TEXT,
          unique_id TEXT,
          downtime_minutes INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE warehouse_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          code TEXT NOT NULL UNIQUE,
          quantity INTEGER NOT NULL DEFAULT 0,
          location TEXT,
          category TEXT,
          min_quantity INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE schedule_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          date TEXT NOT NULL,
          shift TEXT NOT NULL,
          color_hex TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL,
          color_hex TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_downtime (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          line_name TEXT NOT NULL,
          operator_name TEXT NOT NULL,
          date TEXT NOT NULL,
          reason TEXT NOT NULL,
          minutes INTEGER NOT NULL DEFAULT 0,
          shift TEXT,
          barrels_water INTEGER DEFAULT 0,
          cameras_cleaned INTEGER DEFAULT 0,
          defective_carts INTEGER DEFAULT 0,
          causes TEXT,
          start_time TEXT,
          end_time TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS global_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          status TEXT NOT NULL,
          type TEXT NOT NULL,
          date_start TEXT,
          date_end TEXT,
          priority TEXT NOT NULL,
          label TEXT,
          created_at TEXT NOT NULL,
          created_by TEXT,
          progress REAL DEFAULT 0.0,
          failure_id INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS emergency_numbers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          number TEXT NOT NULL,
          category TEXT,
          priority TEXT,
          created_at TEXT NOT NULL,
          created_by TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          line TEXT NOT NULL,
          shift TEXT NOT NULL,
          operator_names TEXT,
          barrels_empty INTEGER DEFAULT 0,
          machine_clean INTEGER DEFAULT 0,
          nozzles_pierced INTEGER DEFAULT 0,
          comments TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_id INTEGER NOT NULL,
          fust_type TEXT,
          start_time TEXT,
          end_time TEXT,
          pause_minutes INTEGER DEFAULT 0,
          cart_count INTEGER DEFAULT 0,
          barrel_count INTEGER DEFAULT 0,
          FOREIGN KEY (report_id) REFERENCES production_reports (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS chlorine_measurements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_id INTEGER NOT NULL,
          measurement_time TEXT,
          chlorine_level REAL,
          FOREIGN KEY (report_id) REFERENCES production_reports (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS saved_names (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS saved_barrel_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          multiplier INTEGER DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_documents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_id INTEGER NOT NULL,
          file_name TEXT NOT NULL,
          file_path TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (report_id) REFERENCES production_reports (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS finalized_production_lists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operator_name TEXT NOT NULL,
          date TEXT NOT NULL,
          line_name TEXT NOT NULL,
          shift TEXT NOT NULL,
          report_data TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }

    Future<void> _backupTable(String tableName, String moduleName) async {
    if (kIsWeb) return;
    try {
      final db = await database;
      final data = await db.query(tableName);
      final jsonStr = jsonEncode(data);
      await saveModuleBackup(moduleName, '${tableName}_backup.json', jsonStr);
    } catch (e) {
      debugPrint('Backup failed for $tableName: $e');
    }
  }

  // Finalized Production List methods
  Future<int> insertFinalizedProductionList(Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final db = await database;
    final res = await db.insert('finalized_production_lists', data);
    _backupTable('finalized_production_lists', 'documents');
    return res;
  }

  Future<List<Map<String, dynamic>>> getFinalizedProductionLists({String? query}) async {
    if (kIsWeb) return [];
    final db = await database;
    
    String? where;
    List<dynamic>? whereArgs;
    
    if (query != null && query.isNotEmpty) {
      where = 'operator_name LIKE ? OR line_name LIKE ? OR shift LIKE ? OR date LIKE ?';
      whereArgs = ['%$query%', '%$query%', '%$query%', '%$query%'];
    }
    
    return db.query(
      'finalized_production_lists',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteFinalizedProductionList(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('finalized_production_lists', where: 'id = ?', whereArgs: [id]);
    _backupTable('finalized_production_lists', 'documents');
  }

  // Production Report Draft methods
  Future<void> saveProductionReportDraft(String draftData) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'production_report_draft',
      {
        'id': 1,
        'draft_data': draftData,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getProductionReportDraft() async {
    if (kIsWeb) return null;
    final db = await database;
    final res = await db.query('production_report_draft', where: 'id = 1');
    if (res.isNotEmpty) {
      return res.first['draft_data'] as String;
    }
    return null;
  }

  Future<void> clearProductionReportDraft() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('production_report_draft', where: 'id = 1');
  }

  // Folder helpers
  Future<String> getModuleFolder(String moduleName) async {
    if (kIsWeb) return '';
    final baseDir = 'D:\\Users\\CMMS LCS CLEAN\\database';
    final moduleDir = Directory(join(baseDir, moduleName));
    if (!await moduleDir.exists()) {
      await moduleDir.create(recursive: true);
    }
    return moduleDir.path;
  }

  Future<void> saveModuleBackup(String moduleName, String fileName, String content) async {
    if (kIsWeb) return;
    try {
      final folder = await getModuleFolder(moduleName);
      final file = File(join(folder, fileName));
      await file.writeAsString(content);
      debugPrint('Backup saved: ${file.path}');
    } catch (e) {
      debugPrint('Backup failed for $moduleName: $e');
    }
  }

  // Settings methods
  Future<void> saveGlobalSetting(String key, String value) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'global_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _backupTable('global_settings', 'settings');
  }

  Future<String?> getGlobalSetting(String key) async {
    if (kIsWeb) return null;
    final db = await database;
    final res = await db.query(
      'global_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['value'] as String?;
  }

  // Production Downtime methods
  Future<void> batchInsertOrUpdateProductionDowntime(List<Map<String, dynamic>> entries) async {
    if (kIsWeb || entries.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (var data in entries) {
        // Match by line, operator, reason, shift AND date
        final existing = await txn.query(
          'production_downtime',
          where: 'line_name = ? AND operator_name = ? AND reason = ? AND shift = ? AND date = ?',
          whereArgs: [data['line_name'], data['operator_name'], data['reason'], data['shift'], data['date']],
          orderBy: 'created_at DESC',
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final id = existing.first['id'] as int;
          final updateData = Map<String, dynamic>.from(data);
          updateData.remove('created_at');
          updateData.remove('id');
          
          await txn.update(
            'production_downtime',
            updateData,
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await txn.insert('production_downtime', data);
        }
      }
    });
    _backupTable('production_downtime', 'production_list');
  }

  Future<void> deleteProductionDowntime(int id) async {
    if (kIsWeb) return;
    final db = await database;
    
    // Fetch the entry first to find its unique_id in failure_reports
    final entry = await db.query('production_downtime', where: 'id = ?', whereArgs: [id]);
    if (entry.isNotEmpty) {
      final line = entry.first['line_name'];
      final date = entry.first['date'];
      final reason = entry.first['reason'];
      final shift = entry.first['shift'];
      final syncId = 'PL-$line-$date-$reason-$shift';
      
      // Delete from failure_reports too
      await db.delete('failure_reports', where: 'unique_id = ?', whereArgs: [syncId]);
    }

    await db.delete('production_downtime', where: 'id = ?', whereArgs: [id]);
    _backupTable('production_downtime', 'production_list');
    _backupTable('failure_reports', 'failures');
  }

  Future<void> deleteCompleteProductionReport(String lineName, String shift, String date) async {
    if (kIsWeb) return;
    final db = await database;
    
    // 1. Delete from production_downtime
    await db.delete(
      'production_downtime',
      where: 'line_name = ? AND shift = ? AND date = ?',
      whereArgs: [lineName, shift, date],
    );

    // 2. Also delete from failure_reports to keep them in sync
    // The unique_id pattern is 'PL-${lineName}-${date}-${reason}-${shift}'
    // We can use a LIKE query or delete where parts match
    await db.delete(
      'failure_reports',
      where: 'unique_id LIKE ?',
      whereArgs: ['PL-$lineName-$date-%-$shift'],
    );

    _backupTable('production_downtime', 'production_list');
    _backupTable('failure_reports', 'failures');
  }

  // Task methods
  Future<int> insertTask(Map<String, dynamic> task) async {
    if (kIsWeb) return 0;
    try {
      final db = await database;
      
      // Safety check for tasks table
      try {
        final tableInfo = await db.rawQuery('PRAGMA table_info(tasks)');
        if (tableInfo.isEmpty) {
          await _ensureTasksTableExists(db);
        } else {
          final columns = tableInfo.map((c) => c['name'] as String).toList();
          if (!columns.contains('failure_id')) {
            await db.execute('ALTER TABLE tasks ADD COLUMN failure_id INTEGER');
          }
          if (!columns.contains('progress')) {
            await db.execute('ALTER TABLE tasks ADD COLUMN progress REAL DEFAULT 0.0');
          }
        }
      } catch (e) {
        await _ensureTasksTableExists(db);
      }
      
      final res = await db.insert('tasks', task);
      debugPrint('DEBUG: Task inserted with ID: $res, Data: $task');
      _backupTable('tasks', 'tasks');
      return res;
    } catch (e) {
      debugPrint('DEBUG: Error inserting task: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTasks({String? status, String? query}) async {
    if (kIsWeb) return [];
    try {
      final db = await database;
      
      debugPrint('DEBUG: getTasks called with status: $status, query: $query');
      
      // Safety check: Ensure the table exists and has all columns
      try {
        final tableInfo = await db.rawQuery('PRAGMA table_info(tasks)');
        if (tableInfo.isEmpty) {
          debugPrint('DEBUG: Table tasks does not exist, creating...');
          await _ensureTasksTableExists(db);
        } else {
          final columns = tableInfo.map((c) => c['name'] as String).toList();
          debugPrint('DEBUG: tasks table columns: $columns');
          if (!columns.contains('failure_id')) {
            debugPrint('DEBUG: Adding missing failure_id column...');
            await db.execute('ALTER TABLE tasks ADD COLUMN failure_id INTEGER');
          }
          if (!columns.contains('progress')) {
            debugPrint('DEBUG: Adding missing progress column...');
            await db.execute('ALTER TABLE tasks ADD COLUMN progress REAL DEFAULT 0.0');
          }
        }
      } catch (e) {
        debugPrint('DEBUG: Schema check failed: $e');
        await _ensureTasksTableExists(db);
      }

      String? where;
      List<dynamic>? whereArgs;
      
      // Robust status matching: handle both Polish and English or ignore if 'Wszystkie'/'All'
      if (status != null && status != 'Wszystkie' && status != 'All' && status.isNotEmpty) {
        if (status == 'active') {
          where = "status NOT IN ('Zrealizowane', 'Anulowane', 'Completed', 'Cancelled')";
          whereArgs = [];
        } else if (status == 'history') {
          where = "status IN ('Zrealizowane', 'Anulowane', 'Completed', 'Cancelled')";
          whereArgs = [];
        } else {
          where = 'status = ?';
          whereArgs = [status];
        }
        debugPrint('DEBUG: Applying status filter: $status');
      }
      
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim();
        final queryWhere = '(title LIKE ? OR label LIKE ? OR type LIKE ?)';
        final queryArgs = ['%$q%', '%$q%', '%$q%'];
        if (where == null) {
          where = queryWhere;
          whereArgs = queryArgs;
        } else {
          where = '$where AND $queryWhere';
          whereArgs!.addAll(queryArgs);
        }
        debugPrint('DEBUG: Applying search query: $query');
      }
      
      final results = await db.query('tasks', where: where, whereArgs: whereArgs, orderBy: 'created_at DESC');
      
      // Log all tasks if results are empty to see what's actually in there
      if (results.isEmpty && (status != null || query != null)) {
        final allTasks = await db.query('tasks');
        debugPrint('DEBUG: getTasks returned 0 results, but total tasks in DB: ${allTasks.length}');
        if (allTasks.isNotEmpty) {
          debugPrint('DEBUG: Sample task status: ${allTasks.first['status']}');
        }
      }
      
      debugPrint('DEBUG: getTasks found ${results.length} tasks in database');
      return results;
    } catch (e) {
      debugPrint('DEBUG: Error in getTasks: $e');
      return [];
    }
  }

  Future<void> _ensureTasksTableExists(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        type TEXT NOT NULL,
        date_start TEXT,
        date_end TEXT,
        priority TEXT NOT NULL,
        label TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        progress REAL DEFAULT 0.0,
        failure_id INTEGER
      )
    ''');
  }

  Future<void> updateTask(int id, Map<String, dynamic> task) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('tasks', task, where: 'id = ?', whereArgs: [id]);
    _backupTable('tasks', 'tasks');
  }

  Future<void> updateTaskByFailureId(int failureId, Map<String, dynamic> task) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('tasks', task, where: 'failure_id = ?', whereArgs: [failureId]);
    _backupTable('tasks', 'tasks');
  }

  Future<void> deleteTaskByFailureId(int failureId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('tasks', where: 'failure_id = ?', whereArgs: [failureId]);
    _backupTable('tasks', 'tasks');
  }

  Future<void> deleteTask(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    _backupTable('tasks', 'tasks');
  }

  Future<int> insertOrUpdateProductionDowntime(Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final db = await database;
    
    // Check if entry exists for this line, operator, reason, shift on the same date
    // We no longer restrict by 12h window to allow finalization at any time
    final existing = await db.query(
      'production_downtime',
      where: 'line_name = ? AND operator_name = ? AND reason = ? AND shift = ? AND date = ?',
      whereArgs: [data['line_name'], data['operator_name'], data['reason'], data['shift'], data['date']],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      final currentMinutes = existing.first['minutes'] as int;
      final updateData = Map<String, dynamic>.from(data);
      
      // If absolute_minutes is provided, use it instead of incrementing
      if (data.containsKey('absolute_minutes')) {
        updateData['minutes'] = data['absolute_minutes'];
        updateData.remove('absolute_minutes');
      } else {
        updateData['minutes'] = currentMinutes + (data['minutes'] as int);
      }
      
      // Keep the original created_at to stay within the session window
      updateData.remove('created_at');
      updateData.remove('id');
      
      final res = await db.update(
        'production_downtime',
        updateData,
        where: 'id = ?',
        whereArgs: [id],
      );
      _backupTable('production_downtime', 'production_list');
      return res;
    } else {
      final insertData = Map<String, dynamic>.from(data);
      if (insertData.containsKey('absolute_minutes')) {
        insertData['minutes'] = insertData['absolute_minutes'];
        insertData.remove('absolute_minutes');
      }
      final res = await db.insert('production_downtime', insertData);
      _backupTable('production_downtime', 'production_list');
      return res;
    }
  }

  Future<List<Map<String, dynamic>>> getProductionDowntime(
    String date, {
    String? lineName,
    String? shift,
    String? operatorName,
    bool last8Hours = false,
  }) async {
    if (kIsWeb) return [];
    final db = await database;

    if (last8Hours) {
      // Get data for the selected date and criteria. 
      // We no longer restrict by a 12h window to allow finalization at any time.
      String where = '1=1';
      List<dynamic> whereArgs = [];

      if (date != null && date.isNotEmpty) {
        where += ' AND date = ?';
        whereArgs.add(date);
      }
      if (lineName != null && lineName.isNotEmpty) {
        where += ' AND line_name = ?';
        whereArgs.add(lineName);
      }
      if (shift != null && shift.isNotEmpty) {
        where += ' AND shift = ?';
        whereArgs.add(shift);
      }
      if (operatorName != null && operatorName.isNotEmpty) {
        where += ' AND operator_name = ?';
        whereArgs.add(operatorName);
      }

      return db.query(
        'production_downtime',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'created_at ASC',
      );
    } else {
      // Original date-based logic for history
      String where = 'date = ?';
      List<dynamic> whereArgs = [date];

      if (lineName != null && lineName.isNotEmpty) {
        where += ' AND line_name = ?';
        whereArgs.add(lineName);
      }
      if (shift != null && shift.isNotEmpty) {
        where += ' AND shift = ?';
        whereArgs.add(shift);
      }
      if (operatorName != null && operatorName.isNotEmpty) {
        where += ' AND operator_name = ?';
        whereArgs.add(operatorName);
      }

      return db.query(
        'production_downtime',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );
    }
  }

  Future<List<String>> getProductionOperators() async {
    if (kIsWeb) return [];
    final db = await database;
    final res = await db.rawQuery('SELECT DISTINCT operator_name FROM production_downtime');
    return res.map((e) => e['operator_name'] as String).toList();
  }

  // New Production Report methods
  Future<int> insertProductionReport(Map<String, dynamic> report, List<Map<String, dynamic>> entries, List<Map<String, dynamic>> measurements) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db.transaction((txn) async {
      final reportId = await txn.insert('production_reports', report);
      for (var entry in entries) {
        entry['report_id'] = reportId;
        await txn.insert('production_entries', entry);
      }
      for (var measurement in measurements) {
        measurement['report_id'] = reportId;
        await txn.insert('chlorine_measurements', measurement);
      }
      return reportId;
    });
  }

  Future<List<Map<String, dynamic>>> getProductionReports() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.rawQuery('''
      SELECT pr.*, GROUP_CONCAT(DISTINCT pe.fust_type) as barrel_types
      FROM production_reports pr
      LEFT JOIN production_entries pe ON pr.id = pe.report_id
      GROUP BY pr.id
      ORDER BY pr.created_at DESC
    ''');
  }

  Future<void> deleteProductionReport(int reportId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('chlorine_measurements', where: 'report_id = ?', whereArgs: [reportId]);
      await txn.delete('production_entries', where: 'report_id = ?', whereArgs: [reportId]);
      await txn.delete('production_reports', where: 'id = ?', whereArgs: [reportId]);
    });
  }

  Future<Map<String, dynamic>> getProductionReportDetails(int reportId) async {
    if (kIsWeb) return {};
    final db = await database;
    final report = await db.query('production_reports', where: 'id = ?', whereArgs: [reportId]);
    final entries = await db.query('production_entries', where: 'report_id = ?', whereArgs: [reportId]);
    final measurements = await db.query('chlorine_measurements', where: 'report_id = ?', whereArgs: [reportId]);
    
    return {
      'report': report.first,
      'entries': entries,
      'measurements': measurements,
    };
  }

  // Saved Names methods
  Future<int> insertSavedName(String name) async {
    if (kIsWeb) return 0;
    final db = await database;
    try {
      return await db.insert('saved_names', {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Name might already exist (UNIQUE constraint)
      return 0;
    }
  }

  Future<List<String>> getSavedNames() async {
    if (kIsWeb) return [];
    final db = await database;
    final res = await db.query('saved_names', orderBy: 'name ASC');
    return res.map((e) => e['name'] as String).toList();
  }

  Future<void> deleteSavedName(String name) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('saved_names', where: 'name = ?', whereArgs: [name]);
  }

  Future<void> updateSavedName(String oldName, String newName) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'saved_names',
      {'name': newName},
      where: 'name = ?',
      whereArgs: [oldName],
    );
  }

  // Saved Barrel Types methods
  Future<int> insertSavedBarrelType(String name, int multiplier) async {
    if (kIsWeb) return 0;
    final db = await database;
    try {
      return await db.insert('saved_barrel_types', {
        'name': name,
        'multiplier': multiplier,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getSavedBarrelTypes() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query('saved_barrel_types', orderBy: 'name ASC');
  }

  Future<void> deleteSavedBarrelType(String name) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('saved_barrel_types', where: 'name = ?', whereArgs: [name]);
  }

  Future<void> updateSavedBarrelType(String oldName, String newName, int multiplier) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'saved_barrel_types',
      {'name': newName, 'multiplier': multiplier},
      where: 'name = ?',
      whereArgs: [oldName],
    );
  }

  // Tile Visibility methods
  Future<void> setTileVisibility(String tileId, bool isVisible) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'tile_visibility',
      {
        'tile_id': tileId,
        'is_visible': isVisible ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isTileVisible(String tileId) async {
    if (kIsWeb) return true;
    final db = await database;
    final res = await db.query('tile_visibility', where: 'tile_id = ?', whereArgs: [tileId]);
    if (res.isNotEmpty) {
      return res.first['is_visible'] == 1;
    }
    return true; // Domyślnie widoczne
  }

  Future<Map<String, bool>> getAllTileVisibility() async {
    if (kIsWeb) return {};
    final db = await database;
    final res = await db.query('tile_visibility');
    final Map<String, bool> visibilityMap = {};
    for (var row in res) {
      visibilityMap[row['tile_id'] as String] = row['is_visible'] == 1;
    }
    return visibilityMap;
  }

  Future<Map<String, int>> getAllTileOrder() async {
    if (kIsWeb) return {};
    final db = await database;
    final res = await db.query('tile_visibility');
    final Map<String, int> orderMap = {};
    for (var row in res) {
      if (row['sort_order'] != null) {
        orderMap[row['tile_id'] as String] = row['sort_order'] as int;
      }
    }
    return orderMap;
  }

  Future<void> updateTileOrder(Map<String, int> orderMap) async {
    if (kIsWeb) return;
    final db = await database;
    await db.transaction((txn) async {
      for (var entry in orderMap.entries) {
        await txn.update(
          'tile_visibility',
          {'sort_order': entry.value},
          where: 'tile_id = ?',
          whereArgs: [entry.key],
        );
      }
    });
  }

  // Production Documents methods
  Future<int> insertProductionDocument(int reportId, String fileName, String filePath) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db.insert('production_documents', {
      'report_id': reportId,
      'file_name': fileName,
      'file_path': filePath,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getProductionDocuments() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query('production_documents', orderBy: 'created_at DESC');
  }

  Future<void> deleteProductionDocument(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('production_documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearActiveProductionDowntime(String date, String line, String shift, String operatorName) async {
    if (kIsWeb) return;
    final db = await database;
    // Delete by date AND by a recent time window to ensure everything is cleared
    // We also match operatorName to be safe
    final sessionThreshold = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
    await db.delete(
      'production_downtime',
      where: '(date = ? OR created_at >= ?) AND line_name = ? AND shift = ? AND (operator_name = ? OR operator_name LIKE ?)',
      whereArgs: [date, sessionThreshold, line, shift, operatorName, '%$operatorName%'],
    );
  }

  // Note methods
  Future<int> insertNote(Map<String, dynamic> note) async {
    if (kIsWeb) return 0;
    final db = await database;
    final res = await db.insert('notes', note);
    _backupTable('notes', 'notebook');
    return res;
  }

  Future<List<Map<String, dynamic>>> getNotes(String username) async {
    if (kIsWeb) return [];
    final db = await database;
    return db.query('notes', where: 'username = ?', whereArgs: [username], orderBy: 'created_at DESC');
  }

  Future<void> deleteNote(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    _backupTable('notes', 'notebook');
  }

  Future<void> updateNote(int id, Map<String, dynamic> note) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('notes', note, where: 'id = ?', whereArgs: [id]);
    _backupTable('notes', 'notebook');
  }

  // Emergency Numbers methods
  Future<int> insertEmergencyNumber(Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final db = await database;
    final res = await db.insert('emergency_numbers', data);
    _backupTable('emergency_numbers', 'emergency');
    return res;
  }

  Future<List<Map<String, dynamic>>> getEmergencyNumbers({String? query}) async {
    if (kIsWeb) return [];
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (query != null && query.isNotEmpty) {
      where = 'name LIKE ? OR number LIKE ? OR category LIKE ?';
      whereArgs = ['%$query%', '%$query%', '%$query%'];
    }
    return db.query('emergency_numbers', where: where, whereArgs: whereArgs, orderBy: 'priority DESC, name ASC');
  }

  Future<void> updateEmergencyNumber(int id, Map<String, dynamic> data) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('emergency_numbers', data, where: 'id = ?', whereArgs: [id]);
    _backupTable('emergency_numbers', 'emergency');
  }

  Future<void> deleteEmergencyNumber(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('emergency_numbers', where: 'id = ?', whereArgs: [id]);
    _backupTable('emergency_numbers', 'emergency');
  }

  Future<void> updateUser(AppUser user) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
    _backupTable('users', 'users');
  }

  Future<void> deleteUser(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
    _backupTable('users', 'users');
  }

  // Warehouse methods
  Future<int> insertWarehouseItem(Map<String, dynamic> item) async {
    if (kIsWeb) return 0;
    final db = await database;
    final res = await db.insert('warehouse_items', item);
    _backupTable('warehouse_items', 'warehouse');
    return res;
  }

  Future<List<Map<String, dynamic>>> getWarehouseItems() async {
    if (kIsWeb) return [];
    final db = await database;
    return db.query('warehouse_items', orderBy: 'name ASC');
  }

  Future<void> updateWarehouseItemQuantity(int id, int newQuantity) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('warehouse_items', {'quantity': newQuantity}, where: 'id = ?', whereArgs: [id]);
    _backupTable('warehouse_items', 'warehouse');
  }

  Future<void> updateWarehouseItem(int id, Map<String, dynamic> item) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('warehouse_items', item, where: 'id = ?', whereArgs: [id]);
    _backupTable('warehouse_items', 'warehouse');
  }

  Future<void> deleteWarehouseItem(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('warehouse_items', where: 'id = ?', whereArgs: [id]);
    _backupTable('warehouse_items', 'warehouse');
  }

  // Schedule methods
  Future<int> insertScheduleEntry(Map<String, dynamic> entry) async {
    if (kIsWeb) return 0;
    final db = await database;
    final res = await db.insert('schedule_entries', entry);
    _backupTable('schedule_entries', 'schedule');
    return res;
  }

  Future<List<Map<String, dynamic>>> getScheduleEntries(String month) async {
    if (kIsWeb) return [];
    final db = await database;
    return db.query('schedule_entries', where: "date LIKE ?", whereArgs: ['$month%']);
  }

  Future<void> updateScheduleEntry(int id, Map<String, dynamic> entry) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('schedule_entries', entry, where: 'id = ?', whereArgs: [id]);
    _backupTable('schedule_entries', 'schedule');
  }

  Future<void> deleteScheduleEntry(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('schedule_entries', where: 'id = ?', whereArgs: [id]);
    _backupTable('schedule_entries', 'schedule');
  }

  Future<void> setUserOnline(String username, bool online) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('users', {'is_online': online ? 1 : 0}, where: 'username = ?', whereArgs: [username]);
  }

  Future<List<Map<String, dynamic>>> getOnlineUsers() async {
    if (kIsWeb) return [];
    final db = await database;
    return db.query('users', where: 'is_online = 1');
  }

  Future<void> updateAssetDocumentation(int id, String docPath) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('assets', {'dokumentacja': docPath}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertAsset(Asset asset) async {
    if (kIsWeb) {
      final map = asset.toMap();
      map['id'] = _webAssetId++;
      _webAssets.add(map);
      return map['id'] as int;
    }
    final db = await database;
    debugPrint('Saving asset to database at: $_dbPath');
    final res = await db.insert('assets', asset.toMap());
    _backupTable('assets', 'machines');
    return res;
  }

  Future<List<Asset>> getAssets() async {
    if (kIsWeb) {
      return _webAssets.map(Asset.fromMap).toList();
    }
    final db = await database;
    final maps = await db.query('assets', orderBy: 'id DESC');
    return maps.map(Asset.fromMap).toList();
  }

  Future<void> updateAsset(Asset asset) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('assets', asset.toMap(), where: 'id = ?', whereArgs: [asset.id]);
    _backupTable('assets', 'machines');
  }

  Future<void> deleteAsset(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('assets', where: 'id = ?', whereArgs: [id]);
    _backupTable('assets', 'machines');
  }

  Future<int> insertUser(AppUser user) async {
    if (kIsWeb) {
      final map = user.toMap();
      map['id'] = _webUserId++;
      _webUsers.add(map);
      return map['id'] as int;
    }
    final db = await database;
    final res = await db.insert('users', user.toMap());
    _backupTable('users', 'users');
    return res;
  }

  Future<List<AppUser>> getUsers() async {
    if (kIsWeb) {
      final sorted = [..._webUsers]
        ..sort((a, b) => (a['username'] as String)
            .toLowerCase()
            .compareTo((b['username'] as String).toLowerCase()));
      return sorted.map(AppUser.fromMap).toList();
    }
    final db = await database;
    final maps = await db.query('users', orderBy: 'username ASC');
    return maps.map(AppUser.fromMap).toList();
  }

  Future<AppUser?> getUserByUsername(String username) async {
    if (kIsWeb) {
      try {
        final map = _webUsers.firstWhere(
          (u) =>
              (u['username'] as String).toLowerCase() == username.toLowerCase(),
        );
        return AppUser.fromMap(map);
      } catch (_) {
        return null;
      }
    }
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return AppUser.fromMap(maps.first);
  }

  Future<int> insertFailureReport(Map<String, dynamic> report) async {
    if (kIsWeb) {
      final map = Map<String, dynamic>.from(report);
      map['id'] = _webFailureId++;
      _webFailureReports.add(map);
      return map['id'] as int;
    }
    final db = await database;
    final res = await db.insert('failure_reports', report);
    _backupTable('failure_reports', 'failures');
    return res;
  }

  Future<int> updateFailureReport(int id, Map<String, dynamic> report) async {
    if (kIsWeb) {
      final index = _webFailureReports.indexWhere((r) => r['id'] == id);
      if (index != -1) {
        _webFailureReports[index] = {..._webFailureReports[index], ...report};
        return 1;
      }
      return 0;
    }
    final db = await database;
    final res = await db.update('failure_reports', report, where: 'id = ?', whereArgs: [id]);
    _backupTable('failure_reports', 'failures');
    return res;
  }

  Future<void> deleteProductionDowntimeByCriteria({
    required String lineName,
    required String date,
    required String reason,
    required String shift,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
      'production_downtime',
      where: 'line_name = ? AND date = ? AND reason = ? AND shift = ?',
      whereArgs: [lineName, date, reason, shift],
    );
    _backupTable('production_downtime', 'production_list');
  }

  Future<void> deleteFailureReportsByUniqueIdPrefix(String prefix) async {
    if (kIsWeb) return;
    final db = await database;
    // Delete failure reports
    await db.delete(
      'failure_reports',
      where: 'unique_id = ? OR unique_id LIKE ?',
      whereArgs: [prefix, '$prefix-%'],
    );
    // Delete associated tasks
    await db.delete(
      'tasks',
      where: 'failure_id NOT IN (SELECT id FROM failure_reports)',
    );
    _backupTable('failure_reports', 'failure_reports');
    _backupTable('tasks', 'tasks');
  }

  Future<void> deleteFailureReport(int id) async {
    if (kIsWeb) {
      _webFailureReports.removeWhere((r) => r['id'] == id);
      return;
    }
    final db = await database;
    await db.delete('failure_reports', where: 'id = ?', whereArgs: [id]);
    _backupTable('failure_reports', 'failures');
  }

  Future<List<Map<String, dynamic>>> getFailureReports() async {
    if (kIsWeb) {
      return _webFailureReports;
    }
    final db = await database;
    return db.query('failure_reports', orderBy: 'created_at DESC');
  }

  // Fault Options Methods
  Future<List<String>> getFaultOptions(String category) async {
    if (kIsWeb) return [];
    final db = await database;
    final res = await db.query('fault_options', where: 'category = ?', whereArgs: [category]);
    return res.map((m) => m['value'] as String).toList();
  }

  Future<void> insertFaultOption(String category, String value) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('fault_options', {'category': category, 'value': value}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> deleteFaultOption(String category, String value) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('fault_options', where: 'category = ? AND value = ?', whereArgs: [category, value]);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final failures = await getFailureReports();
    
    // Production stats
    final productionData = await db.query('production_downtime', orderBy: 'date ASC');
    
    int openFailures = 0;
    int closedFailures = 0;
    double failureDowntimeHours = 0;
    Map<String, int> lineFailureStats = {};
    
    // Failure processing
    for (var r in failures) {
      final isResolved = (r['czy_rozwiazane'] == 1 || r['czy_rozwiazane'] == true);
      if (isResolved) {
        closedFailures++;
        final durationMin = r['downtime_minutes'] as int? ?? 0;
        failureDowntimeHours += durationMin / 60.0;
      } else {
        openFailures++;
      }
      final line = r['linia']?.toString() ?? 'Nieznana';
      lineFailureStats[line] = (lineFailureStats[line] ?? 0) + 1;
    }

    // Production processing
    double totalProductionDowntime = 0;
    int totalDefectiveCarts = 0;
    int barrelChecksOk = 0;
    int cameraChecksOk = 0;
    int totalEntries = productionData.length;
    
    Map<String, double> dailyDowntime = {};
    Map<String, int> dailyDefects = {};

    for (var p in productionData) {
      final mins = (p['minutes'] as num? ?? 0).toDouble();
      final defects = p['defective_carts'] as int? ?? 0;
      final date = p['date']?.toString() ?? 'Unknown';
      
      totalProductionDowntime += mins;
      totalDefectiveCarts += defects;
      
      if ((p['barrels_water'] as int? ?? 0) == 1) barrelChecksOk++;
      if ((p['cameras_cleaned'] as int? ?? 0) == 1) cameraChecksOk++;
      
      dailyDowntime[date] = (dailyDowntime[date] ?? 0) + mins;
      dailyDefects[date] = (dailyDefects[date] ?? 0) + defects;
    }

    double barrelRate = totalEntries > 0 ? (barrelChecksOk / totalEntries) * 10.0 : 0.0;
    double cameraRate = totalEntries > 0 ? (cameraChecksOk / totalEntries) * 10.0 : 0.0;

    return {
      'openFailures': openFailures,
      'closedFailures': closedFailures,
      'failureDowntimeHours': failureDowntimeHours,
      'totalProductionDowntime': totalProductionDowntime,
      'totalDefectiveCarts': totalDefectiveCarts,
      'barrelRate': barrelRate, // 0-10 scale for the circular indicator
      'cameraRate': cameraRate, // 0-10 scale for the circular indicator
      'dailyDowntime': dailyDowntime,
      'dailyDefects': dailyDefects,
      'lineFailureStats': lineFailureStats,
    };
  }
}
