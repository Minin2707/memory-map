import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/music/data/remote/dio_music_remote_data_source.dart';
import 'package:memory_map/features/music/data/remote/music_remote_exception.dart';
import 'package:memory_map/features/music/data/remote/story_soundtrack_remote_data_source.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';

void main() {
  group('DioMusicRemoteDataSource catalog', () {
    test('shouldGetMusicCatalogEndpoint', () async {
      final adapter = FakeHttpClientAdapter(responseData: <Object?>[]);
      final dataSource = createMusicDataSource(adapter);

      await dataSource.getAvailableTracks();

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/music/tracks');
      expect(adapter.lastBody, isNull);
    });

    test('shouldReturnCatalogInBackendOrder', () async {
      final dataSource = createMusicDataSource(
        FakeHttpClientAdapter(
          responseData: <Object?>[
            validTrackJson(id: 'track-b', title: 'B'),
            validTrackJson(id: 'track-a', title: 'A'),
          ],
        ),
      );

      final tracks = await dataSource.getAvailableTracks();

      expect(tracks, <MusicTrack>[
        track(id: 'track-b', title: 'B'),
        track(id: 'track-a', title: 'A'),
      ]);
    });

    test('shouldReturnEmptyCatalog', () async {
      final dataSource = createMusicDataSource(
        FakeHttpClientAdapter(responseData: <Object?>[]),
      );

      final tracks = await dataSource.getAvailableTracks();

      expect(tracks, isEmpty);
    });
  });

  group('DioStorySoundtrackRemoteDataSource', () {
    test('shouldGetStorySoundtrackByEncodedStoryId', () async {
      final adapter = FakeHttpClientAdapter(responseData: noMusicJson());
      final dataSource = createStorySoundtrackDataSource(adapter);

      await dataSource.getStorySoundtrack('story/id');

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/stories/story%2Fid/soundtrack');
      expect(adapter.lastBody, isNull);
    });

    test('shouldPutStorySoundtrackByStoryIdWithTrackBody', () async {
      final adapter = FakeHttpClientAdapter(responseData: selectedJson());
      final dataSource = createStorySoundtrackDataSource(adapter);

      await dataSource.setStorySoundtrack(
        'story-id',
        const SetStorySoundtrackRemoteRequest(musicTrackId: 'track-id'),
      );

      expect(adapter.lastMethod, 'PUT');
      expect(adapter.lastPath, '/api/v1/stories/story-id/soundtrack');
      expect(adapter.lastBody, <String, Object?>{
        'musicTrackId': 'track-id',
      });
      expect((adapter.lastBody! as Map).containsKey('userId'), isFalse);
      expect((adapter.lastBody! as Map).containsKey('role'), isFalse);
      expect((adapter.lastBody! as Map).containsKey('storageKey'), isFalse);
    });

    test('shouldDeleteStorySoundtrackByStoryId', () async {
      final adapter = FakeHttpClientAdapter(responseData: noMusicJson());
      final dataSource = createStorySoundtrackDataSource(adapter);

      await dataSource.removeStorySoundtrack('story-id');

      expect(adapter.lastMethod, 'DELETE');
      expect(adapter.lastPath, '/api/v1/stories/story-id/soundtrack');
      expect(adapter.lastBody, isNull);
    });

    test('shouldReturnNoMusic', () async {
      final dataSource = createStorySoundtrackDataSource(
        FakeHttpClientAdapter(responseData: noMusicJson()),
      );

      final soundtrack = await dataSource.getStorySoundtrack('story-id');

      expect(soundtrack, StorySoundtrack.noMusic());
    });

    test('shouldReturnSelectedUnavailable', () async {
      final dataSource = createStorySoundtrackDataSource(
        FakeHttpClientAdapter(
          responseData: <String, Object?>{
            'selectedSoundtrack': validTrackJson(),
            'effectiveSoundtrack': null,
          },
        ),
      );

      final soundtrack = await dataSource.getStorySoundtrack('story-id');

      expect(soundtrack.selectedSoundtrack, track());
      expect(soundtrack.effectiveSoundtrack, isNull);
      expect(soundtrack.isSelectedUnavailable, isTrue);
    });

    test('shouldRejectBlankStoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(responseData: noMusicJson());
      final dataSource = createStorySoundtrackDataSource(adapter);

      await expectLater(
        dataSource.getStorySoundtrack('   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });
  });

  group('Dio music remote errors', () {
    test('shouldMap400ToValidation', () async {
      await expectMusicStatusFailure(
        400,
        isA<MusicRemoteValidationException>(),
      );
    });

    test('shouldMap401ToUnauthorized', () async {
      await expectMusicStatusFailure(
        401,
        isA<MusicRemoteUnauthorizedException>(),
      );
    });

    test('shouldMap403ToUnauthorized', () async {
      await expectMusicStatusFailure(
        403,
        isA<MusicRemoteUnauthorizedException>(),
      );
    });

    test('shouldMap404ToUnavailable', () async {
      await expectMusicStatusFailure(
        404,
        isA<MusicRemoteUnavailableException>(),
      );
    });

    test('shouldMap500ToServerFailure', () async {
      await expectMusicStatusFailure(
        500,
        isA<MusicRemoteServerException>(),
      );
    });

    test('shouldMapConnectionTimeout', () async {
      await expectMusicTransportFailure(
        DioExceptionType.connectionTimeout,
        isA<MusicRemoteTimeoutException>(),
      );
    });

    test('shouldMapConnectionError', () async {
      await expectMusicTransportFailure(
        DioExceptionType.connectionError,
        isA<MusicRemoteNetworkException>(),
      );
    });

    test('shouldMapMalformedCatalog', () async {
      final dataSource = createMusicDataSource(
        FakeHttpClientAdapter(responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.getAvailableTracks(),
        throwsA(isA<MusicRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapMalformedStorySoundtrack', () async {
      final dataSource = createStorySoundtrackDataSource(
        FakeHttpClientAdapter(responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.getStorySoundtrack('story-id'),
        throwsA(isA<MusicRemoteMalformedResponseException>()),
      );
    });

    test('shouldNotExposeRawResponseInException', () async {
      final dataSource = createStorySoundtrackDataSource(
        FakeHttpClientAdapter(
          statusCode: 404,
          responseData: <String, Object?>{
            'detail': 'Story soundtrack was not found',
            'storageKey': 'private/storage/key',
          },
        ),
      );

      try {
        await dataSource.getStorySoundtrack('private-story-id');
        fail('Expected remote exception');
      } on MusicRemoteException catch (error) {
        expect(error.toString(), 'MusicRemoteUnavailableException');
        expect(error.toString(), isNot(contains('private-story-id')));
        expect(error.toString(), isNot(contains('storageKey')));
        expect(error, isNot(isA<DioException>()));
      }
    });
  });
}

DioMusicRemoteDataSource createMusicDataSource(FakeHttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioMusicRemoteDataSource(dio);
}

DioStorySoundtrackRemoteDataSource createStorySoundtrackDataSource(
  FakeHttpClientAdapter adapter,
) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioStorySoundtrackRemoteDataSource(dio);
}

Future<void> expectMusicStatusFailure(
  int statusCode,
  Matcher matcher,
) async {
  final dataSource = createMusicDataSource(
    FakeHttpClientAdapter(statusCode: statusCode, responseData: <Object?>[]),
  );

  await expectLater(
    dataSource.getAvailableTracks(),
    throwsA(matcher),
  );
}

Future<void> expectMusicTransportFailure(
  DioExceptionType type,
  Matcher matcher,
) async {
  final adapter = FakeHttpClientAdapter(
    failure: DioException(
      requestOptions: RequestOptions(path: '/api/v1/music/tracks'),
      type: type,
    ),
  );
  final dataSource = createMusicDataSource(adapter);

  await expectLater(
    dataSource.getAvailableTracks(),
    throwsA(matcher),
  );
}

Map<String, Object?> validTrackJson({
  String id = 'track-id',
  String title = 'Autumn Leaves',
  String artist = 'LofCosmos',
  int durationSeconds = 270,
}) {
  return <String, Object?>{
    'id': id,
    'title': title,
    'artist': artist,
    'durationSeconds': durationSeconds,
  };
}

Map<String, Object?> noMusicJson() {
  return <String, Object?>{
    'selectedSoundtrack': null,
    'effectiveSoundtrack': null,
  };
}

Map<String, Object?> selectedJson() {
  return <String, Object?>{
    'selectedSoundtrack': validTrackJson(),
    'effectiveSoundtrack': validTrackJson(),
  };
}

MusicTrack track({
  String id = 'track-id',
  String title = 'Autumn Leaves',
  String artist = 'LofCosmos',
  int durationSeconds = 270,
}) {
  return MusicTrack(
    id: id,
    title: title,
    artist: artist,
    durationSeconds: durationSeconds,
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

final class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({
    this.statusCode = 200,
    this.responseData,
    this.failure,
  });

  final int statusCode;
  final Object? responseData;
  final DioException? failure;

  int fetchCalls = 0;
  String? lastMethod;
  String? lastPath;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCalls += 1;
    lastMethod = options.method;
    lastPath = options.path;
    lastBody = await decodeRequestBody(requestStream);

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
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

Future<Object?> decodeRequestBody(Stream<Uint8List>? requestStream) async {
  if (requestStream == null) {
    return null;
  }

  final bytes = await requestStream.expand((chunk) => chunk).toList();
  if (bytes.isEmpty) {
    return null;
  }

  return jsonDecode(utf8.decode(bytes));
}

String encodeResponseBody(Object? responseData) {
  if (responseData == null) {
    return '';
  }

  return jsonEncode(responseData);
}
