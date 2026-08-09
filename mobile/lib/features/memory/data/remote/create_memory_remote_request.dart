import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

final class CreateMemoryRemoteRequest {
  factory CreateMemoryRemoteRequest({
    required String title,
    String? description,
    String? placeName,
    required MemoryLocation location,
    required MemoryDate eventDate,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('title must not be blank');
    }

    if (title.length > Memory.maxTitleLength) {
      throw ArgumentError('title must not exceed 255 characters');
    }

    if (placeName != null && placeName.length > Memory.maxPlaceNameLength) {
      throw ArgumentError('placeName must not exceed 255 characters');
    }

    return CreateMemoryRemoteRequest._(
      title: title,
      description: description,
      placeName: placeName,
      location: location,
      eventDate: eventDate,
    );
  }

  factory CreateMemoryRemoteRequest.fromInput(CreateMemoryInput input) {
    return CreateMemoryRemoteRequest(
      title: input.title,
      description: input.description,
      placeName: input.placeName,
      location: input.location,
      eventDate: input.eventDate,
    );
  }

  const CreateMemoryRemoteRequest._({
    required this.title,
    this.description,
    this.placeName,
    required this.location,
    required this.eventDate,
  });

  final String title;
  final String? description;
  final String? placeName;
  final MemoryLocation location;
  final MemoryDate eventDate;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      if (description != null) 'description': description,
      if (placeName != null) 'placeName': placeName,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'eventDate': eventDate.toIso8601Date(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CreateMemoryRemoteRequest &&
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
  String toString() => 'CreateMemoryRemoteRequest';
}
