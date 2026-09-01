import 'package:flutter/material.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/story/presentation/widgets/story_role_badge.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class ParticipantTile extends StatelessWidget {
  const ParticipantTile({
    required this.participant,
    required this.isCurrentUser,
    this.showRemoveAction = false,
    this.removeEnabled = true,
    this.isRemoving = false,
    this.onRemove,
    super.key,
  });

  final StoryParticipant participant;
  final bool isCurrentUser;
  final bool showRemoveAction;
  final bool removeEnabled;
  final bool isRemoving;
  final ValueChanged<StoryParticipant>? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final removeAction = onRemove;

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ParticipantAvatar(participant: participant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        participant.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      if (isCurrentUser)
                        Semantics(
                          label: l10n.participantsCurrentUser,
                          child: Container(
                            key: const ValueKey(
                              'participants.current-user-marker',
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE6EA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              l10n.participantsCurrentUser,
                              style: const TextStyle(
                                color: Color(0xFFFF5D72),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StoryRoleBadge(role: participant.role),
                  ),
                ],
              ),
            ),
            if (showRemoveAction && removeAction != null) ...[
              const SizedBox(width: 10),
              Semantics(
                label: l10n.participantsRemoveParticipantLabel(
                  participant.displayName,
                ),
                button: true,
                enabled: removeEnabled && !isRemoving,
                child: IconButton.filledTonal(
                  key: ValueKey(
                    'participants.remove-action.${participant.userId}',
                  ),
                  onPressed: isRemoving || !removeEnabled
                      ? null
                      : () {
                          removeAction(participant);
                        },
                  tooltip: l10n.participantsRemoveParticipantLabel(
                    participant.displayName,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F3),
                    disabledBackgroundColor: const Color(0xFFFFF1F3),
                    foregroundColor: const Color(0xFFFF5D72),
                    disabledForegroundColor: const Color(0xFFFFB3BD),
                  ),
                  icon: isRemoving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF5D72),
                          ),
                        )
                      : const Icon(Icons.person_remove_alt_1_rounded),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({
    required this.participant,
  });

  final StoryParticipant participant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatarUrl = participant.avatarUrl?.trim();
    final fallback = _ParticipantAvatarFallback(participant: participant);

    return Semantics(
      label: l10n.participantsAvatarLabel(participant.displayName),
      image: true,
      child: _avatar(avatarUrl, fallback),
    );
  }

  Widget _avatar(String? avatarUrl, Widget fallback) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return fallback;
    }

    final uri = Uri.tryParse(avatarUrl);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return CircleAvatar(
        radius: 32,
        foregroundImage: NetworkImage(avatarUrl),
        onForegroundImageError: (_, __) {},
        backgroundColor: const Color(0xFFFFE6EA),
        child: _ParticipantInitials(participant: participant),
      );
    }

    return ClipOval(
      child: SizedBox.square(
        dimension: 64,
        child: AuthenticatedMediaPathImage(
          thumbnailPath: avatarUrl,
          representation: AuthenticatedMediaRepresentation.display,
          fit: BoxFit.cover,
          cacheWidth: 128,
          cacheHeight: 128,
          placeholder: fallback,
          errorBuilder: (_) => fallback,
        ),
      ),
    );
  }
}

class _ParticipantAvatarFallback extends StatelessWidget {
  const _ParticipantAvatarFallback({
    required this.participant,
  });

  final StoryParticipant participant;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 32,
      backgroundColor: const Color(0xFFFFE6EA),
      child: _ParticipantInitials(participant: participant),
    );
  }
}

class _ParticipantInitials extends StatelessWidget {
  const _ParticipantInitials({
    required this.participant,
  });

  final StoryParticipant participant;

  @override
  Widget build(BuildContext context) {
    return Text(
      _initials(participant.displayName),
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: const TextStyle(
        color: Color(0xFFFF5D72),
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return '?';
    }

    return words
        .take(2)
        .map((word) => word.substring(0, 1))
        .join()
        .toUpperCase();
  }
}
