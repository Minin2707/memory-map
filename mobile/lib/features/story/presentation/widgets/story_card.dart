import 'package:flutter/material.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/widgets/story_role_badge.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({
    required this.userStory,
    this.onSelected,
    super.key,
  });

  final UserStory userStory;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final story = userStory.story;
    final description = story.description?.trim();

    return Semantics(
      button: onSelected != null,
      label: l10n.storiesOpenStoryLabel(story.title),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onSelected == null
              ? null
              : () {
                  onSelected!(story.id);
                },
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  offset: Offset(0, 10),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 330) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StoryMark(userStory: userStory),
                            const SizedBox(width: 12),
                            Flexible(
                              child: StoryRoleBadge(role: userStory.role),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _StoryText(
                          title: story.title,
                          description: description,
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StoryMark(userStory: userStory),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StoryText(
                          title: story.title,
                          description: description,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 136),
                        child: StoryRoleBadge(role: userStory.role),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryText extends StatelessWidget {
  const _StoryText({
    required this.title,
    required this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final visibleDescription =
        description == null || description!.isEmpty ? null : description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: 0,
          ),
        ),
        if (visibleDescription != null) ...[
          const SizedBox(height: 10),
          Text(
            visibleDescription,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _StoryMark extends StatelessWidget {
  const _StoryMark({
    required this.userStory,
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    final colors = _markColors(userStory.role);

    return ExcludeSemantics(
      child: Container(
        width: 92,
        height: 92,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          _initials(userStory.story.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  List<Color> _markColors(StoryRole role) {
    return switch (role) {
      StoryRole.owner => const [Color(0xFFFF8A99), Color(0xFFFF5D72)],
      StoryRole.coOwner => const [Color(0xFFFFC46B), Color(0xFFE49323)],
      StoryRole.editor => const [Color(0xFF8EC5FF), Color(0xFF4C83D8)],
      StoryRole.viewer => const [Color(0xFFC9CED6), Color(0xFF8C95A3)],
    };
  }

  String _initials(String title) {
    final words = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return '?';
    }

    return words.take(2).map((word) => word.substring(0, 1)).join();
  }
}
