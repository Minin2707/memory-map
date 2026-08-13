import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/data/remote/dio_media_remote_data_source.dart';
import 'package:memory_map/features/media/data/remote/media_remote_exception.dart';
import 'package:memory_map/features/media/domain/media.dart';

import '../../media_test_fixtures.dart';

void main() {
  group('DioMediaRemoteDataSource list', () {
    test('shouldGetMemoryMediaByEncodedMemoryId', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[mediaJson()],
      );
      final dataSource = createDataSource(adapter);

      await dataSource.getMedia('memory/id');

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/memories/memory%2Fid/media');
      expect(adapter.lastBodyText, isNull);
    });

    test('shouldReturnMediaListInBackendOrder', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <Object?>[
            mediaJson(id: 'media-a'),
            mediaJson(
              id: 'media-b',
              thumbnailUrl: '/api/v1/media/media-b/thumbnail',
              displayUrl: '/api/v1/media/media-b/display',
            ),
          ],
        ),
      );

      final items = await dataSource.getMedia(defaultMemoryId);

      expect(items, <Media>[
        media(id: 'media-a'),
        media(
          id: 'media-b',
          thumbnailPath: '/api/v1/media/media-b/thumbnail',
          displayPath: '/api/v1/media/media-b/display',
        ),
      ]);
    });

    test('shouldRejectBlankMemoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[mediaJson()],
      );
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.getMedia('   '),
        throwsA(argumentErrorWithMessage('memoryId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });
  });

  group('DioMediaRemoteDataSource upload', () {
    test('shouldPostMultipartPreparedPhotoOnly', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 201,
        responseData: mediaJson(id: 'uploaded-media-id'),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.uploadPhoto(
        'memory/id',
        preparedPhotoUpload(bytes: <int>[4, 5, 6]),
      );

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastPath, '/api/v1/memories/memory%2Fid/media');
      expect(adapter.lastContentType, startsWith('multipart/form-data'));
      expect(adapter.lastBodyText, contains('name="file"'));
      expect(adapter.lastBodyText, contains('filename="photo.jpg"'));
      expect(
        adapter.lastBodyText?.toLowerCase(),
        contains('content-type: image/jpeg'),
      );
      expect(adapter.lastBodyText, isNot(contains('storyId')));
      expect(adapter.lastBodyText, isNot(contains('mediaId')));
      expect(adapter.lastBodyText, isNot(contains('thumbnail')));
      expect(adapter.lastBodyText, isNot(contains('displayStorageKey')));
      expect(adapter.lastBodyText, isNot(contains('MinIO')));
    });

    test('shouldReturnAuthoritativeUploadedMedia', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 201,
          responseData: mediaJson(id: 'uploaded-media-id'),
        ),
      );

      final item = await dataSource.uploadPhoto(
        defaultMemoryId,
        preparedPhotoUpload(),
      );

      expect(item.id, 'uploaded-media-id');
    });
  });

  group('DioMediaRemoteDataSource binary representation', () {
    test('shouldGetBackendRelativeRepresentationAsBytes', () async {
      final adapter = FakeHttpClientAdapter(
        responseBytes: Uint8List.fromList(<int>[1, 2, 3]),
      );
      final dataSource = createDataSource(adapter);

      final bytes = await dataSource.getRepresentation(
        '/api/v1/media/media-id/thumbnail',
      );

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/media/media-id/thumbnail');
      expect(adapter.lastResponseType, ResponseType.bytes);
      expect(bytes, <int>[1, 2, 3]);
    });

    test('shouldRejectExternalOrBlankRepresentationPaths', () async {
      final adapter = FakeHttpClientAdapter(
        responseBytes: Uint8List.fromList(<int>[1]),
      );
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.getRepresentation('   '),
        throwsA(argumentErrorWithMessage('backendPath must not be blank')),
      );
      await expectLater(
        dataSource.getRepresentation('https://storage.example/object'),
        throwsA(
          argumentErrorWithMessage(
            'backendPath must be a backend API path',
          ),
        ),
      );
      await expectLater(
        dataSource.getRepresentation('/api/v1/media/media-id/thumbnail?x=1'),
        throwsA(
          argumentErrorWithMessage(
            'backendPath must be a backend API path',
          ),
        ),
      );
      expect(adapter.fetchCalls, 0);
    });
  });

  group('DioMediaRemoteDataSource delete', () {
    test('shouldDeleteMediaByEncodedMediaIdWithoutBodyOrQuery', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await dataSource.deleteMedia('media/id');

      expect(adapter.lastMethod, 'DELETE');
      expect(adapter.lastPath, '/api/v1/media/media%2Fid');
      expect(adapter.lastBodyText, isNull);
      expect(adapter.lastPath, isNot(contains('memory')));
      expect(adapter.lastPath, isNot(contains('role')));
      expect(adapter.lastPath, isNot(contains('thumbnail')));
      expect(adapter.lastPath, isNot(contains('display')));
    });

    test('shouldTreat204EmptyBodyAsSuccessWithoutDtoParsing', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 204),
      );

      await expectLater(
        dataSource.deleteMedia(defaultMediaId),
        completes,
      );
    });

    test('shouldRejectBlankMediaIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.deleteMedia('   '),
        throwsA(argumentErrorWithMessage('mediaId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });
  });

  group('DioMediaRemoteDataSource failures', () {
    test('shouldMapMalformedResponses', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.getMedia(defaultMemoryId),
        throwsA(isA<MediaRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapStatusCodes', () async {
      await expectMediaStatusFailure(400, isA<MediaRemoteValidationException>());
      await expectMediaStatusFailure(
        401,
        isA<MediaRemoteUnauthorizedException>(),
      );
      await expectMediaStatusFailure(
        403,
        isA<MediaRemoteUnauthorizedException>(),
      );
      await expectMediaStatusFailure(404, isA<MediaRemoteUnavailableException>());
      await expectMediaStatusFailure(500, isA<MediaRemoteServerException>());
      await expectMediaStatusFailure(418, isA<MediaRemoteUnknownException>());
    });

    test('shouldMapUpload404ToUploadUnavailable', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 404, responseData: problemJson()),
      );

      await expectLater(
        dataSource.uploadPhoto(defaultMemoryId, preparedPhotoUpload()),
        throwsA(isA<MediaRemoteUploadUnavailableException>()),
      );
    });

    test('shouldMapDelete404ToUnavailable', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 404, responseData: problemJson()),
      );

      await expectLater(
        dataSource.deleteMedia(defaultMediaId),
        throwsA(isA<MediaRemoteUnavailableException>()),
      );
    });

    test('shouldMapTransportFailures', () async {
      await expectMediaTransportFailure(
        DioExceptionType.connectionTimeout,
        isA<MediaRemoteTimeoutException>(),
      );
      await expectMediaTransportFailure(
        DioExceptionType.connectionError,
        isA<MediaRemoteNetworkException>(),
      );
      await expectMediaTransportFailure(
        DioExceptionType.cancel,
        isA<MediaRemoteUnknownException>(),
      );
    });
  });

  group('MediaRemoteException', () {
    test('shouldExposeSafeToString', () {
      expect(
        const MediaRemoteUnavailableException().toString(),
        'MediaRemoteUnavailableException',
      );
      expect(
        const MediaRemoteUnavailableException().toString(),
        isNot(contains('/api/v1/media')),
      );
    });
  });
}

