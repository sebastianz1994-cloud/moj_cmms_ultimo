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
}
