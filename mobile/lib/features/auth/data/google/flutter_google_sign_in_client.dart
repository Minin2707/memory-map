import 'package:google_sign_in/google_sign_in.dart';
import 'package:memory_map/features/auth/data/google/google_sign_in_client.dart';

final class FlutterGoogleSignInClient implements GoogleSignInClient {
  FlutterGoogleSignInClient({
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  @override
  Future<void> initialize({
    required String serverClientId,
    String? clientId,
  }) async {
    _initialization ??= _initialize(
      serverClientId: serverClientId,
      clientId: clientId,
    );

    await _initialization;
  }

  @override
  bool supportsAuthenticate() {
    return _googleSignIn.supportsAuthenticate();
  }

  @override
  Future<String?> authenticateAndGetIdToken() async {
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const GoogleSignInClientException(
        GoogleSignInClientFailureCode.unavailable,
      );
    }

    try {
      final account = await _googleSignIn.authenticate();

      return account.authentication.idToken;
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    } on Object {
      throw const GoogleSignInClientException(
        GoogleSignInClientFailureCode.failed,
      );
    }
  }

  Future<void> _initialize({
    required String serverClientId,
    String? clientId,
  }) async {
    try {
      await _googleSignIn.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
      );
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    } on Object {
      throw const GoogleSignInClientException(
        GoogleSignInClientFailureCode.failed,
      );
    }
  }

  GoogleSignInClientException _mapGoogleSignInException(
    GoogleSignInException error,
  ) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return const GoogleSignInClientException(
          GoogleSignInClientFailureCode.cancelled,
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
      case GoogleSignInExceptionCode.uiUnavailable:
        return const GoogleSignInClientException(
          GoogleSignInClientFailureCode.unavailable,
        );
      default:
        return const GoogleSignInClientException(
          GoogleSignInClientFailureCode.failed,
        );
    }
  }
}
