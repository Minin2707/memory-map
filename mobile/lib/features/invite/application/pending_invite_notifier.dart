import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/invite/application/pending_invite_state.dart';

final pendingInviteProvider =
    NotifierProvider<PendingInviteNotifier, PendingInviteState>(
      PendingInviteNotifier.new,
    );

final class PendingInviteNotifier extends Notifier<PendingInviteState> {
  @override
  PendingInviteState build() {
    return const PendingInviteState();
  }

  void setToken(String rawToken) {
    if (rawToken.trim().isEmpty) {
      throw ArgumentError.value('', 'rawToken', 'Invite token must not be blank');
    }

    if (state.rawToken == rawToken) {
      return;
    }

    state = PendingInviteState(rawToken: rawToken);
  }

  String? takeToken() {
    final token = state.rawToken;
    state = const PendingInviteState();
    return token;
  }

  void clear() {
    if (!state.hasInvite) {
      return;
    }

    state = const PendingInviteState();
  }
}
