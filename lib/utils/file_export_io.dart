import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> saveFile(String content, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
}

Future<String> getSavePath(String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  return '${directory.path}/$fileName';
}
