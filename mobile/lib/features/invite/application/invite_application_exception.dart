import 'package:memory_map/features/invite/domain/invite_failure.dart';

final class InviteApplicationException implements Exception {
  const InviteApplicationException(this.failure);

  final InviteFailure failure;

  @override
  String toString() => 'InviteApplicationException';
}
