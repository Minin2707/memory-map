import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/authorized_session_exception.dart';
import 'package:memory_map/features/auth/data/network/authorized_auth_interceptor.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/auth/domain/authorized_session_manager.dart';

void main() {
  group('AuthorizedAuthInterceptor request', () {
    test('shouldAddBearerAccessToken', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 200)],
      );
      final dio = createDio(adapter, FakeAuthorizedSessionManager());

      await dio.get<Object?>('/protected');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer signed-access-token',
      );
    });

    test('shouldReplaceExistingAuthorizationHeader', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 200)],
      );
      final dio = createDio(adapter, FakeAuthorizedSessionManager());

      await dio.get<Object?>(
        '/protected',
        options: Options(
          headers: <String, Object?>{
            'Authorization': 'Bearer stale-token',
          },
        ),
      );

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer signed-access-token',
      );
    });

    test('shouldRejectProtectedRequestWhenSessionUnavailable', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 200)],
      );
      final manager = FakeAuthorizedSessionManager()..session = null;
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'error',
            const AuthorizedSessionUnavailableException(),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    });

    test('shouldNotAddBearerToAuthEndpoints', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 200)],
      );
      final manager = FakeAuthorizedSessionManager()..session = null;
      final dio = createDio(adapter, manager);

      await dio.post<Object?>('/api/v1/auth/refresh');

      expect(
        adapter.requests.single.headers.containsKey(
          'Authorization',
        ),
        isFalse,
      );
    });

    test('shouldNotExposeTokenInErrors', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 500)],
      );
      final dio = createDio(adapter, FakeAuthorizedSessionManager());

      try {
        await dio.get<Object?>('/protected');
        fail('Expected DioException');
      } on DioException catch (error) {
        expect(error.toString(), isNot(contains('signed-access-token')));
        expect(error.toString(), isNot(contains('raw-refresh-token')));
      }
    });
  });

  group('AuthorizedAuthInterceptor 401 refresh', () {
    test('shouldRefreshAfter401', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 200),
        ],
      );
      final manager = FakeAuthorizedSessionManager();
      final dio = createDio(adapter, manager);

      await dio.get<Object?>('/protected');

      expect(manager.refreshCalls, 1);
    });

    test('shouldRetryOriginalRequestWithNewAccessToken', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 200),
        ],
      );
      final dio = createDio(adapter, FakeAuthorizedSessionManager());

      await dio.get<Object?>('/protected');

      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer new-access-token',
      );
    });

    test('shouldRetryOnlyOnce', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 401),
        ],
      );
      final manager = FakeAuthorizedSessionManager();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(manager.refreshCalls, 1);
      expect(adapter.requests, hasLength(2));
    });

    test('shouldNotRefreshRetried401', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 401),
        ],
      );
      final manager = FakeAuthorizedSessionManager();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(manager.refreshCalls, 1);
    });

    test('shouldInvalidateAfterRetried401', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 401),
        ],
      );
      final manager = FakeAuthorizedSessionManager();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(manager.invalidateCalls, 1);
    });

    test('shouldNotRefreshAuthEndpoint401', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 401)],
      );
      final manager = FakeAuthorizedSessionManager();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.post<Object?>('/api/v1/auth/refresh'),
        throwsA(isA<DioException>()),
      );

      expect(manager.refreshCalls, 0);
    });
  });

  group('AuthorizedAuthInterceptor concurrency', () {
    test('shouldUseSingleRefreshForConcurrent401Responses', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 200),
          ResponseSpec(statusCode: 200),
        ],
      );
      final refreshCompleter = Completer<AuthSession>();
      final manager = FakeAuthorizedSessionManager()
        ..refreshCompleter = refreshCompleter;
      final dio = createDio(adapter, manager);

      final first = dio.get<Object?>('/protected/1');
      final second = dio.get<Object?>('/protected/2');
      await pumpEventQueue();
      refreshCompleter.complete(refreshedSession);
      await Future.wait([first, second]);

      expect(manager.refreshCalls, 1);
    });

    test('shouldMakeAllWaitingRequestsUseSameNewAccessToken', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 200),
          ResponseSpec(statusCode: 200),
        ],
      );
      final refreshCompleter = Completer<AuthSession>();
      final manager = FakeAuthorizedSessionManager()
        ..refreshCompleter = refreshCompleter;
      final dio = createDio(adapter, manager);

      final first = dio.get<Object?>('/protected/1');
      final second = dio.get<Object?>('/protected/2');
      await pumpEventQueue();
      refreshCompleter.complete(refreshedSession);
      await Future.wait([first, second]);

      expect(
        adapter.requests.skip(2).map(
              (request) => request.headers['Authorization'],
            ),
        everyElement('Bearer new-access-token'),
      );
    });

    test('shouldClearSingleFlightAfterFailure', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 401),
        ],
      );
      final manager = FakeAuthorizedSessionManager()
        ..refreshFailure = const AuthorizedSessionRefreshException();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected/1'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.get<Object?>('/protected/2'),
        throwsA(isA<DioException>()),
      );

      expect(manager.refreshCalls, 2);
    });
  });

  group('AuthorizedAuthInterceptor failure', () {
    test('shouldNotRetryWhenRefreshIsInvalid', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 401)],
      );
      final manager = FakeAuthorizedSessionManager()
        ..refreshFailure = const AuthorizedSessionInvalidException();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, hasLength(1));
    });

    test('shouldNotRetryWhenRefreshTemporarilyFails', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 401)],
      );
      final manager = FakeAuthorizedSessionManager()
        ..refreshFailure = const AuthorizedSessionRefreshException();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, hasLength(1));
    });

    test('shouldPreserveSessionOnTemporaryRefreshFailure', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 401)],
      );
      final manager = FakeAuthorizedSessionManager()
        ..refreshFailure = const AuthorizedSessionRefreshException();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(manager.session, session);
    });

    test('shouldBecomeUnauthenticatedOnInvalidRefresh', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 401)],
      );
      final manager = FakeAuthorizedSessionManager()
        ..refreshFailure = const AuthorizedSessionInvalidException();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(manager.session, isNull);
    });
  });

  group('AuthorizedAuthInterceptor replay', () {
    test('shouldNotAutomaticallyRetryFormDataRequest', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 401)],
      );
      final manager = FakeAuthorizedSessionManager();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.post<Object?>(
          '/protected',
          data: FormData.fromMap(<String, Object?>{'name': 'memory'}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(manager.refreshCalls, 0);
    });

    test('shouldNotAutomaticallyRetryStreamRequest', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [ResponseSpec(statusCode: 401)],
      );
      final manager = FakeAuthorizedSessionManager();
      final dio = createDio(adapter, manager);

      await expectLater(
        dio.post<Object?>(
          '/protected',
          data: Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('stream-body'),
          ]),
        ),
        throwsA(isA<DioException>()),
      );

      expect(manager.refreshCalls, 0);
    });

    test('shouldRetryJsonRequest', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 200),
        ],
      );
      final dio = createDio(adapter, FakeAuthorizedSessionManager());

      await dio.post<Object?>(
        '/protected',
        data: <String, Object?>{'name': 'memory'},
      );

      expect(adapter.requests, hasLength(2));
    });

    test('shouldPreserveMethodPathQueryHeadersAndBody', () async {
      final adapter = FakeHttpClientAdapter(
        responses: [
          ResponseSpec(statusCode: 401),
          ResponseSpec(statusCode: 200),
        ],
      );
      final dio = createDio(adapter, FakeAuthorizedSessionManager());

      await dio.post<Object?>(
        '/protected',
        queryParameters: <String, Object?>{'page': 1},
        data: <String, Object?>{'name': 'memory'},
        options: Options(headers: <String, Object?>{'X-Trace': 'trace-id'}),
      );

      final retry = adapter.requests.last;
      expect(retry.method, 'POST');
      expect(retry.path, '/protected');
      expect(retry.queryParameters, <String, Object?>{'page': '1'});
      expect(retry.body, <String, Object?>{'name': 'memory'});
      expect(retry.headers['X-Trace'], 'trace-id');
    });
  });
}

