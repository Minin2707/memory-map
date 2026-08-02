import 'package:memory_map/features/story/domain/story.dart';

final class StoryDto {
  factory StoryDto.fromJson(Object? json) {
    final map = storyRequiredRootMap(json);

    return StoryDto(
      id: storyRequiredString(map, 'id'),
      title: storyRequiredString(map, 'title'),
      description: storyOptionalString(map, 'description'),
      createdAt: storyRequiredDate(map, 'createdAt'),
      updatedAt: storyRequiredDate(map, 'updatedAt'),
    );
  }

  StoryDto({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw const FormatException('Malformed story response');
    }

    if (title.trim().isEmpty) {
      throw const FormatException('Malformed story response');
    }
  }

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Story toDomain() {
    return Story(
      id: id,
      title: title,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryDto &&
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
  String toString() => 'StoryDto';
}

Map<Object?, Object?> storyRequiredRootMap(Object? json) {
  if (json is! Map) {
    throw const FormatException('Malformed story response');
  }

  return json.cast<Object?, Object?>();
}

String storyRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed story response');
  }

  return value;
}

String? storyOptionalString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return value;
  }

  throw const FormatException('Malformed story response');
}

DateTime storyRequiredDate(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed story response');
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Malformed story response');
  }

  return parsed;
}
