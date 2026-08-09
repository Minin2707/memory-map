import 'package:memory_map/features/memory/data/remote/memory_patch_field.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

final class UpdateMemoryRemoteRequest {
  factory UpdateMemoryRemoteRequest({
    MemoryPatchField<String> title =
        const MemoryPatchField<String>.notProvided(),
    MemoryPatchField<String?> description =
        const MemoryPatchField<String?>.notProvided(),
    MemoryPatchField<String?> placeName =
        const MemoryPatchField<String?>.notProvided(),
    MemoryPatchField<MemoryLocation> location =
        const MemoryPatchField<MemoryLocation>.notProvided(),
    MemoryPatchField<MemoryDate> eventDate =
        const MemoryPatchField<MemoryDate>.notProvided(),
  }) {
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

    return UpdateMemoryRemoteRequest._(
      title: title,
      description: description,
      placeName: placeName,
      location: location,
      eventDate: eventDate,
    );
  }

  factory UpdateMemoryRemoteRequest.fromInput(UpdateMemoryInput input) {
    return UpdateMemoryRemoteRequest(
      title: _fromUpdateField(input.title),
      description: _fromUpdateField(input.description),
      placeName: _fromUpdateField(input.placeName),
      location: _fromUpdateField(input.location),
      eventDate: _fromUpdateField(input.eventDate),
    );
  }

  const UpdateMemoryRemoteRequest._({
    required this.title,
    required this.description,
    required this.placeName,
    required this.location,
    required this.eventDate,
  });

  final MemoryPatchField<String> title;
  final MemoryPatchField<String?> description;
  final MemoryPatchField<String?> placeName;
  final MemoryPatchField<MemoryLocation> location;
  final MemoryPatchField<MemoryDate> eventDate;

  Map<String, Object?> toJson() {
    final updatedLocation = location.value;

    return <String, Object?>{
      if (title.isProvided) 'title': title.value,
      if (description.isProvided) 'description': description.value,
      if (placeName.isProvided) 'placeName': placeName.value,
      if (location.isProvided) ...<String, Object?>{
        'latitude': updatedLocation!.latitude,
        'longitude': updatedLocation.longitude,
      },
      if (eventDate.isProvided) 'eventDate': eventDate.value!.toIso8601Date(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UpdateMemoryRemoteRequest &&
            title == other.title &&
            description == other.description &&
            placeName == other.placeName &&
            location == other.location &&
            eventDate == other.eventDate;
  }

  @override
  int get hashCode => Object.hash(
        title,
        description,
        placeName,
        location,
        eventDate,
      );

  @override
  String toString() {
    return 'UpdateMemoryRemoteRequest(updatesTitle: ${title.isProvided}, '
        'updatesDescription: ${description.isProvided}, '
        'updatesPlaceName: ${placeName.isProvided}, '
        'updatesLocation: ${location.isProvided}, '
        'updatesEventDate: ${eventDate.isProvided})';
  }

  static MemoryPatchField<T> _fromUpdateField<T>(MemoryUpdateField<T> field) {
    if (field.isProvided) {
      return MemoryPatchField<T>.provided(field.value);
    }

    return MemoryPatchField<T>.notProvided();
  }

  static void _validateTitle(MemoryPatchField<String> title) {
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

  static void _validatePlaceName(MemoryPatchField<String?> placeName) {
    if (!placeName.isProvided || placeName.value == null) {
      return;
    }

    if (placeName.value!.length > Memory.maxPlaceNameLength) {
      throw ArgumentError('placeName must not exceed 255 characters');
    }
  }

  static void _validateRequiredProvidedValue<T>(
    MemoryPatchField<T> field,
    String fieldName,
  ) {
    if (field.isProvided && field.value == null) {
      throw ArgumentError('$fieldName must not be null');
    }
  }
}
