import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/auth/data/remote/dto/auth_user_dto.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/profile/data/remote/account_remote_data_source.dart';
import 'package:memory_map/features/profile/data/remote/account_remote_exception.dart';

final accountRemoteDataSourceProvider = Provider<AccountRemoteDataSource>(
  (ref) => DioAccountRemoteDataSource(ref.watch(authorizedDioProvider)),
);

final class DioAccountRemoteDataSource implements AccountRemoteDataSource {
  DioAccountRemoteDataSource(this._dio);

  final Dio _dio;

  static const _currentAccountPath = '/api/v1/me';
  static const _currentAvatarPath = '/api/v1/me/avatar';
  static const _displayNamePath = '/api/v1/me/display-name';

  @override
  Future<void> deleteCurrentAccount() async {
    final response = await _delete(_currentAccountPath);
    _ensureExpectedStatus(response, 204);
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    final response = await _patchJson(_displayNamePath, <String, Object?>{
      'displayName': displayName,
    });
    _ensureExpectedStatus(response, 200);

    return _mapResponse(() => AuthUserDto.fromJson(response.data).toDomain());
  }

  @override
  Future<AuthUser> uploadCurrentUserAvatar(PreparedPhotoUpload photo) async {
    final response = await _putMultipart(_currentAvatarPath, photo);
    _ensureExpectedStatus(response, 200);

    return _mapResponse(() => AuthUserDto.fromJson(response.data).toDomain());
  }

  @override
  Future<AuthUser> removeCurrentUserAvatar() async {
    final response = await _delete(_currentAvatarPath);
    _ensureExpectedStatus(response, 200);

    return _mapResponse(() => AuthUserDto.fromJson(response.data).toDomain());
  }

  Future<Response<Object?>> _delete(String path) async {
    try {
      return await _dio.delete<Object?>(path);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on Object {
      throw const AccountRemoteUnknownException();
    }
  }

  Future<Response<Object?>> _patchJson(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      return await _dio.patch<Object?>(path, data: body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on Object {
      throw const AccountRemoteUnknownException();
    }
  }

  Future<Response<Object?>> _putMultipart(
    String path,
    PreparedPhotoUpload photo,
  ) async {
    final formData = FormData.fromMap(<String, Object?>{
      'file': MultipartFile.fromBytes(
        photo.bytes,
        filename: 'avatar.jpg',
        contentType: http_parser.MediaType.parse(photo.contentType),
      ),
    });

    try {
      return await _dio.put<Object?>(
        path,
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on Object {
      throw const AccountRemoteUnknownException();
    }
  }

  T _mapResponse<T>(T Function() mapper) {
    try {
      return mapper();
    } on AccountRemoteException {
      rethrow;
    } on Object {
      throw const AccountRemoteUnknownException();
    }
  }

  void _ensureExpectedStatus(
    Response<Object?> response,
    int expectedStatus,
  ) {
    if (response.statusCode == expectedStatus) {
      return;
    }

    throw _mapStatusCode(response.statusCode);
  }

  AccountRemoteException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AccountRemoteTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const AccountRemoteNetworkException();
      case DioExceptionType.badResponse:
        return _mapStatusCode(error.response?.statusCode);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const AccountRemoteUnknownException();
    }
  }

  AccountRemoteException _mapStatusCode(int? statusCode) {
    if (statusCode == 400 || statusCode == 413 || statusCode == 415) {
      return const AccountRemoteValidationException();
    }

    if (statusCode == 401 || statusCode == 403) {
      return const AccountRemoteUnauthorizedException();
    }

    if (statusCode == 409) {
      return const AccountRemoteOwnershipConflictException();
    }

    if (statusCode != null && statusCode >= 500) {
      return const AccountRemoteServerException();
    }

    return const AccountRemoteUnknownException();
  }
}
