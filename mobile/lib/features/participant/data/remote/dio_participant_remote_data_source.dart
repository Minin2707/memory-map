import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/participant/data/dto/story_participant_dto.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_data_source.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_exception.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';

final participantRemoteDataSourceProvider =
    Provider<ParticipantRemoteDataSource>((ref) {
  return DioParticipantRemoteDataSource(ref.watch(authorizedDioProvider));
});

final class DioParticipantRemoteDataSource
    implements ParticipantRemoteDataSource {
  const DioParticipantRemoteDataSource(this._dio);

  static const String _storiesPath = '/api/v1/stories';
  static const String _removeSelfDetail =
      'Use the leave story operation to remove yourself';
  static const String _removeOwnerDetail = 'A story owner cannot be removed';

  final Dio _dio;

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    final response = await _get(
      _participantsPath(storyId),
      _ParticipantRemoteOperation.getParticipants,
    );

    _ensureExpectedStatus(
      response,
      200,
      _ParticipantRemoteOperation.getParticipants,
    );

    return _mapResponse(() {
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Malformed participant response');
      }

      return data
          .map((item) => StoryParticipantDto.fromJson(item).toDomain())
          .toList();
    });
  }

  @override
  Future<void> leaveStory(String storyId) async {
    final response = await _delete(
      _leaveStoryPath(storyId),
      _ParticipantRemoteOperation.leaveStory,
    );

    _ensureExpectedStatus(
      response,
      204,
      _ParticipantRemoteOperation.leaveStory,
    );
  }

  @override
  Future<void> removeParticipant(
    String storyId,
    String participantUserId,
  ) async {
    final response = await _delete(
      _removeParticipantPath(storyId, participantUserId),
      _ParticipantRemoteOperation.removeParticipant,
    );

    _ensureExpectedStatus(
      response,
      204,
      _ParticipantRemoteOperation.removeParticipant,
    );
  }

  Future<Response<Object?>> _get(
    String path,
    _ParticipantRemoteOperation operation,
  ) async {
    try {
      return await _dio.get<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error, operation);
    }
  }

  Future<Response<Object?>> _delete(
    String path,
    _ParticipantRemoteOperation operation,
  ) async {
    try {
      return await _dio.delete<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error, operation);
    }
  }

  T _mapResponse<T>(T Function() mapper) {
    try {
      return mapper();
    } on ParticipantRemoteException {
      rethrow;
    } on Object {
      throw const ParticipantRemoteMalformedResponseException();
    }
  }

  void _ensureExpectedStatus(
    Response<Object?> response,
    int expectedStatus,
    _ParticipantRemoteOperation operation,
  ) {
    if (response.statusCode == expectedStatus) {
      return;
    }

    _throwMappedStatus(response.statusCode, operation, response.data);
  }

  String _participantsPath(String storyId) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    return '$_storiesPath/${Uri.encodeComponent(storyId)}/participants';
  }

  String _leaveStoryPath(String storyId) {
    return '${_participantsPath(storyId)}/me';
  }

  String _removeParticipantPath(
    String storyId,
    String participantUserId,
  ) {
    if (participantUserId.trim().isEmpty) {
      throw ArgumentError('participantUserId must not be blank');
    }

    return '${_participantsPath(storyId)}/'
        '${Uri.encodeComponent(participantUserId)}';
  }

  Never _throwMappedDioException(
    DioException error,
    _ParticipantRemoteOperation operation,
  ) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        throw const ParticipantRemoteTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        throw const ParticipantRemoteNetworkException();
      case DioExceptionType.badResponse:
        _throwMappedStatus(
          error.response?.statusCode,
          operation,
          error.response?.data,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        throw const ParticipantRemoteUnknownException();
    }
  }

  Never _throwMappedStatus(
    int? statusCode,
    _ParticipantRemoteOperation operation,
    Object? data,
  ) {
    if (statusCode == 400) {
      throw const ParticipantRemoteValidationException();
    }

    if (statusCode == 401 || statusCode == 403) {
      throw const ParticipantRemoteUnauthorizedException();
    }

    if (statusCode == 404) {
      throw const ParticipantRemoteNotFoundException();
    }

    if (statusCode == 409) {
      _throwMappedConflict(operation, data);
    }

    if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
      throw const ParticipantRemoteServerException();
    }

    throw const ParticipantRemoteUnknownException();
  }

  Never _throwMappedConflict(
    _ParticipantRemoteOperation operation,
    Object? data,
  ) {
    if (operation == _ParticipantRemoteOperation.leaveStory) {
      throw const ParticipantRemoteLastOwnerConflictException();
    }

    if (operation == _ParticipantRemoteOperation.removeParticipant) {
      final detail = _problemDetailDetail(data);
      if (detail == _removeSelfDetail) {
        throw const ParticipantRemoteCannotRemoveSelfException();
      }

      if (detail == _removeOwnerDetail) {
        throw const ParticipantRemoteOwnerCannotBeRemovedException();
      }
    }

    throw const ParticipantRemoteUnknownException();
  }

  String? _problemDetailDetail(Object? data) {
    if (data is! Map) {
      return null;
    }

    final detail = data['detail'];
    if (detail is String) {
      return detail;
    }

    return null;
  }
}

enum _ParticipantRemoteOperation {
  getParticipants,
  leaveStory,
  removeParticipant,
}