DioMediaRemoteDataSource createDataSource(FakeHttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioMediaRemoteDataSource(dio);
}

Future<void> expectMediaStatusFailure(int statusCode, Matcher matcher) async {
  final dataSource = createDataSource(
    FakeHttpClientAdapter(statusCode: statusCode, responseData: problemJson()),
  );

  await expectLater(dataSource.getMedia(defaultMemoryId), throwsA(matcher));
}

Future<void> expectMediaTransportFailure(
  DioExceptionType type,
  Matcher matcher,
) async {
  final adapter = FakeHttpClientAdapter(
    failure: DioException(
      requestOptions: RequestOptions(path: '/api/v1/memories/memory-id/media'),
      type: type,
    ),
  );
  final dataSource = createDataSource(adapter);

  await expectLater(dataSource.getMedia(defaultMemoryId), throwsA(matcher));
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

Map<String, Object?> problemJson() {
  return <String, Object?>{
    'title': 'Not Found',
    'status': 404,
    'detail': 'Media was not found',
  };
}

final class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({
    this.statusCode = 200,
    this.responseData,
    this.responseBytes,
    this.failure,
  });

  final int statusCode;
  final Object? responseData;
  final Uint8List? responseBytes;
  final DioException? failure;

  int fetchCalls = 0;
  String? lastMethod;
  String? lastPath;
  String? lastBodyText;
  String? lastContentType;
  ResponseType? lastResponseType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCalls += 1;
    lastMethod = options.method;
    lastPath = options.path;
    lastContentType = options.contentType;
    lastResponseType = options.responseType;
    lastBodyText = await decodeRequestBody(requestStream);

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    final configuredResponseBytes = responseBytes;
    if (configuredResponseBytes != null) {
      return ResponseBody.fromBytes(
        configuredResponseBytes,
        statusCode,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['image/jpeg'],
        },
      );
    }

    return ResponseBody.fromString(
      encodeResponseBody(responseData),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<String?> decodeRequestBody(Stream<Uint8List>? requestStream) async {
  if (requestStream == null) {
    return null;
  }

  final bytes = await requestStream.expand((chunk) => chunk).toList();
  if (bytes.isEmpty) {
    return null;
  }

  return latin1.decode(bytes);
}

String encodeResponseBody(Object? responseData) {
  if (responseData == null) {
    return '';
  }

  return jsonEncode(responseData);
}
