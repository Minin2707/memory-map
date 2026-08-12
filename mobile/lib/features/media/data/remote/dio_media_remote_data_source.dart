import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/media/data/dto/media_dto.dart';
import 'package:memory_map/features/media/data/remote/media_remote_data_source.dart';
import 'package:memory_map/features/media/data/remote/media_remote_exception.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';

final mediaRemoteDataSourceProvider = Provider<MediaRemoteDataSource>((ref) {
  return DioMediaRemoteDataSource(ref.watch(authorizedDioProvider));
});

final class DioMediaRemoteDataSource implements MediaRemoteDataSource {
  const DioMediaRemoteDataSource(this._dio);

  static const String _memoriesPath = '/api/v1/memories';

  final Dio _dio;

  @override
  Future<List<Media>> getMedia(String memoryId) async {
    final response = await _get(
      _memoryMediaPath(memoryId),
      _MediaRemoteOperation.list,
    );

    _ensureExpectedStatus(response, 200, _MediaRemoteOperation.list);

    return _mapResponse(() {
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Malformed media response');
      }

      return data.map((item) => MediaDto.fromJson(item).toDomain()).toList();
    });
  }

  @override
  Future<Media> uploadPhoto(String memoryId, PreparedPhotoUpload photo) async {
    final response = await _postMultipart(
      _memoryMediaPath(memoryId),
      photo,
    );

    _ensureExpectedStatus(response, 201, _MediaRemoteOperation.upload);

    return _mapResponse(
      () => MediaDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    final response = await _delete(_mediaPath(mediaId));

    _ensureExpectedStatus(response, 204, _MediaRemoteOperation.delete);
  }

  @override
  Future<Uint8List> getRepresentation(String backendPath) async {
    final response = await _getBytes(
      _backendApiPath(backendPath),
      _MediaRemoteOperation.download,
    );

    _ensureExpectedStatus(response, 200, _MediaRemoteOperation.download);

    final data = response.data;
    if (data is Uint8List) {
      return data;
    }

    throw const MediaRemoteMalformedResponseException();
  }

  Future<Response<Object?>> _get(
    String path,
    _MediaRemoteOperation operation,
  ) async {
    try {
      return await _dio.get<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error, operation);
    }
  }

  Future<Response<Object?>> _postMultipart(
    String path,
    PreparedPhotoUpload photo,
  ) async {
    final formData = FormData.fromMap(<String, Object?>{
      'file': MultipartFile.fromBytes(
        photo.bytes,
        filename: 'photo.jpg',
        contentType: http_parser.MediaType.parse(photo.contentType),
      ),
    });

    try {
      return await _dio.post<Object?>(
        path,
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
    } on DioException catch (error) {
      _throwMappedDioException(error, _MediaRemoteOperation.upload);
    }
  }

  Future<Response<Object?>> _delete(String path) async {
    try {
      return await _dio.delete<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error, _MediaRemoteOperation.delete);
    }
  }

  Future<Response<Uint8List>> _getBytes(
    String path,
    _MediaRemoteOperation operation,
  ) async {
    try {
      return await _dio.get<Uint8List>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
    } on DioException catch (error) {
      _throwMappedDioException(error, operation);
    }
  }

  T _mapResponse<T>(T Function() mapper) {
    try {
      return mapper();
    } on MediaRemoteException {
      rethrow;
    } on Object {
      throw const MediaRemoteMalformedResponseException();
    }
  }

  void _ensureExpectedStatus(
    Response<dynamic> response,
    int expectedStatus,
    _MediaRemoteOperation operation,
  ) {
    if (response.statusCode == expectedStatus) {
      return;
    }

    _throwMappedStatus(response.statusCode, operation);
  }

  String _memoryMediaPath(String memoryId) {
    if (memoryId.trim().isEmpty) {
      throw ArgumentError('memoryId must not be blank');
    }

    return '$_memoriesPath/${Uri.encodeComponent(memoryId)}/media';
  }

  String _mediaPath(String mediaId) {
    if (mediaId.trim().isEmpty) {
      throw ArgumentError('mediaId must not be blank');
    }

    return '/api/v1/media/${Uri.encodeComponent(mediaId)}';
  }

  String _backendApiPath(String path) {
    if (path.trim().isEmpty) {
      throw ArgumentError('backendPath must not be blank');
    }

    final uri = Uri.tryParse(path);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !path.startsWith('/api/v1/')) {
      throw ArgumentError('backendPath must be a backend API path');
    }

    return path;
  }

  Never _throwMappedDioException(
    DioException error,
    _MediaRemoteOperation operation,
  ) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        throw const MediaRemoteTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        throw const MediaRemoteNetworkException();
      case DioExceptionType.badResponse:
        _throwMappedStatus(error.response?.statusCode, operation);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        throw const MediaRemoteUnknownException();
    }
  }

  Never _throwMappedStatus(
    int? statusCode,
    _MediaRemoteOperation operation,
  ) {
    if (statusCode == 400) {
      throw const MediaRemoteValidationException();
    }

    if (statusCode == 401 || statusCode == 403) {
      throw const MediaRemoteUnauthorizedException();
    }

    if (statusCode == 404) {
      if (operation == _MediaRemoteOperation.upload) {
        throw const MediaRemoteUploadUnavailableException();
      }

      throw const MediaRemoteUnavailableException();
    }

    if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
      throw const MediaRemoteServerException();
    }

    throw const MediaRemoteUnknownException();
  }
}

enum _MediaRemoteOperation {
  list,
  upload,
  delete,
  download,
}
