import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';

final class UpdateMemoryInput {
  factory UpdateMemoryInput({
    required String memoryId,
    MemoryUpdateField<String> title =
        const MemoryUpdateField<String>.notProvided(),
    MemoryUpdateField<String?> description =
        const MemoryUpdateField<String?>.notProvided(),
    MemoryUpdateField<String?> placeName =
        const MemoryUpdateField<String?>.notProvided(),
    MemoryUpdateField<MemoryLocation> location =
        const MemoryUpdateField<MemoryLocation>.notProvided(),
    MemoryUpdateField<MemoryDate> eventDate =
        const MemoryUpdateField<MemoryDate>.notProvided(),
  }) {
    if (memoryId.trim().isEmpty) {
      throw ArgumentError('memoryId must not be blank');
    }

    if (!title.isProvided &&
        !description.isProvided &&
        !placeName.isProvided &&
        !location.isProvided &&
        !eventDate.isProvided) {
      throw ArgumentError('at least one update field must be provided');
    }

    _validateTitle(title);
    _validatePlaceName(placeName);
    _validateRequiredProvidedValue(location, 'location');
    _validateRequiredProvidedValue(eventDate, 'eventDate');

    return UpdateMemoryInput._(
      memoryId: memoryId,
      title: title,
      description: description,
      placeName: placeName,
      location: location,
      eventDate: eventDate,
    );
  }

  const UpdateMemoryInput._({
    required this.memoryId,
    required this.title,
    required this.description,
    required this.placeName,
    required this.location,
    required this.eventDate,
  });

  final String memoryId;
  final MemoryUpdateField<String> title;
  final MemoryUpdateField<String?> description;
  final MemoryUpdateField<String?> placeName;
  final MemoryUpdateField<MemoryLocation> location;
  final MemoryUpdateField<MemoryDate> eventDate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UpdateMemoryInput &&
            memoryId == other.memoryId &&
            title == other.title &&
            description == other.description &&
            placeName == other.placeName &&
            location == other.location &&
            eventDate == other.eventDate;
  }

  @override
  int get hashCode => Object.hash(
        memoryId,
        title,
        description,
        placeName,
        location,
        eventDate,
      );

  @override
  String toString() {
    return 'UpdateMemoryInput(updatesTitle: ${title.isProvided}, '
        'updatesDescription: ${description.isProvided}, '
        'updatesPlaceName: ${placeName.isProvided}, '
        'updatesLocation: ${location.isProvided}, '
        'updatesEventDate: ${eventDate.isProvided})';
  }

  static void _validateTitle(MemoryUpdateField<String> title) {
    if (!title.isProvided) {
      return;
    }

    final value = title.value;
    if (value == null) {
      throw ArgumentError('title must not be null');
    }

    if (value.trim().isEmpty) {
      throw ArgumentError('title must not be blank');
    }

    if (value.length > Memory.maxTitleLength) {
      throw ArgumentError('title must not exceed 255 characters');
    }
  }

  static void _validatePlaceName(MemoryUpdateField<String?> placeName) {
    if (!placeName.isProvided || placeName.value == null) {
      return;
    }

    if (placeName.value!.length > Memory.maxPlaceNameLength) {
      throw ArgumentError('placeName must not exceed 255 characters');
    }
  }

  static void _validateRequiredProvidedValue<T>(
    MemoryUpdateField<T> field,
    String fieldName,
  ) {
    if (field.isProvided && field.value == null) {
      throw ArgumentError('$fieldName must not be null');
    }
  }
}
