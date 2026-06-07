class Asset {
  const Asset({
    this.id,
    required this.nazwa,
    required this.kod,
    required this.lokalizacja,
    required this.opis,
    this.dokumentacja,
  });

  final int? id;
  final String nazwa;
  final String kod;
  final String lokalizacja;
  final String opis;
  final String? dokumentacja;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nazwa': nazwa,
      'kod': kod,
      'lokalizacja': lokalizacja,
      'opis': opis,
      'dokumentacja': dokumentacja,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as int?,
      nazwa: map['nazwa'] as String? ?? '',
      kod: map['kod'] as String? ?? '',
      lokalizacja: map['lokalizacja'] as String? ?? '',
      opis: map['opis'] as String? ?? '',
      dokumentacja: map['dokumentacja'] as String?,
    );
  }
}
