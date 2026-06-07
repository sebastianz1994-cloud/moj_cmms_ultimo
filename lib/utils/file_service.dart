import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class FileService {
  static const String _directoryPath = r'D:\Users\CMMS LCS CLEAN\database\json';
  static const String _fileName = 'temp_production_list.json';
  
  static String get _filePath => p.join(_directoryPath, _fileName);

  /// Zapisuje listę danych do pliku JSON.
  static Future<void> saveProductionList(List<Map<String, dynamic>> data) async {
    try {
      final directory = Directory(_directoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File(_filePath);
      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Błąd podczas zapisywania pliku: $e');
    }
  }

  /// Wczytuje listę danych z pliku JSON.
  static Future<List<Map<String, dynamic>>> loadProductionList() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      print('Błąd podczas wczytywania pliku: $e');
    }
    return [];
  }

  /// Usuwa plik z dysku.
  static Future<void> deleteProductionFile() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Błąd podczas usuwania pliku: $e');
    }
  }
}
