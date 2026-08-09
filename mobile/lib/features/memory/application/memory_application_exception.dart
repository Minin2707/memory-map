import 'package:memory_map/features/memory/domain/memory_failure.dart';

final class MemoryApplicationException implements Exception {
  const MemoryApplicationException(this.failure);

  final MemoryFailure failure;

  @override
  String toString() => 'MemoryApplicationException';
}
