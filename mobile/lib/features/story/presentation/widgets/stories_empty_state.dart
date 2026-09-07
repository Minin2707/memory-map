import 'package:flutter/material.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _storiesEmptyHeroAsset = 'assets/hero_stories_empty_state.png';
const _storiesEmptyBackground = Color(0xFFFBF6F1);
const _storiesEmptyInk = Color(0xFF182331);
const _storiesEmptyMuted = Color(0xFF747B86);
const _storiesEmptyButton = Color(0xFFC45A66);
const _storiesEmptyDisplayFontFamily = 'NotoSerif';
const _storiesEmptyHeroVisibleHeightRatio = 1.12;

class StoriesEmptyState extends StatelessWidget {
  const StoriesEmptyState({
    this.onCreateStory,
    super.key,
  });

  final VoidCallback? onCreateStory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final availableWidth = mediaSize.width - 16;
    final availableHeight = mediaSize.height - mediaPadding.vertical;
    final desiredHeroWidth =
        (availableWidth * 0.92).clamp(280.0, 430.0).toDouble();
    final heightBasedHeroHeight =
        (availableHeight * 0.64).clamp(300.0, 540.0).toDouble();
    final heightLimitedHeroWidth =
        heightBasedHeroHeight / _storiesEmptyHeroVisibleHeightRatio;
    final heroImageWidth = desiredHeroWidth < heightLimitedHeroWidth
        ? desiredHeroWidth
        : heightLimitedHeroWidth;
    final heroHeight = heroImageWidth * _storiesEmptyHeroVisibleHeightRatio;
    final bottomFadeHeight =
        (heroHeight * 0.15).clamp(42.0, 72.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: SizedBox(
            width: double.infinity,
            height: heroHeight,
            child: _StoriesEmptyHero(
              imageWidth: heroImageWidth,
              bottomFadeHeight: bottomFadeHeight,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Text(
            l10n.storiesEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _storiesEmptyInk,
              fontFamily: _storiesEmptyDisplayFontFamily,
              fontFamilyFallback: <String>['NotoSerifGeorgian'],
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Text(
            l10n.storiesEmptyDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _storiesEmptyMuted,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 286),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('stories.empty.create-action'),
              onPressed: onCreateStory,
              style: FilledButton.styleFrom(
                backgroundColor: _storiesEmptyButton,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              child: Text(l10n.storiesCreateFirstAction),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoriesEmptyHero extends StatelessWidget {
  const _StoriesEmptyHero({
    required this.imageWidth,
    required this.bottomFadeHeight,
  });

  final double imageWidth;
  final double bottomFadeHeight;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              child: SizedBox(
                width: imageWidth,
                child: Image.asset(
                  _storiesEmptyHeroAsset,
                  alignment: Alignment.topCenter,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomFadeHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _storiesEmptyBackground.withValues(alpha: 0),
                    _storiesEmptyBackground.withValues(alpha: 0.42),
                    _storiesEmptyBackground,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
