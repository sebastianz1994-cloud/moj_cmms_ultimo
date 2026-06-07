class Task {
  const Task({
    this.id,
    required this.title,
    required this.status,
    required this.type,
    this.dateStart,
    this.dateEnd,
    required this.priority,
    this.label,
    required this.createdAt,
    this.createdBy,
    this.progress = 0.0,
    this.failureId,
  });

  final int? id;
  final String title;
  final String status;
  final String type;
  final String? dateStart;
  final String? dateEnd;
  final String priority;
  final String? label;
  final String createdAt;
  final String? createdBy;
  final double progress;
  final int? failureId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'type': type,
      'date_start': dateStart,
      'date_end': dateEnd,
      'priority': priority,
      'label': label,
      'created_at': createdAt,
      'created_by': createdBy,
      'progress': progress,
      'failure_id': failureId,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      status: map['status'] as String? ?? '',
      type: map['type'] as String? ?? '',
      dateStart: map['date_start'] as String?,
      dateEnd: map['date_end'] as String?,
      priority: map['priority'] as String? ?? 'Standardowy',
      label: map['label'] as String?,
      createdAt: map['created_at'] as String? ?? '',
      createdBy: map['created_by'] as String?,
      progress: (map['progress'] as num? ?? 0.0).toDouble(),
      failureId: map['failure_id'] as int?,
    );
  }
}
