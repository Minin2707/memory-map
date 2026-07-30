final class AuthTokens {
  factory AuthTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError('accessToken must not be blank');
    }

    if (refreshToken.trim().isEmpty) {
      throw ArgumentError('refreshToken must not be blank');
    }

    return AuthTokens._(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  const AuthTokens._({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthTokens &&
            accessToken == other.accessToken &&
            refreshToken == other.refreshToken;
  }

  @override
  int get hashCode => Object.hash(
        accessToken,
        refreshToken,
      );

  @override
  String toString() => 'AuthTokens[REDACTED]';
}
