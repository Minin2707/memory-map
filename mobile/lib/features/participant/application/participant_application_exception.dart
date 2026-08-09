import 'package:memory_map/features/participant/domain/participant_failure.dart';

final class ParticipantApplicationException implements Exception {
  const ParticipantApplicationException(this.failure);

  final ParticipantFailure failure;

  @override
  String toString() => 'ParticipantApplicationException';
}
