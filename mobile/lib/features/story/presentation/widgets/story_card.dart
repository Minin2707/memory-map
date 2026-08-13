import 'package:flutter/material.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
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
    final description = story.description;
    final visibleDescription = description == null || description.trim().isEmpty
        ? null
        : description;

    return Semantics(
      button: onSelected != null,
      label: l10n.storiesOpenStoryLabel(story.title),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_cardRadius),
          onTap: onSelected == null
              ? null
              : () {
                  onSelected!(story.id);
                },
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_cardRadius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x100F172A),
                  offset: Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final previewSize =
                      constraints.maxWidth < 320 ? 92.0 : _previewSize;
                  final contentGap = constraints.maxWidth < 320 ? 10.0 : 13.0;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StoryPreview(
                        userStory: userStory,
                        size: previewSize,
                      ),
                      SizedBox(width: contentGap),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: previewSize),
                          child: _StoryContent(
                            userStory: userStory,
                            title: story.title,
                            description: visibleDescription,
                          ),
                        ),
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

class _StoryPreview extends StatelessWidget {
  const _StoryPreview({
    required this.userStory,
    required this.size,
  });

  final UserStory userStory;
  final double size;

  @override
  Widget build(BuildContext context) {
    final preview = userStory.previewPhoto;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      image: preview != null,
      label: preview == null ? null : l10n.storyThumbnailLabel,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            key: preview == null
                ? const ValueKey('story-card.no-photo')
                : const ValueKey('story-card.thumbnail'),
            width: size,
            height: size,
            child: preview == null
                ? _NoPhotoState(userStory: userStory)
                : AuthenticatedMediaPathImage(
                    thumbnailPath: preview.thumbnailPath,
                    fit: BoxFit.cover,
                    placeholder: _PhotoPlaceholder(role: userStory.role),
                    errorBuilder: (_) => _PhotoUnavailableState(
                      userStory: userStory,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({
    required this.role,
  });

  final StoryRole role;

  @override
  Widget build(BuildContext context) {
    final colors = _markColors(role);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.first.withValues(alpha: 0.22),
            colors.last.withValues(alpha: 0.12),
          ],
        ),
      ),
    );
  }
}

class _PhotoUnavailableState extends StatelessWidget {
  const _PhotoUnavailableState({
    required this.userStory,
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    return _IntentionalPhotoState(
      key: const ValueKey('story-card.thumbnail-unavailable'),
      userStory: userStory,
      icon: Icons.image_not_supported_outlined,
    );
  }
}

class _NoPhotoState extends StatelessWidget {
  const _NoPhotoState({
    required this.userStory,
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    return _IntentionalPhotoState(
      userStory: userStory,
      icon: Icons.photo_outlined,
    );
  }
}

class _IntentionalPhotoState extends StatelessWidget {
  const _IntentionalPhotoState({
    required this.userStory,
    required this.icon,
    super.key,
  });

  final UserStory userStory;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = _markColors(userStory.role);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.first.withValues(alpha: 0.26),
            colors.last.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 12,
            bottom: 10,
            child: Icon(
              icon,
              color: colors.last.withValues(alpha: 0.52),
              size: 25,
            ),
          ),
          Text(
            _initials(userStory.story.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.last,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({
    required this.userStory,
    required this.title,
    required this.description,
  });

  final UserStory userStory;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.14,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: StoryRoleBadge(
                role: userStory.role,
                showIcon: false,
                compact: true,
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.32,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 13),
        _StoryFooter(userStory: userStory),
      ],
    );
  }
}

class _StoryFooter extends StatelessWidget {
  const _StoryFooter({
    required this.userStory,
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Flexible(
          child: _Counter(
            icon: Icons.location_on_outlined,
            label: l10n.storyMemoryCount(userStory.memoryCount),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: _Counter(
            icon: Icons.group_outlined,
            label: l10n.storyParticipantCount(userStory.participantCount),
          ),
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF6B7280),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            key: icon == Icons.location_on_outlined
                ? const ValueKey('story-card.memory-count')
                : const ValueKey('story-card.participant-count'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

const double _cardRadius = 22;
const double _previewSize = 104;

List<Color> _markColors(StoryRole role) {
  return switch (role) {
    StoryRole.owner => const [Color(0xFFFFCBD2), Color(0xFFFF5D72)],
    StoryRole.coOwner => const [Color(0xFFFFE4AD), Color(0xFFE49323)],
    StoryRole.editor => const [Color(0xFFCFE4FF), Color(0xFF4C83D8)],
    StoryRole.viewer => const [Color(0xFFE4E7EC), Color(0xFF8C95A3)],
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
