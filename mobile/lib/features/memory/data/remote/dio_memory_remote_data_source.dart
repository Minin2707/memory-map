import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/memory/data/dto/memory_dto.dart';
import 'package:memory_map/features/memory/data/remote/create_memory_remote_request.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_data_source.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_exception.dart';
import 'package:memory_map/features/memory/data/remote/update_memory_remote_request.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

final memoryRemoteDataSourceProvider = Provider<MemoryRemoteDataSource>((ref) {
  return DioMemoryRemoteDataSource(ref.watch(authorizedDioProvider));
});

final class DioMemoryRemoteDataSource implements MemoryRemoteDataSource {
  const DioMemoryRemoteDataSource(this._dio);

  static const String _storiesPath = '/api/v1/stories';
  static const String _memoriesPath = '/api/v1/memories';

  final Dio _dio;

  @override
  Future<List<Memory>> getMemories(String storyId) async {
    final response = await _get(
      _storyMemoriesPath(storyId),
      _MemoryRemoteOperation.getMemories,
    );

    _ensureExpectedStatus(response, 200, _MemoryRemoteOperation.getMemories);

    return _mapResponse(() {
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Malformed memory response');
      }

      return data.map((item) => MemoryDto.fromJson(item).toDomain()).toList();
    });
  }

  @override
  Future<Memory> getMemory(String memoryId) async {
    final response = await _get(
      _memoryPath(memoryId),
      _MemoryRemoteOperation.getMemory,
    );

    _ensureExpectedStatus(response, 200, _MemoryRemoteOperation.getMemory);

    return _mapResponse(
      () => MemoryDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    final response = await _post(
      _storyMemoriesPath(input.storyId),
      data: CreateMemoryRemoteRequest.fromInput(input).toJson(),
    );

    _ensureExpectedStatus(response, 201, _MemoryRemoteOperation.createMemory);

    return _mapResponse(
      () => MemoryDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    final response = await _patch(
      _memoryPath(input.memoryId),
      data: UpdateMemoryRemoteRequest.fromInput(input).toJson(),
    );

    _ensureExpectedStatus(response, 200, _MemoryRemoteOperation.updateMemory);

    return _mapResponse(
      () => MemoryDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    final response = await _delete(
      _memoryPath(input.memoryId),
      _MemoryRemoteOperation.deleteMemory,
    );

    _ensureExpectedStatus(response, 204, _MemoryRemoteOperation.deleteMemory);
  }

  Future<Response<Object?>> _get(
    String path,
    _MemoryRemoteOperation operation,
  ) async {
    try {
      return await _dio.get<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error, operation);
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
      _throwMappedDioException(error, _MemoryRemoteOperation.createMemory);
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
      _throwMappedDioException(error, _MemoryRemoteOperation.updateMemory);
    }
  }

  Future<Response<Object?>> _delete(
    String path,
    _MemoryRemoteOperation operation,
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
    } on MemoryRemoteException {
      rethrow;
    } on Object {
      throw const MemoryRemoteMalformedResponseException();
    }
  }

  void _ensureExpectedStatus(
    Response<Object?> response,
    int expectedStatus,
    _MemoryRemoteOperation operation,
  ) {
    if (response.statusCode == expectedStatus) {
      return;
    }

    _throwMappedStatus(response.statusCode, operation);
  }

  String _storyMemoriesPath(String storyId) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    return '$_storiesPath/${Uri.encodeComponent(storyId)}/memories';
  }

  String _memoryPath(String memoryId) {
    if (memoryId.trim().isEmpty) {
      throw ArgumentError('memoryId must not be blank');
    }

    return '$_memoriesPath/${Uri.encodeComponent(memoryId)}';
  }

  Never _throwMappedDioException(
    DioException error,
    _MemoryRemoteOperation operation,
  ) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        throw const MemoryRemoteTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        throw const MemoryRemoteNetworkException();
      case DioExceptionType.badResponse:
        _throwMappedStatus(error.response?.statusCode, operation);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        throw const MemoryRemoteUnknownException();
    }
  }

  Never _throwMappedStatus(
    int? statusCode,
    _MemoryRemoteOperation operation,
  ) {
    if (statusCode == 400) {
      throw const MemoryRemoteValidationException();
    }

    if (statusCode == 401 || statusCode == 403) {
      throw const MemoryRemoteUnauthorizedException();
    }

    if (statusCode == 404) {
      switch (operation) {
        case _MemoryRemoteOperation.getMemories:
          throw const MemoryRemoteStoryUnavailableException();
        case _MemoryRemoteOperation.getMemory:
          throw const MemoryRemoteNotFoundException();
        case _MemoryRemoteOperation.createMemory:
          throw const MemoryRemoteCreationUnavailableException();
        case _MemoryRemoteOperation.updateMemory:
          throw const MemoryRemoteUpdateUnavailableException();
        case _MemoryRemoteOperation.deleteMemory:
          throw const MemoryRemoteDeletionUnavailableException();
      }
    }

    if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
      throw const MemoryRemoteServerException();
    }

    throw const MemoryRemoteUnknownException();
  }
}

enum _MemoryRemoteOperation {
  getMemories,
  getMemory,
  createMemory,
  updateMemory,
  deleteMemory,
}
