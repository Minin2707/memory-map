import 'package:memory_map/features/auth/domain/auth_failure.dart';

final class AuthApplicationException implements Exception {
  const AuthApplicationException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthApplicationException';
}
