import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/invite/data/dto/invite_dto.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_data_source.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_exception.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/story/data/dto/user_story_dto.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final inviteRemoteDataSourceProvider = Provider<InviteRemoteDataSource>((ref) {
  return DioInviteRemoteDataSource(ref.watch(authorizedDioProvider));
});

final class DioInviteRemoteDataSource implements InviteRemoteDataSource {
  const DioInviteRemoteDataSource(this._dio);

  static const String _storiesPath = '/api/v1/stories';
  static const String _invitesPath = '/api/v1/invites';

  final Dio _dio;

  @override
  Future<Invite> createInvite(String storyId) async {
    final response = await _post(_createInvitePath(storyId));

    _ensureExpectedStatus(response, 201);

    return _mapResponse(
      () => InviteDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<UserStory> acceptInvite(String rawToken) async {
    final response = await _post(_acceptInvitePath(rawToken));

    _ensureExpectedStatus(response, 200);

    return _mapResponse(
      () => UserStoryDto.fromJson(response.data).toDomain(),
    );
  }

  Future<Response<Object?>> _post(String path) async {
    try {
      return await _dio.post<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
  }

  T _mapResponse<T>(T Function() mapper) {
    try {
      return mapper();
    } on InviteRemoteException {
      rethrow;
    } on Object {
      throw const InviteRemoteMalformedResponseException();
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

  String _createInvitePath(String storyId) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    return '$_storiesPath/${Uri.encodeComponent(storyId)}/invites';
  }

  String _acceptInvitePath(String rawToken) {
    if (rawToken.trim().isEmpty) {
      throw ArgumentError('rawToken must not be blank');
    }

    return '$_invitesPath/${Uri.encodeComponent(rawToken)}/accept';
  }

  Never _throwMappedDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        throw const InviteRemoteTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        throw const InviteRemoteNetworkException();
      case DioExceptionType.badResponse:
        _throwMappedStatus(error.response?.statusCode);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        throw const InviteRemoteUnknownException();
    }
  }

  Never _throwMappedStatus(int? statusCode) {
    if (statusCode == 400) {
      throw const InviteRemoteValidationException();
    }

    if (statusCode == 401 || statusCode == 403) {
      throw const InviteRemoteUnauthorizedException();
    }

    if (statusCode == 404) {
      throw const InviteRemoteNotFoundException();
    }

    if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
      throw const InviteRemoteServerException();
    }

    throw const InviteRemoteUnknownException();
  }
}