Dio createDio(
  FakeHttpClientAdapter adapter,
  FakeAuthorizedSessionManager manager,
) {
  late final Dio dio;
  final interceptor = AuthorizedAuthInterceptor(
    sessionManager: manager,
  )..attachRetryRequest((options) => dio.fetch<Object?>(options));

  dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.com',
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )
    ..httpClientAdapter = adapter
    ..interceptors.add(interceptor);

  return dio;
}

final class FakeAuthorizedSessionManager
    implements AuthorizedSessionManager {
  AuthSession? session = sessionFixture;
  int refreshCalls = 0;
  int invalidateCalls = 0;
  Object? refreshFailure;
  Completer<AuthSession>? refreshCompleter;

  @override
  Future<AuthSession?> getCurrentSession() async {
    return session;
  }

  @override
  Future<AuthSession> refreshCurrentSession(AuthSession currentSession) async {
    refreshCalls += 1;

    final completer = refreshCompleter;
    if (completer != null) {
      final refreshed = await completer.future;
      session = refreshed;
      return refreshed;
    }

    final failure = refreshFailure;
    if (failure != null) {
      if (failure is AuthorizedSessionInvalidException) {
        session = null;
      }
      throw failure;
    }

    session = refreshedSession;
    return refreshedSession;
  }

  @override
  Future<void> invalidateCurrentSession(AuthSession currentSession) async {
    invalidateCalls += 1;
    session = null;
  }

  @override
  Future<AuthSession?> updateCurrentSessionUserIfStillCurrent({
    required AuthSession expectedSession,
    required AuthUser updatedUser,
  }) {
    throw UnimplementedError();
  }
}

