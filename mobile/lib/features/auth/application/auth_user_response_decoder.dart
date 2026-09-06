import 'package:memory_map/features/auth/domain/auth_user.dart';

abstract interface class AuthUserResponseDecoder {
  AuthUser decode(Object? payload);
}
