import 'package:intl/intl.dart';

class TimeUtils {
  static String calculateDuration(String? start, String? end) {
    if (start == null || end == null || start.isEmpty || end.isEmpty) return '0h 00min';
    try {
      final s = start.split(':');
      final e = end.split(':');
      if (s.length != 2 || e.length != 2) return '0h 00min';
      
      final sMin = int.parse(s[0]) * 60 + int.parse(s[1]);
      var eMin = int.parse(e[0]) * 60 + int.parse(e[1]);
      
      if (eMin < sMin) eMin += 24 * 60; // Crosses midnight
      
      final diff = eMin - sMin;
      if (diff <= 0) return '0h 00min';
      
      final h = diff ~/ 60;
      final m = diff % 60;
      return '${h}h ${m.toString().padLeft(2, '0')}min';
    } catch (_) {
      return '0h 00min';
    }
  }

  static int getISOWeek(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  static String formatFaultId({
    required String? line,
    required int count,
    required DateTime date,
  }) {
    final year = date.year;
    final week = getISOWeek(date);
    final lineCode = _getLineCode(line);
    final paddedCount = count.toString().padLeft(3, '0');
    return '$lineCode/$paddedCount/W$week/$year';
  }

  static String simplifyFaultId(String? uniqueId) {
    if (uniqueId == null || uniqueId.isEmpty) return '-';
    
    // If it's a Storing List technical fault ID (starts with PL-)
    if (uniqueId.startsWith('PL-')) {
      final parts = uniqueId.split('-');
      if (parts.isNotEmpty) {
        final lastPart = parts.last;
        // Check if last part looks like a fault ID (e.g., L1/001/W24/2026 or 001/W24/2026)
        if (lastPart.contains('/W')) {
          return lastPart;
        }
      }
    }
    
    return uniqueId;
  }

  static String _getLineCode(String? line) {
    if (line == null || line.isEmpty) return 'L?';
    final upperLine = line.toUpperCase();
    if (upperLine.contains('LIJN 1')) return 'L1';
    if (upperLine.contains('LIJN 2')) return 'L2';
    if (upperLine.contains('LIJN 3')) return 'L3';
    if (upperLine.contains('COMPRESSOR')) return 'COMP';
    if (upperLine.contains('WATER PUMP')) return 'WP';
    if (upperLine.contains('CHLORINE') || upperLine.contains('CHL')) return 'CHL';
    if (upperLine.contains('SOAP')) return 'SOAP';
    return 'O'; // Other
  }
}
