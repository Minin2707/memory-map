import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/story/data/dto/story_dto.dart';
import 'package:memory_map/features/story/data/dto/user_story_dto.dart';
import 'package:memory_map/features/story/data/remote/create_story_remote_request.dart';
import 'package:memory_map/features/story/data/remote/story_remote_data_source.dart';
import 'package:memory_map/features/story/data/remote/story_remote_exception.dart';
import 'package:memory_map/features/story/data/remote/update_story_remote_request.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final storyRemoteDataSourceProvider = Provider<StoryRemoteDataSource>((ref) {
  return DioStoryRemoteDataSource(ref.watch(authorizedDioProvider));
});

final class DioStoryRemoteDataSource implements StoryRemoteDataSource {
  const DioStoryRemoteDataSource(this._dio);

  static const String _storiesPath = '/api/v1/stories';

  final Dio _dio;

  @override
  Future<Story> createStory(CreateStoryRemoteRequest request) async {
    final response = await _post(
      _storiesPath,
      data: request.toJson(),
    );

    _ensureExpectedStatus(response, 201);

    return _mapResponse(
      () => StoryDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<List<UserStory>> getStories() async {
    final response = await _get(_storiesPath);

    _ensureExpectedStatus(response, 200);

    return _mapResponse(() {
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Malformed story response');
      }

      return data
          .map((item) => UserStoryDto.fromJson(item).toDomain())
          .toList();
    });
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    final response = await _get(_storyPath(storyId));

    _ensureExpectedStatus(response, 200);

    return _mapResponse(
      () => UserStoryDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<UserStory> updateStory(
    String storyId,
    UpdateStoryRemoteRequest request,
  ) async {
    final response = await _patch(
      _storyPath(storyId),
      data: request.toJson(),
    );

    _ensureExpectedStatus(response, 200);

    return _mapResponse(
      () => UserStoryDto.fromJson(response.data).toDomain(),
    );
  }

  Future<Response<Object?>> _get(String path) async {
    try {
      return await _dio.get<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
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

  Future<Response<Object?>> _patch(
    String path, {
    required Map<String, Object?> data,
  }) async {
    try {
      return await _dio.patch<Object?>(
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
    } on StoryRemoteException {
      rethrow;
    } on Object {
      throw const StoryRemoteMalformedResponseException();
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

  String _storyPath(String storyId) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    return '$_storiesPath/${Uri.encodeComponent(storyId)}';
  }

  Never _throwMappedDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        throw const StoryRemoteTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        throw const StoryRemoteNetworkException();
      case DioExceptionType.badResponse:
        _throwMappedStatus(error.response?.statusCode);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        throw const StoryRemoteUnknownException();
    }
  }

  Never _throwMappedStatus(int? statusCode) {
    if (statusCode == 400) {
      throw const StoryRemoteValidationException();
    }

    if (statusCode == 401 || statusCode == 403) {
      throw const StoryRemoteUnauthorizedException();
    }

    if (statusCode == 404) {
      throw const StoryRemoteNotFoundException();
    }

    if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
      throw const StoryRemoteServerException();
    }

    throw const StoryRemoteUnknownException();
  }
}
