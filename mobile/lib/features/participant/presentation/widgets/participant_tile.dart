import 'package:flutter/material.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _participantInk = Color(0xFF182331);
const _participantMuted = Color(0xFF747B86);
const _participantAccent = Color(0xFFD16A74);
const _participantAccentSoft = Color(0xFFFFEEF0);
const _participantAccentDisabled = Color(0x7AD16A74);
const _participantWarmWhite = Color(0xFFFFFDFB);
const _participantWarmBorder = Color(0x1FD16A74);

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
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ParticipantAvatar(participant: participant),
            const SizedBox(width: 13),
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
                          color: _participantInk,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
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
                              color: _participantAccentSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _participantWarmBorder,
                              ),
                            ),
                            child: Text(
                              l10n.participantsCurrentUser,
                              style: const TextStyle(
                                color: _participantAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
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
                    child: _ParticipantRoleBadge(role: participant.role),
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
                    backgroundColor: _participantAccentSoft,
                    disabledBackgroundColor: _participantAccentSoft,
                    foregroundColor: _participantAccent,
                    disabledForegroundColor: _participantAccentDisabled,
                  ),
                  icon: isRemoving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _participantAccent,
                          ),
                        )
                      : const Icon(Icons.close_rounded),
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
        radius: 28,
        foregroundImage: NetworkImage(avatarUrl),
        onForegroundImageError: (_, __) {},
        backgroundColor: _participantAccentSoft,
        child: _ParticipantInitials(participant: participant),
      );
    }

    return ClipOval(
      child: SizedBox.square(
        dimension: 56,
        child: AuthenticatedMediaPathImage(
          thumbnailPath: avatarUrl,
          representation: AuthenticatedMediaRepresentation.display,
          fit: BoxFit.cover,
          cacheWidth: 112,
          cacheHeight: 112,
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
      radius: 28,
      backgroundColor: _participantAccentSoft,
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
        color: _participantAccent,
        fontSize: 18,
        fontWeight: FontWeight.w800,
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

class _ParticipantRoleBadge extends StatelessWidget {
  const _ParticipantRoleBadge({
    required this.role,
  });

  final StoryRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = _colors(role);
    final label = _label(l10n, role);

    return Semantics(
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(role),
              size: 14,
              color: colors.foreground,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, StoryRole role) {
    return switch (role) {
      StoryRole.owner => l10n.storyRoleOwner,
      StoryRole.coOwner => l10n.storyRoleCoOwner,
      StoryRole.editor => l10n.storyRoleEditor,
      StoryRole.viewer => l10n.storyRoleViewer,
    };
  }

  IconData _icon(StoryRole role) {
    return switch (role) {
      StoryRole.owner => Icons.workspace_premium_rounded,
      StoryRole.coOwner => Icons.group_rounded,
      StoryRole.editor => Icons.edit_rounded,
      StoryRole.viewer => Icons.visibility_rounded,
    };
  }

  _ParticipantRoleBadgeColors _colors(StoryRole role) {
    return switch (role) {
      StoryRole.owner => const _ParticipantRoleBadgeColors(
          background: _participantAccentSoft,
          border: _participantWarmBorder,
          foreground: _participantAccent,
        ),
      StoryRole.coOwner => const _ParticipantRoleBadgeColors(
          background: Color(0xFFF6EEE3),
          border: Color(0x1F8D6B4D),
          foreground: Color(0xFF6F5D4F),
        ),
      StoryRole.editor => const _ParticipantRoleBadgeColors(
          background: Color(0xFFF3EFEC),
          border: Color(0x1F182331),
          foreground: _participantInk,
        ),
      StoryRole.viewer => const _ParticipantRoleBadgeColors(
          background: _participantWarmWhite,
          border: Color(0x26747B86),
          foreground: _participantMuted,
        ),
    };
  }
}

final class _ParticipantRoleBadgeColors {
  const _ParticipantRoleBadgeColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}
