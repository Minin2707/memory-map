final class AcceptInviteInput {
  factory AcceptInviteInput({
    required String rawToken,
  }) {
    if (rawToken.trim().isEmpty) {
      throw ArgumentError('rawToken must not be blank');
    }

    return AcceptInviteInput._(rawToken: rawToken);
  }

  const AcceptInviteInput._({
    required this.rawToken,
  });

  final String rawToken;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AcceptInviteInput && rawToken == other.rawToken;
  }

  @override
  int get hashCode => rawToken.hashCode;

  @override
  String toString() => 'AcceptInviteInput';
}
