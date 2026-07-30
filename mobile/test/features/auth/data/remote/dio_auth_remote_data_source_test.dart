import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/data/remote/auth_remote_exception.dart';
import 'package:memory_map/features/auth/data/remote/dio_auth_remote_data_source.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('DioAuthRemoteDataSource login', () {
    test('shouldPostGoogleLoginRequest', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        responseData: validLoginResponseJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.loginWithGoogle('raw-google-id-token');

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastBody, <String, Object?>{
        'idToken': 'raw-google-id-token',
      });
    });

    test('shouldUseGoogleLoginEndpoint', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        responseData: validLoginResponseJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.loginWithGoogle('raw-google-id-token');

      expect(adapter.lastPath, '/api/v1/auth/google');
    });

    test('shouldReturnAuthSession', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        responseData: validLoginResponseJson(),
      );
      final dataSource = createDataSource(adapter);

      final session = await dataSource.loginWithGoogle('raw-google-id-token');

      expect(session, createSession());
    });

    test('shouldNotSendAuthorizationHeader', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        responseData: validLoginResponseJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.loginWithGoogle('raw-google-id-token');

      expect(adapter.lastHeaders.containsKey('Authorization'), isFalse);
    });

    test('shouldRejectBlankGoogleIdTokenWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        responseData: validLoginResponseJson(),
      );
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.loginWithGoogle('   '),
        throwsA(argumentErrorWithMessage('idToken must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });

    test('shouldMapLogin401ToUnauthorized', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 401, responseData: problemJson()),
      );

      await expectLater(
        dataSource.loginWithGoogle('raw-google-id-token'),
        throwsA(isA<AuthRemoteUnauthorizedException>()),
      );
    });

    test('shouldMapLogin400ToValidationFailure', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 400, responseData: problemJson()),
      );

      await expectLater(
        dataSource.loginWithGoogle('raw-google-id-token'),
        throwsA(isA<AuthRemoteValidationException>()),
      );
    });

    test('shouldMapLogin500ToServerFailure', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 500, responseData: problemJson()),
      );

      await expectLater(
        dataSource.loginWithGoogle('raw-google-id-token'),
        throwsA(isA<AuthRemoteServerException>()),
      );
    });

    test('shouldMapMalformedLoginResponse', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 200, responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.loginWithGoogle('raw-google-id-token'),
        throwsA(isA<AuthRemoteMalformedResponseException>()),
      );
    });
  });

  group('DioAuthRemoteDataSource refresh', () {
    test('shouldPostRefreshTokenRequest', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        responseData: validTokensJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.refresh('raw-refresh-token');

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastBody, <String, Object?>{
        'refreshToken': 'raw-refresh-token',
      });
    });

    test('shouldUseRefreshEndpoint', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        responseData: validTokensJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.refresh('raw-refresh-token');

      expect(adapter.lastPath, '/api/v1/auth/refresh');
    });

    test('shouldReturnRotatedAuthTokens', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 200,
          responseData: <String, Object?>{
            'accessToken': 'new-access-token',
            'refreshToken': 'new-refresh-token',
          },
        ),
      );

      final tokens = await dataSource.refresh('raw-refresh-token');

      expect(
        tokens,
        AuthTokens(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
        ),
      );
    });

    test('shouldRejectBlankRefreshTokenWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        responseData: validTokensJson(),
      );
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.refresh('   '),
        throwsA(argumentErrorWithMessage('refreshToken must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });

    test('shouldMapRefresh401ToUnauthorized', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 401, responseData: problemJson()),
      );

      await expectLater(
        dataSource.refresh('raw-refresh-token'),
        throwsA(isA<AuthRemoteUnauthorizedException>()),
      );
    });

    test('shouldMapMalformedRefreshResponse', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 200, responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.refresh('raw-refresh-token'),
        throwsA(isA<AuthRemoteMalformedResponseException>()),
      );
    });
  });

  group('DioAuthRemoteDataSource logout', () {
    test('shouldPostLogoutRequest', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await dataSource.logout('raw-refresh-token');

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastBody, <String, Object?>{
        'refreshToken': 'raw-refresh-token',
      });
    });

    test('shouldUseLogoutEndpoint', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await dataSource.logout('raw-refresh-token');

      expect(adapter.lastPath, '/api/v1/auth/logout');
    });

    test('shouldAccept204WithoutBody', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 204),
      );

      await expectLater(
        dataSource.logout('raw-refresh-token'),
        completes,
      );
    });

    test('shouldRejectBlankLogoutRefreshTokenWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.logout('   '),
        throwsA(argumentErrorWithMessage('refreshToken must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });

    test('shouldMapLogout500ToServerFailure', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 500, responseData: problemJson()),
      );

      await expectLater(
        dataSource.logout('raw-refresh-token'),
        throwsA(isA<AuthRemoteServerException>()),
      );
    });
  });

  group('DioAuthRemoteDataSource transport', () {
    test('shouldMapConnectionTimeout', () async {
      await expectRemoteFailure(
        DioExceptionType.connectionTimeout,
        isA<AuthRemoteTimeoutException>(),
      );
    });

    test('shouldMapSendTimeout', () async {
      await expectRemoteFailure(
        DioExceptionType.sendTimeout,
        isA<AuthRemoteTimeoutException>(),
      );
    });

    test('shouldMapReceiveTimeout', () async {
      await expectRemoteFailure(
        DioExceptionType.receiveTimeout,
        isA<AuthRemoteTimeoutException>(),
      );
    });

    test('shouldMapConnectionError', () async {
      await expectRemoteFailure(
        DioExceptionType.connectionError,
        isA<AuthRemoteNetworkException>(),
      );
    });

    test('shouldMapBadCertificate', () async {
      await expectRemoteFailure(
        DioExceptionType.badCertificate,
        isA<AuthRemoteNetworkException>(),
      );
    });

    test('shouldMapUnknownDioFailure', () async {
      await expectRemoteFailure(
        DioExceptionType.unknown,
        isA<AuthRemoteUnknownException>(),
      );
    });

    test('shouldMapUnexpectedHttpStatus', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 409, responseData: problemJson()),
      );

      await expectLater(
        dataSource.loginWithGoogle('raw-google-id-token'),
        throwsA(isA<AuthRemoteUnknownException>()),
      );
    });

    test('shouldNotExposeGoogleIdTokenInExceptions', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 401, responseData: problemJson()),
      );

      try {
        await dataSource.loginWithGoogle('raw-google-id-token');
        fail('Expected remote exception');
      } on AuthRemoteException catch (error) {
        expect(error.toString(), isNot(contains('raw-google-id-token')));
        expect(error, isNot(isA<DioException>()));
      }
    });

    test('shouldNotExposeAccessOrRefreshTokenInExceptions', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 200,
          responseData: <String, Object?>{
            'accessToken': 123,
            'refreshToken': 'raw-refresh-token',
          },
        ),
      );

      try {
        await dataSource.refresh('raw-refresh-token');
        fail('Expected remote exception');
      } on AuthRemoteException catch (error) {
        expect(error.toString(), 'AuthRemoteMalformedResponseException');
        expect(error.toString(), isNot(contains('signed-access-token')));
        expect(error.toString(), isNot(contains('raw-refresh-token')));
        expect(error, isNot(isA<DioException>()));
      }
    });
  });
}

