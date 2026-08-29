import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/profile/data/remote/account_remote_exception.dart';
import 'package:memory_map/features/profile/data/remote/dio_account_remote_data_source.dart';

void main() {
  group('DioAccountRemoteDataSource deleteCurrentAccount', () {
    test('shouldSendDeleteCurrentAccountRequest', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 204);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await dataSource.deleteCurrentAccount();

      expect(adapter.requestOptions?.method, 'DELETE');
      expect(adapter.requestOptions?.path, '/api/v1/me');
      expect(adapter.requestOptions?.data, isNull);
    });

    test('shouldMapOwnershipConflict', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 409);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.deleteCurrentAccount(),
        throwsA(isA<AccountRemoteOwnershipConflictException>()),
      );
    });

    test('shouldMapUnauthorizedResponse', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 401);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.deleteCurrentAccount(),
        throwsA(isA<AccountRemoteUnauthorizedException>()),
      );
    });

    test('shouldMapServerFailure', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 500);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.deleteCurrentAccount(),
        throwsA(isA<AccountRemoteServerException>()),
      );
    });

    test('shouldRejectUnexpectedSuccessStatus', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 200);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.deleteCurrentAccount(),
        throwsA(isA<AccountRemoteUnknownException>()),
      );
    });

    test('shouldMapNetworkFailure', () async {
      final adapter = RecordingHttpClientAdapter()
        ..failure = DioExceptionType.connectionError;
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.deleteCurrentAccount(),
        throwsA(isA<AccountRemoteNetworkException>()),
      );
    });
  });

  group('DioAccountRemoteDataSource avatar', () {
    test('shouldUploadCurrentUserAvatar', () async {
      final adapter = RecordingHttpClientAdapter(
        statusCode: 200,
        body: '''
          {
            "id": "user-id",
            "displayName": "Ada Lovelace",
            "avatarUrl": "/api/v1/me/avatar/1",
            "hasCustomAvatar": true
          }
        ''',
      );
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      final user = await dataSource.uploadCurrentUserAvatar(
        PreparedPhotoUpload(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          contentType: 'image/jpeg',
        ),
      );

      expect(adapter.requestOptions?.method, 'PUT');
      expect(adapter.requestOptions?.path, '/api/v1/me/avatar');
      expect(adapter.requestOptions?.data, isA<FormData>());
      expect(user.avatarUrl, '/api/v1/me/avatar/1');
      expect(user.hasCustomAvatar, isTrue);
    });

    test('shouldRemoveCurrentUserAvatar', () async {
      final adapter = RecordingHttpClientAdapter(
        statusCode: 200,
        body: '''
          {
            "id": "user-id",
            "displayName": "Ada Lovelace",
            "avatarUrl": "https://example.com/avatar.png",
            "hasCustomAvatar": false
          }
        ''',
      );
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      final user = await dataSource.removeCurrentUserAvatar();

      expect(adapter.requestOptions?.method, 'DELETE');
      expect(adapter.requestOptions?.path, '/api/v1/me/avatar');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
      expect(user.hasCustomAvatar, isFalse);
    });

    test('shouldMapInvalidAvatarRequest', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 400);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.uploadCurrentUserAvatar(
          PreparedPhotoUpload(
            bytes: Uint8List.fromList(<int>[1]),
            contentType: 'image/jpeg',
          ),
        ),
        throwsA(isA<AccountRemoteValidationException>()),
      );
    });

    test('shouldMapOversizedAvatarRequest', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 413);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.uploadCurrentUserAvatar(
          PreparedPhotoUpload(
            bytes: Uint8List.fromList(<int>[1]),
            contentType: 'image/jpeg',
          ),
        ),
        throwsA(isA<AccountRemoteValidationException>()),
      );
    });

    test('shouldMapUnsupportedAvatarMediaType', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 415);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.uploadCurrentUserAvatar(
          PreparedPhotoUpload(
            bytes: Uint8List.fromList(<int>[1]),
            contentType: 'image/jpeg',
          ),
        ),
        throwsA(isA<AccountRemoteValidationException>()),
      );
    });
  });

  group('DioAccountRemoteDataSource updateDisplayName', () {
    test('shouldPatchCurrentUserDisplayName', () async {
      final adapter = RecordingHttpClientAdapter(
        statusCode: 200,
        body: '''
          {
            "id": "user-id",
            "displayName": "Анна-Мария O'Connor",
            "avatarUrl": "https://example.com/avatar.png",
            "hasCustomAvatar": false
          }
        ''',
      );
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      final user = await dataSource.updateDisplayName(
        "Анна-Мария O'Connor",
      );

      expect(adapter.requestOptions?.method, 'PATCH');
      expect(adapter.requestOptions?.path, '/api/v1/me/display-name');
      expect(adapter.requestOptions?.data, <String, Object?>{
        'displayName': "Анна-Мария O'Connor",
      });
      expect(user.displayName, "Анна-Мария O'Connor");
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('shouldMapInvalidDisplayNameRequest', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 400);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.updateDisplayName(''),
        throwsA(isA<AccountRemoteValidationException>()),
      );
    });

    test('shouldMapUnauthorizedDisplayNameRequest', () async {
      final adapter = RecordingHttpClientAdapter(statusCode: 401);
      final dataSource = DioAccountRemoteDataSource(createDio(adapter));

      await expectLater(
        dataSource.updateDisplayName('Ada'),
        throwsA(isA<AccountRemoteUnauthorizedException>()),
      );
    });
  });
}

Dio createDio(HttpClientAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..httpClientAdapter = adapter;
}

final class RecordingHttpClientAdapter implements HttpClientAdapter {
  RecordingHttpClientAdapter({this.statusCode = 204, this.body = ''});

  final int statusCode;
  final String body;
  DioExceptionType? failure;
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;

    final failureType = failure;
    if (failureType != null) {
      throw DioException(
        requestOptions: options,
        type: failureType,
        error: const Object(),
      );
    }

    return ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
