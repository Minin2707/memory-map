import 'dart:async';

import 'package:dio/dio.dart';
import 'package:memory_map/features/auth/application/authorized_session_exception.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/authorized_session_manager.dart';

typedef AuthorizedRequestRetry = Future<Response<Object?>> Function(
  RequestOptions options,
);

final class AuthorizedAuthInterceptor extends Interceptor {
  AuthorizedAuthInterceptor({
    required AuthorizedSessionManager sessionManager,
    AuthorizedRequestRetry? retryRequest,
  })  : _sessionManager = sessionManager,
        _retryRequest = retryRequest;

  static const String _retryMarker = 'memory_map.auth.retry';

  final AuthorizedSessionManager _sessionManager;
  AuthorizedRequestRetry? _retryRequest;

  Future<AuthSession>? _refreshInFlight;

  void attachRetryRequest(AuthorizedRequestRetry retryRequest) {
    _retryRequest = retryRequest;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    unawaited(_handleRequest(options, handler));
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    unawaited(_handleError(err, handler));
  }

  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthEndpoint(options.path)) {
      handler.next(options);
      return;
    }

    final session = await _sessionManager.getCurrentSession();
    if (session == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const AuthorizedSessionUnavailableException(),
        ),
      );
      return;
    }

    options.headers['Authorization'] =
        'Bearer ${session.tokens.accessToken}';
    handler.next(options);
  }

  Future<void> _handleError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;
    if (response?.statusCode != 401 ||
        _isAuthEndpoint(options.path) ||
        !_isReplayable(options)) {
      handler.next(err);
      return;
    }

    if (options.extra[_retryMarker] == true) {
      await _invalidateCurrentSession();
      handler.next(err);
      return;
    }

    final failedSession = await _sessionManager.getCurrentSession();
    if (failedSession == null) {
      handler.next(err);
      return;
    }

    final AuthSession refreshedSession;
    try {
      refreshedSession = await _refreshOnce(failedSession);
    } on AuthorizedSessionException {
      handler.next(err);
      return;
    }

    final retryRequest = _retryRequest;
    if (retryRequest == null) {
      handler.next(err);
      return;
    }

    try {
      final retryResponse = await retryRequest(
        _retryOptions(options, refreshedSession),
      );
      handler.resolve(retryResponse);
    } on DioException catch (retryError) {
      if (retryError.response?.statusCode == 401 &&
          retryError.requestOptions.extra[_retryMarker] != true) {
        await _sessionManager.invalidateCurrentSession(refreshedSession);
      }

      handler.next(retryError);
    }
  }

  Future<AuthSession> _refreshOnce(AuthSession failedSession) {
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refresh = _sessionManager.refreshCurrentSession(failedSession);
    _refreshInFlight = refresh;

    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<void> _invalidateCurrentSession() async {
    final currentSession = await _sessionManager.getCurrentSession();
    if (currentSession != null) {
      await _sessionManager.invalidateCurrentSession(currentSession);
    }
  }

  RequestOptions _retryOptions(
    RequestOptions original,
    AuthSession session,
  ) {
    final headers = Map<String, dynamic>.of(original.headers)
      ..['Authorization'] = 'Bearer ${session.tokens.accessToken}';
    final extra = Map<String, dynamic>.of(original.extra)
      ..[_retryMarker] = true;

    return original.copyWith(
      headers: headers,
      extra: extra,
    );
  }

  bool _isReplayable(RequestOptions options) {
    final data = options.data;

    return data is! FormData && data is! Stream;
  }

  bool _isAuthEndpoint(String path) {
    final parsedPath = Uri.tryParse(path)?.path ?? path;

    return parsedPath.startsWith('/api/v1/auth/');
  }
}