DioAuthRemoteDataSource createDataSource(FakeHttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioAuthRemoteDataSource(dio);
}

Future<void> expectRemoteFailure(
  DioExceptionType type,
  Matcher matcher,
) async {
  final adapter = FakeHttpClientAdapter(
    failure: DioException(
      requestOptions: RequestOptions(path: '/api/v1/auth/google'),
      type: type,
    ),
  );
  final dataSource = createDataSource(adapter);

  await expectLater(
    dataSource.loginWithGoogle('raw-google-id-token'),
    throwsA(matcher),
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

AuthSession createSession() {
  return AuthSession(
    user: AuthUser(
      id: 'user-id',
      displayName: 'Ada Lovelace',
      avatarUrl: 'https://example.com/avatar.png',
    ),
    tokens: AuthTokens(
      accessToken: 'signed-access-token',
      refreshToken: 'raw-refresh-token',
    ),
  );
}

Map<String, Object?> validLoginResponseJson() {
  return <String, Object?>{
    'user': validUserJson(),
    'accessToken': 'signed-access-token',
    'refreshToken': 'raw-refresh-token',
  };
}

Map<String, Object?> validUserJson() {
  return <String, Object?>{
    'id': 'user-id',
    'displayName': 'Ada Lovelace',
    'avatarUrl': 'https://example.com/avatar.png',
  };
}

Map<String, Object?> validTokensJson() {
  return <String, Object?>{
    'accessToken': 'signed-access-token',
    'refreshToken': 'raw-refresh-token',
  };
}

Map<String, Object?> problemJson() {
  return <String, Object?>{
    'title': 'Unauthorized',
    'status': 401,
    'detail': 'Authentication failed',
  };
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
  Map<String, dynamic> lastHeaders = <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCalls += 1;
    lastMethod = options.method;
    lastPath = options.path;
    lastHeaders = options.headers;
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
