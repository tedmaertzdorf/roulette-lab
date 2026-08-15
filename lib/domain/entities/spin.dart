class Spin {
  const Spin({
    required this.id,
    required this.position,
    required this.number,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.occurredAtUtc,
  });

  final int? id;
  final int position;
  final int number;
  final DateTime? occurredAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  Spin copyWith({
    int? id,
    int? position,
    int? number,
    DateTime? occurredAtUtc,
    bool clearOccurredAt = false,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) => Spin(
    id: id ?? this.id,
    position: position ?? this.position,
    number: number ?? this.number,
    occurredAtUtc: clearOccurredAt ? null : occurredAtUtc ?? this.occurredAtUtc,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
}
