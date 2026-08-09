import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

final class Memory {
  factory Memory({
    required String id,
    required String storyId,
    required String createdBy,
    required String title,
    String? description,
    String? placeName,
    required MemoryLocation location,
    required MemoryDate eventDate,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    _validateIdentifier(id, 'id');
    _validateIdentifier(storyId, 'storyId');
    _validateIdentifier(createdBy, 'createdBy');
    _validateTitle(title);
    _validatePlaceName(placeName);

    return Memory._(
      id: id,
      storyId: storyId,
      createdBy: createdBy,
      title: title,
      description: description,
      placeName: placeName,
      location: location,
      eventDate: eventDate,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  const Memory._({
    required this.id,
    required this.storyId,
    required this.createdBy,
    required this.title,
    this.description,
    this.placeName,
    required this.location,
    required this.eventDate,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int maxTitleLength = 255;
  static const int maxPlaceNameLength = 255;

  final String id;
  final String storyId;
  final String createdBy;
  final String title;
  final String? description;
  final String? placeName;
  final MemoryLocation location;
  final MemoryDate eventDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Memory &&
            id == other.id &&
            storyId == other.storyId &&
            createdBy == other.createdBy &&
            title == other.title &&
            description == other.description &&
            placeName == other.placeName &&
            location == other.location &&
            eventDate == other.eventDate &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        storyId,
        createdBy,
        title,
        description,
        placeName,
        location,
        eventDate,
        createdAt,
        updatedAt,
      );

  @override
  String toString() {
    return 'Memory(hasDescription: ${description != null}, '
        'hasPlaceName: ${placeName != null})';
  }

  static void _validateIdentifier(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$fieldName must not be blank');
    }
  }

  static void _validateTitle(String title) {
    if (title.trim().isEmpty) {
      throw ArgumentError('title must not be blank');
    }

    if (title.length > maxTitleLength) {
      throw ArgumentError('title must not exceed 255 characters');
    }
  }

  static void _validatePlaceName(String? placeName) {
    if (placeName != null && placeName.length > maxPlaceNameLength) {
      throw ArgumentError('placeName must not exceed 255 characters');
    }
  }
}
