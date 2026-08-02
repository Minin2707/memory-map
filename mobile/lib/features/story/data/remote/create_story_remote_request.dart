final class CreateStoryRemoteRequest {
  factory CreateStoryRemoteRequest({
    required String title,
    String? description,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('title must not be blank');
    }

    return CreateStoryRemoteRequest._(
      title: title,
      description: description,
    );
  }

  const CreateStoryRemoteRequest._({
    required this.title,
    this.description,
  });

  final String title;
  final String? description;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      if (description != null) 'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CreateStoryRemoteRequest &&
            title == other.title &&
            description == other.description;
  }

  @override
  int get hashCode => Object.hash(
        title,
        description,
      );

  @override
  String toString() {
    return 'CreateStoryRemoteRequest(title: $title, '
        'description: $description)';
  }
}
