final class AuthUser {
  factory AuthUser({
    required String id,
    required String displayName,
    String? avatarUrl,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('id must not be blank');
    }

    if (displayName.trim().isEmpty) {
      throw ArgumentError('displayName must not be blank');
    }

    return AuthUser._(
      id: id,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  const AuthUser._({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthUser &&
            id == other.id &&
            displayName == other.displayName &&
            avatarUrl == other.avatarUrl;
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        avatarUrl,
      );

  @override
  String toString() {
    return 'AuthUser(id: $id, displayName: $displayName, avatarUrl: $avatarUrl)';
  }
}
