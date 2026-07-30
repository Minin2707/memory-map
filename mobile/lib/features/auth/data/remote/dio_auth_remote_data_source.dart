import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/core/network/dio_provider.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_data_source.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_exception.dart';
import 'package:memory_map/features/auth/data/remote/dto/auth_token_response_dto.dart';
import 'package:memory_map/features/auth/data/remote/dto/google_login_request_dto.dart';
import 'package:memory_map/features/auth/data/remote/dto/google_login_response_dto.dart';
import 'package:memory_map/features/auth/data/remote/dto/refresh_token_request_dto.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return DioAuthRemoteDataSource(ref.watch(publicDioProvider));
});

final class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  const DioAuthRemoteDataSource(this._dio);

  static const String _googleLoginPath = '/api/v1/auth/google';
  static const String _refreshPath = '/api/v1/auth/refresh';
  static const String _logoutPath = '/api/v1/auth/logout';

  final Dio _dio;

  @override
  Future<AuthSession> loginWithGoogle(String idToken) async {
    final request = GoogleLoginRequestDto(idToken: idToken);
    final response = await _post(
      _googleLoginPath,
      data: request.toJson(),
    );

    _ensureExpectedStatus(response, 200);

    return _mapResponse(
      () => GoogleLoginResponseDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final request = RefreshTokenRequestDto(refreshToken: refreshToken);
    final response = await _post(
      _refreshPath,
      data: request.toJson(),
    );

    _ensureExpectedStatus(response, 200);

    return _mapResponse(
      () => AuthTokenResponseDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    final request = RefreshTokenRequestDto(refreshToken: refreshToken);
    final response = await _post(
      _logoutPath,
      data: request.toJson(),
    );

    _ensureExpectedStatus(response, 204);
  }

  Future<Response<Object?>> _post(
    String path, {
    required Map<String, Object?> data,
  }) async {
    try {
      return await _dio.post<Object?>(
        path,
        data: data,
      );
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
  }

  T _mapResponse<T>(T Function() mapper) {
    try {
      return mapper();
    } on AuthRemoteException {
      rethrow;
    } on Object {
      throw const AuthRemoteMalformedResponseException();
    }
  }

  void _ensureExpectedStatus(
    Response<Object?> response,
    int expectedStatus,
  ) {
    if (response.statusCode == expectedStatus) {
      return;
    }

    _throwMappedStatus(response.statusCode);
  }

  Never _throwMappedDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        throw const AuthRemoteTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        throw const AuthRemoteNetworkException();
      case DioExceptionType.badResponse:
        _throwMappedStatus(error.response?.statusCode);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        throw const AuthRemoteUnknownException();
    }
  }

  Never _throwMappedStatus(int? statusCode) {
    if (statusCode == 400) {
      throw const AuthRemoteValidationException();
    }

    if (statusCode == 401) {
      throw const AuthRemoteUnauthorizedException();
    }

    if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
      throw const AuthRemoteServerException();
    }

    throw const AuthRemoteUnknownException();
  }
}
