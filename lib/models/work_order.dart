class WorkOrder {
  const WorkOrder({
    this.id,
    required this.tytul,
    required this.opis,
    required this.status,
    required this.assetId,
  });

  final int? id;
  final String tytul;
  final String opis;
  final String status;
  final int assetId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tytul': tytul,
      'opis': opis,
      'status': status,
      'asset_id': assetId,
    };
  }

  factory WorkOrder.fromMap(Map<String, dynamic> map) {
    return WorkOrder(
      id: map['id'] as int?,
      tytul: map['tytul'] as String? ?? '',
      opis: map['opis'] as String? ?? '',
      status: map['status'] as String? ?? '',
      assetId: map['asset_id'] as int? ?? 0,
    );
  }
}