final class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({required List<ResponseSpec> responses})
      : _responses = responses;

  final List<ResponseSpec> _responses;
  final List<RequestSnapshot> requests = <RequestSnapshot>[];
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      RequestSnapshot(
        method: options.method,
        path: options.path,
        queryParameters: Map<String, Object?>.of(
          options.queryParameters.map(
            (key, value) => MapEntry(key, value?.toString()),
          ),
        ),
        headers: Map<String, dynamic>.of(options.headers),
        body: await decodeRequestBody(requestStream),
      ),
    );

    final response = _responses[_index];
    _index += 1;

    return ResponseBody.fromString(
      encodeResponseBody(response.data),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class ResponseSpec {
  const ResponseSpec({
    required this.statusCode,
    this.data,
  });

  final int statusCode;
  final Object? data;
}

final class RequestSnapshot {
  const RequestSnapshot({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, Object?> queryParameters;
  final Map<String, dynamic> headers;
  final Object? body;
}

Future<Object?> decodeRequestBody(Stream<Uint8List>? requestStream) async {
  if (requestStream == null) {
    return null;
  }

  final bytes = await requestStream.expand((chunk) => chunk).toList();
  if (bytes.isEmpty) {
    return null;
  }

  final rawBody = utf8.decode(bytes);
  try {
    return jsonDecode(rawBody);
  } on FormatException {
    return rawBody;
  }
}

String encodeResponseBody(Object? data) {
  if (data == null) {
    return '';
  }

  return jsonEncode(data);
}

final AuthSession sessionFixture = AuthSession(
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

final AuthSession session = sessionFixture;

final AuthSession refreshedSession = AuthSession(
  user: session.user,
  tokens: AuthTokens(
    accessToken: 'new-access-token',
    refreshToken: 'new-refresh-token',
  ),
);
