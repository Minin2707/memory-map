import 'package:memory_map/features/memory/domain/memory.dart';

int compareMemoriesCanonical(Memory left, Memory right) {
  final eventDateComparison = left.eventDate.compareTo(right.eventDate);
  if (eventDateComparison != 0) {
    return eventDateComparison;
  }

  final createdAtComparison = left.createdAt.compareTo(right.createdAt);
  if (createdAtComparison != 0) {
    return createdAtComparison;
  }

  return left.id.compareTo(right.id);
}
