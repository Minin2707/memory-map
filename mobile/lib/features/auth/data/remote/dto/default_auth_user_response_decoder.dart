import 'package:memory_map/features/auth/application/auth_user_response_decoder.dart';
import 'package:memory_map/features/auth/data/remote/dto/auth_user_dto.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

final class DefaultAuthUserResponseDecoder implements AuthUserResponseDecoder {
  const DefaultAuthUserResponseDecoder();

  @override
  AuthUser decode(Object? payload) {
    return AuthUserDto.fromJson(payload).toDomain();
  }
}
