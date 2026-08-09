import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

final class CreateMemoryInput {
  factory CreateMemoryInput({
    required String storyId,
    required String title,
    String? description,
    String? placeName,
    required MemoryLocation location,
    required MemoryDate eventDate,
  }) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError('title must not be blank');
    }

    if (title.length > Memory.maxTitleLength) {
      throw ArgumentError('title must not exceed 255 characters');
    }

    if (placeName != null && placeName.length > Memory.maxPlaceNameLength) {
      throw ArgumentError('placeName must not exceed 255 characters');
    }

    return CreateMemoryInput._(
      storyId: storyId,
      title: title,
      description: description,
      placeName: placeName,
      location: location,
      eventDate: eventDate,
    );
  }

  const CreateMemoryInput._({
    required this.storyId,
    required this.title,
    this.description,
    this.placeName,
    required this.location,
    required this.eventDate,
  });

  final String storyId;
  final String title;
  final String? description;
  final String? placeName;
  final MemoryLocation location;
  final MemoryDate eventDate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CreateMemoryInput &&
            storyId == other.storyId &&
            title == other.title &&
            description == other.description &&
            placeName == other.placeName &&
            location == other.location &&
            eventDate == other.eventDate;
  }

  @override
  int get hashCode => Object.hash(
        storyId,
        title,
        description,
        placeName,
        location,
        eventDate,
      );

  @override
  String toString() => 'CreateMemoryInput';
}
