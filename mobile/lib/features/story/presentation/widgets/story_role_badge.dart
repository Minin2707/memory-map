import 'package:flutter/material.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class StoryRoleBadge extends StatelessWidget {
  const StoryRoleBadge({
    required this.role,
    super.key,
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
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(role),
              size: 16,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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

  _BadgeColors _colors(StoryRole role) {
    return switch (role) {
      StoryRole.owner => const _BadgeColors(
          background: Color(0xFFFFE6EA),
          foreground: Color(0xFFFF5D72),
        ),
      StoryRole.coOwner => const _BadgeColors(
          background: Color(0xFFFFF1D6),
          foreground: Color(0xFFD98200),
        ),
      StoryRole.editor => const _BadgeColors(
          background: Color(0xFFE4F0FF),
          foreground: Color(0xFF2F70C8),
        ),
      StoryRole.viewer => const _BadgeColors(
          background: Color(0xFFF0F1F3),
          foreground: Color(0xFF6B7280),
        ),
    };
  }
}

final class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
