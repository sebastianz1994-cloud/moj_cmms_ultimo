import 'dart:typed_data';

class FailureReport {
  final int? id;
  final String uniqueId;
  final String opis;
  final String lokalizacja;
  final String linia;
  final bool czyRozwiazane;
  final String? czasTrwania; // calculated string like "2h 30m"
  final String? coNaprawiono;
  final String? ktoNaprawil;
  final String? zdjecieSciezka;
  final Uint8List? zdjecieBlob;
  final String createdBy;
  final DateTime createdAt;
  final String? powod;
  final String? priorytet;
  final String status; // OTWARTY / ZAMKNIĘTY
  final DateTime? dataRozpoczeciaNaprawy;
  final DateTime? dataZakonczeniaNaprawy;
  final int? downtimeMinutes;

  FailureReport({
    this.id,
    required this.uniqueId,
    required this.opis,
    required this.lokalizacja,
    required this.linia,
    required this.czyRozwiazane,
    this.czasTrwania,
    this.coNaprawiono,
    this.ktoNaprawil,
    this.zdjecieSciezka,
    this.zdjecieBlob,
    required this.createdBy,
    required this.createdAt,
    this.powod,
    this.priorytet,
    required this.status,
    this.dataRozpoczeciaNaprawy,
    this.dataZakonczeniaNaprawy,
    this.downtimeMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unique_id': uniqueId,
      'opis': opis,
      'lokalizacja': lokalizacja,
      'linia': linia,
      'czy_rozwiazane': czyRozwiazane ? 1 : 0,
      'czas_trwania': czasTrwania,
      'co_naprawiono': coNaprawiono,
      'kto_naprawil': ktoNaprawil,
      'zdjecie_sciezka': zdjecieSciezka,
      'zdjecie_blob': zdjecieBlob,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'powod': powod,
      'priorytet': priorytet,
      'status': status,
      'data_rozpoczecia_naprawy': dataRozpoczeciaNaprawy?.toIso8601String(),
      'data_zakonczenia_naprawy': dataZakonczeniaNaprawy?.toIso8601String(),
      'downtime_minutes': downtimeMinutes,
    };
  }

  factory FailureReport.fromMap(Map<String, dynamic> map) {
    return FailureReport(
      id: map['id'] as int?,
      uniqueId: map['unique_id'] as String? ?? '',
      opis: map['opis'] as String? ?? '',
      lokalizacja: map['lokalizacja'] as String? ?? '',
      linia: map['linia'] as String? ?? '',
      czyRozwiazane: map['czy_rozwiazane'] == 1,
      czasTrwania: map['czas_trwania'] as String?,
      coNaprawiono: map['co_naprawiono'] as String?,
      ktoNaprawil: map['kto_naprawil'] as String?,
      zdjecieSciezka: map['zdjecie_sciezka'] as String?,
      zdjecieBlob: map['zdjecie_blob'] as Uint8List?,
      createdBy: map['created_by'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      powod: map['powod'] as String?,
      priorytet: map['priorytet'] as String?,
      status: map['status'] as String? ?? 'OTWARTY',
      dataRozpoczeciaNaprawy: map['data_rozpoczecia_naprawy'] != null
          ? DateTime.parse(map['data_rozpoczecia_naprawy'] as String)
          : null,
      dataZakonczeniaNaprawy: map['data_zakonczenia_naprawy'] != null
          ? DateTime.parse(map['data_zakonczenia_naprawy'] as String)
          : null,
      downtimeMinutes: map['downtime_minutes'] as int?,
    );
  }
}
