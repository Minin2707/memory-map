final class Story {
  factory Story({
    required String id,
    required String title,
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('id must not be blank');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError('title must not be blank');
    }

    return Story._(
      id: id,
      title: title,
      description: description,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  const Story._({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Story &&
            id == other.id &&
            title == other.title &&
            description == other.description &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        createdAt,
        updatedAt,
      );

  @override
  String toString() {
    return 'Story(id: $id, title: $title, description: $description, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
