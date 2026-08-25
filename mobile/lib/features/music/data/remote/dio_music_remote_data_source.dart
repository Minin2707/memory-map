import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/music/data/dto/music_track_dto.dart';
import 'package:memory_map/features/music/data/remote/music_remote_data_source.dart';
import 'package:memory_map/features/music/data/remote/music_remote_exception.dart';
import 'package:memory_map/features/music/data/remote/story_soundtrack_remote_data_source.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';

final musicRemoteDataSourceProvider = Provider<MusicRemoteDataSource>((ref) {
  return DioMusicRemoteDataSource(ref.watch(authorizedDioProvider));
});

final storySoundtrackRemoteDataSourceProvider =
    Provider<StorySoundtrackRemoteDataSource>((ref) {
  return DioStorySoundtrackRemoteDataSource(ref.watch(authorizedDioProvider));
});

final class DioMusicRemoteDataSource implements MusicRemoteDataSource {
  const DioMusicRemoteDataSource(this._dio);

  static const String _musicTracksPath = '/api/v1/music/tracks';

  final Dio _dio;

  @override
  Future<List<MusicTrack>> getAvailableTracks() async {
    final response = await _get(_musicTracksPath);

    _ensureExpectedStatus(response, 200);

    return _mapResponse(() {
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Malformed music response');
      }

      return data
          .map((item) => MusicTrackDto.fromJson(item).toDomain())
          .toList();
    });
  }

  Future<Response<Object?>> _get(String path) async {
    try {
      return await _dio.get<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
  }
}

final class DioStorySoundtrackRemoteDataSource
    implements StorySoundtrackRemoteDataSource {
  const DioStorySoundtrackRemoteDataSource(this._dio);

  static const String _storiesPath = '/api/v1/stories';

  final Dio _dio;

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    final response = await _get(_storySoundtrackPath(storyId));

    _ensureExpectedStatus(response, 200);

    return _mapResponse(
      () => StorySoundtrackDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    SetStorySoundtrackRemoteRequest request,
  ) async {
    final response = await _put(
      _storySoundtrackPath(storyId),
      data: request.toJson(),
    );

    _ensureExpectedStatus(response, 200);

    return _mapResponse(
      () => StorySoundtrackDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) async {
    final response = await _delete(_storySoundtrackPath(storyId));

    _ensureExpectedStatus(response, 200);

    return _mapResponse(
      () => StorySoundtrackDto.fromJson(response.data).toDomain(),
    );
  }

  Future<Response<Object?>> _get(String path) async {
    try {
      return await _dio.get<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
  }

  Future<Response<Object?>> _put(
    String path, {
    required Map<String, Object?> data,
  }) async {
    try {
      return await _dio.put<Object?>(
        path,
        data: data,
      );
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
  }

  Future<Response<Object?>> _delete(String path) async {
    try {
      return await _dio.delete<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
  }

  String _storySoundtrackPath(String storyId) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    return '$_storiesPath/${Uri.encodeComponent(storyId)}/soundtrack';
  }
}

T _mapResponse<T>(T Function() mapper) {
  try {
    return mapper();
  } on MusicRemoteException {
    rethrow;
  } on Object {
    throw const MusicRemoteMalformedResponseException();
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
      throw const MusicRemoteTimeoutException();
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      throw const MusicRemoteNetworkException();
    case DioExceptionType.badResponse:
      _throwMappedStatus(error.response?.statusCode);
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      throw const MusicRemoteUnknownException();
  }
}

Never _throwMappedStatus(int? statusCode) {
  if (statusCode == 400) {
    throw const MusicRemoteValidationException();
  }

  if (statusCode == 401 || statusCode == 403) {
    throw const MusicRemoteUnauthorizedException();
  }

  if (statusCode == 404) {
    throw const MusicRemoteUnavailableException();
  }

  if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
    throw const MusicRemoteServerException();
  }

  throw const MusicRemoteUnknownException();
}
