import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/core/config/app_config.dart';
import 'package:memory_map/features/auth/data/google/flutter_google_sign_in_client.dart';
import 'package:memory_map/features/auth/data/google/google_sign_in_client.dart';
import 'package:memory_map/features/auth/domain/google_identity_exception.dart';
import 'package:memory_map/features/auth/domain/google_identity_provider.dart';

final googleSignInClientProvider = Provider<GoogleSignInClient>((_) {
  return FlutterGoogleSignInClient();
});

final googleIdentityProvider = Provider<GoogleIdentityProvider>((ref) {
  final config = ref.watch(appConfigProvider);

  return GoogleSignInIdentityProvider(
    client: ref.watch(googleSignInClientProvider),
    serverClientId: config.googleServerClientId,
    iosClientId: config.googleIosClientId,
  );
});

final class GoogleSignInIdentityProvider
    implements GoogleIdentityProvider {
  GoogleSignInIdentityProvider({
    required GoogleSignInClient client,
    required String serverClientId,
    String? iosClientId,
  })  : _client = client,
        _serverClientId = serverClientId,
        _iosClientId = iosClientId;

  final GoogleSignInClient _client;
  final String _serverClientId;
  final String? _iosClientId;
  Future<void>? _initialization;

  @override
  Future<String> requestIdToken() async {
    if (_serverClientId.trim().isEmpty) {
      throw const GoogleIdentityUnavailableException();
    }

    try {
      await _ensureInitialized();

      if (!_client.supportsAuthenticate()) {
        throw const GoogleIdentityUnavailableException();
      }

      final idToken = await _client.authenticateAndGetIdToken();
      if (idToken == null || idToken.trim().isEmpty) {
        throw const GoogleIdentityAuthenticationException();
      }

      return idToken;
    } on GoogleIdentityException {
      rethrow;
    } on GoogleSignInClientException catch (error) {
      throw _mapClientException(error);
    } on Object {
      throw const GoogleIdentityAuthenticationException();
    }
  }

  Future<void> _ensureInitialized() async {
    _initialization ??= _client.initialize(
      serverClientId: _serverClientId,
      clientId: _normalizedIosClientId(),
    );

    await _initialization;
  }

  String? _normalizedIosClientId() {
    final iosClientId = _iosClientId;
    if (iosClientId == null || iosClientId.trim().isEmpty) {
      return null;
    }

    return iosClientId;
  }

  GoogleIdentityException _mapClientException(
    GoogleSignInClientException error,
  ) {
    return switch (error.code) {
      GoogleSignInClientFailureCode.cancelled =>
        const GoogleIdentityCancelledException(),
      GoogleSignInClientFailureCode.unavailable =>
        const GoogleIdentityUnavailableException(),
      GoogleSignInClientFailureCode.failed =>
        const GoogleIdentityAuthenticationException(),
    };
  }
}
