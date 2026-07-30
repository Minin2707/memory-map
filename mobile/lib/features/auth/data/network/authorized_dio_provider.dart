import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/core/config/app_config.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/data/network/authorized_auth_interceptor.dart';

final authorizedAuthInterceptorProvider =
    Provider<AuthorizedAuthInterceptor>((ref) {
  return AuthorizedAuthInterceptor(
    sessionManager: ref.watch(authorizedSessionManagerProvider),
  );
});

final authorizedDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final interceptor = ref.watch(authorizedAuthInterceptorProvider)
    ..attachRetryRequest((options) => dio.fetch<Object?>(options));

  dio.interceptors.add(interceptor);
  ref.onDispose(dio.close);

  return dio;
});
