abstract interface class GoogleSignInClient {
  Future<void> initialize({
    required String serverClientId,
    String? clientId,
  });

  bool supportsAuthenticate();

  Future<String?> authenticateAndGetIdToken();
}

enum GoogleSignInClientFailureCode {
  cancelled,
  unavailable,
  failed,
}

final class GoogleSignInClientException implements Exception {
  const GoogleSignInClientException(this.code);

  final GoogleSignInClientFailureCode code;

  @override
  String toString() => 'GoogleSignInClientException';
}
