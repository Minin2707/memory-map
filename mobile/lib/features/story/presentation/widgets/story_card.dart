import 'package:flutter/material.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
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

    return Semantics(
      button: onSelected != null,
      label: l10n.storiesOpenStoryLabel(story.title),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
          child: SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(_cardRadius),
                onTap: onSelected == null
                    ? null
                    : () {
                        onSelected!(story.id);
                      },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_cardRadius),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6ECE5),
                      borderRadius: BorderRadius.circular(_cardRadius),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x144D2B32),
                          offset: Offset(0, 14),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.24,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _StoryPreview(userStory: userStory),
                          const _StoryScrim(),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 24,
                            child: _StoryOverlayContent(
                              userStory: userStory,
                              title: story.title,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    final preview = userStory.previewPhoto;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      image: preview != null,
      label: preview == null ? null : l10n.storyThumbnailLabel,
      child: ExcludeSemantics(
        child: SizedBox.expand(
          key: preview == null
              ? const ValueKey('story-card.no-photo')
              : const ValueKey('story-card.thumbnail'),
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
            colors.first.withValues(alpha: 0.32),
            colors.last.withValues(alpha: 0.18),
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
            colors.first.withValues(alpha: 0.34),
            const Color(0xFFF3E6DC),
            colors.last.withValues(alpha: 0.24),
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
              color: colors.last.withValues(alpha: 0.42),
              size: 48,
            ),
          ),
          Text(
            _initials(userStory.story.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.last.withValues(alpha: 0.82),
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryScrim extends StatelessWidget {
  const _StoryScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.34, 0.68, 0.84, 1],
          colors: [
            Color(0x00000000),
            Color(0x24111827),
            Color(0x5C111827),
            Color(0x9C111827),
          ],
        ),
      ),
    );
  }
}

class _StoryOverlayContent extends StatelessWidget {
  const _StoryOverlayContent({
    required this.userStory,
    required this.title,
  });

  final UserStory userStory;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0,
            shadows: [
              Shadow(
                color: Color(0x66000000),
                offset: Offset(0, 1),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
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
    final memoryCount = l10n.storyMemoryCount(userStory.memoryCount);
    final participantCount = l10n.storyParticipantCount(
      userStory.participantCount,
    );

    return Row(
      children: [
        Flexible(
          child: Text(
            memoryCount,
            key: const ValueKey('story-card.memory-count'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _metadataStyle,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: _metadataStyle,
          ),
        ),
        Flexible(
          child: Text(
            participantCount,
            key: const ValueKey('story-card.participant-count'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _metadataStyle,
          ),
        ),
      ],
    );
  }
}

const double _cardRadius = 22;
const double _cardMaxWidth = 560;
const _metadataStyle = TextStyle(
  color: Color(0xD9FFFFFF),
  fontSize: 13,
  fontWeight: FontWeight.w500,
  height: 1.2,
  letterSpacing: 0,
);

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
