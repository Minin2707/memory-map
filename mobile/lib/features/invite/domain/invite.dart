final class Invite {
  factory Invite({
    required Uri inviteLink,
    required DateTime expiresAt,
  }) {
    if (inviteLink.toString().trim().isEmpty) {
      throw ArgumentError('inviteLink must not be blank');
    }

    return Invite._(
      inviteLink: inviteLink,
      expiresAt: expiresAt.toUtc(),
    );
  }

  const Invite._({
    required this.inviteLink,
    required this.expiresAt,
  });

  final Uri inviteLink;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Invite &&
            inviteLink == other.inviteLink &&
            expiresAt == other.expiresAt;
  }

  @override
  int get hashCode => Object.hash(
        inviteLink,
        expiresAt,
      );

  @override
  String toString() {
    return 'Invite(inviteLink: <redacted>, expiresAt: $expiresAt)';
  }
}
