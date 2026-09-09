import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/music/application/music_catalog_notifier.dart';
import 'package:memory_map/features/music/application/music_catalog_state.dart';
import 'package:memory_map/features/music/application/story_soundtrack_notifier.dart';
import 'package:memory_map/features/music/application/story_soundtrack_state.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/presentation/music_duration_format.dart';
import 'package:memory_map/features/music/presentation/music_failure_message.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _pickerBackground = Color(0xFFFBF6F1);
const _pickerInk = Color(0xFF182331);
const _pickerMuted = Color(0xFF747B86);
const _pickerAccent = Color(0xFFD16A74);
const _pickerAccentSoft = Color(0xFFFFEEF0);
const _pickerWarmWhite = Color(0xFFFFFDFB);
const _pickerWarmBorder = Color(0xFFEFE5E1);
const _pickerDisplayFontFamily = 'NotoSerif';
const _pickerDisplayFontFallback = <String>['NotoSerifGeorgian'];

class SoundtrackSelectionScreen extends ConsumerWidget {
  const SoundtrackSelectionScreen({
    required this.storyId,
    this.onBack,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyValue = ref.watch(storyDetailsProvider(storyId));
    final soundtrackValue = ref.watch(storySoundtrackProvider(storyId));
    final catalogValue = ref.watch(musicCatalogProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: _pickerBackground,
        body: _SoundtrackSelectionBody(
          storyId: storyId,
          onBack: onBack,
          storyValue: storyValue,
          soundtrackValue: soundtrackValue,
          catalogValue: catalogValue,
        ),
      ),
    );
  }
}

class _SoundtrackSelectionBody extends ConsumerWidget {
  const _SoundtrackSelectionBody({
    required this.storyId,
    required this.onBack,
    required this.storyValue,
    required this.soundtrackValue,
    required this.catalogValue,
  });

  final String storyId;
  final VoidCallback? onBack;
  final AsyncValue<StoryDetailsState> storyValue;
  final AsyncValue<StorySoundtrackState> soundtrackValue;
  final AsyncValue<MusicCatalogState> catalogValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (storyValue.isLoading) {
      return _SoundtrackPageFrame(
        onBack: onBack,
        child: const _ScreenLoading(),
      );
    }

    if (storyValue.hasError) {
      return _SoundtrackPageFrame(
        onBack: onBack,
        child: _ScreenFailure(
          title: l10n.storyDetailsLoadFailureTitle,
          message: l10n.storyFailureUnknown,
          onRetry: () {
            ref.read(storyDetailsProvider(storyId).notifier).retryLoad();
          },
        ),
      );
    }

    final storyState = storyValue.asData?.value;
    final storyFailure = storyState?.loadFailure;
    if (storyFailure != null) {
      return _SoundtrackPageFrame(
        onBack: onBack,
        child: _ScreenFailure(
          title: l10n.storyDetailsLoadFailureTitle,
          message: storyFailureMessage(l10n, storyFailure),
          onRetry: () {
            ref.read(storyDetailsProvider(storyId).notifier).retryLoad();
          },
        ),
      );
    }

    final userStory = storyState?.userStory;
    if (userStory == null) {
      return _SoundtrackPageFrame(
        onBack: onBack,
        child: _ScreenFailure(
          title: l10n.storyDetailsLoadFailureTitle,
          message: l10n.storyFailureUnknown,
          onRetry: () {
            ref.read(storyDetailsProvider(storyId).notifier).retryLoad();
          },
        ),
      );
    }

    final editable = _canEditSoundtrack(userStory.role);

    return _SoundtrackPageFrame(
      onBack: onBack,
      readOnly: !editable,
      child: ListView(
        key: const ValueKey('soundtrack-selection.screen'),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
        children: [
          _StorySoundtrackPanel(
            storyId: storyId,
            editable: editable,
            soundtrackValue: soundtrackValue,
          ),
          const SizedBox(height: 24),
          _CatalogPanel(
            storyId: storyId,
            editable: editable,
            soundtrackValue: soundtrackValue,
            catalogValue: catalogValue,
          ),
        ],
      ),
    );
  }
}

class _SoundtrackPageFrame extends StatelessWidget {
  const _SoundtrackPageFrame({
    required this.onBack,
    required this.child,
    this.readOnly = false,
  });

  final VoidCallback? onBack;
  final Widget child;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditorialHeader(onBack: onBack, readOnly: readOnly),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EditorialHeader extends StatelessWidget {
  const _EditorialHeader({
    required this.onBack,
    required this.readOnly,
  });

  final VoidCallback? onBack;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            key: const ValueKey('soundtrack-selection.back-action'),
            tooltip: l10n.storyDetailsBackLabel,
            onPressed: onBack,
            color: _pickerInk,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              l10n.soundtrackChooseTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _pickerInk,
                fontSize: 32,
                height: 1.08,
                fontWeight: FontWeight.w500,
                fontFamily: _pickerDisplayFontFamily,
                fontFamilyFallback: _pickerDisplayFontFallback,
                letterSpacing: 0,
              ),
            ),
          ),
          if (readOnly)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: Text(
                l10n.soundtrackReadOnly,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _pickerMuted,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StorySoundtrackPanel extends ConsumerWidget {
  const _StorySoundtrackPanel({
    required this.storyId,
    required this.editable,
    required this.soundtrackValue,
  });

  final String storyId;
  final bool editable;
  final AsyncValue<StorySoundtrackState> soundtrackValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (soundtrackValue.isLoading) {
      return const _InlineLoading(
        key: ValueKey('soundtrack-selection.soundtrack.loading'),
      );
    }

    if (soundtrackValue.hasError) {
      return _InlineFailure(
        title: l10n.soundtrackLoadFailureTitle,
        message: l10n.musicFailureUnavailable,
        retryKey: const ValueKey('soundtrack-selection.soundtrack.retry'),
        onRetry: () {
          ref.read(storySoundtrackProvider(storyId).notifier).retryLoad();
        },
      );
    }

    final state = soundtrackValue.asData?.value;
    final loadFailure = state?.loadFailure;
    if (loadFailure != null) {
      return _InlineFailure(
        title: l10n.soundtrackLoadFailureTitle,
        message: musicFailureMessage(l10n, loadFailure),
        retryKey: const ValueKey('soundtrack-selection.soundtrack.retry'),
        onRetry: () {
          ref.read(storySoundtrackProvider(storyId).notifier).retryLoad();
        },
      );
    }

    final soundtrack = state?.soundtrack;
    final unavailableTrack = soundtrack?.isSelectedUnavailable == true
        ? soundtrack!.selectedSoundtrack
        : null;

    final children = <Widget>[
      if (unavailableTrack != null) ...[
        Text(
          l10n.soundtrackCurrentSelection,
          style: _sectionTitleStyle,
        ),
        const SizedBox(height: 12),
        _UnavailableSelection(
          track: unavailableTrack,
          editable: editable,
        ),
      ],
      if (state?.mutationFailure != null) ...[
        if (unavailableTrack != null) const SizedBox(height: 12),
        _MutationFailure(message: l10n.soundtrackUpdateFailure),
      ],
      if (state?.isMutating == true) ...[
        if (unavailableTrack != null || state?.mutationFailure != null)
          const SizedBox(height: 12),
        const _MutationProgress(),
      ],
    ];

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _MutationProgress extends StatelessWidget {
  const _MutationProgress();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: LinearProgressIndicator(
        minHeight: 2,
        color: _pickerAccent,
        backgroundColor: _pickerAccentSoft,
      ),
    );
  }
}

class _UnavailableSelection extends StatelessWidget {
  const _UnavailableSelection({
    required this.track,
    required this.editable,
  });

  final MusicTrack track;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('soundtrack-selection.selected-unavailable'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _pickerAccentSoft.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _pickerAccent.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrackText(track: track),
          const SizedBox(height: 8),
          Text(
            editable
                ? l10n.soundtrackUnavailableEditable
                : l10n.soundtrackCurrentlyUnavailable,
            style: const TextStyle(
              color: _pickerAccent,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogPanel extends ConsumerWidget {
  const _CatalogPanel({
    required this.storyId,
    required this.editable,
    required this.soundtrackValue,
    required this.catalogValue,
  });

  final String storyId;
  final bool editable;
  final AsyncValue<StorySoundtrackState> soundtrackValue;
  final AsyncValue<MusicCatalogState> catalogValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            l10n.soundtrackCatalogTitle,
            textAlign: TextAlign.center,
            style: _sectionTitleStyle.copyWith(
              color: const Color(0xFF8A746A),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _NoMusicRow(
          storyId: storyId,
          editable: editable,
          soundtrackValue: soundtrackValue,
        ),
        const SizedBox(height: 10),
        _CatalogBody(
          storyId: storyId,
          editable: editable,
          soundtrackValue: soundtrackValue,
          catalogValue: catalogValue,
        ),
      ],
    );
  }
}

class _CatalogBody extends ConsumerWidget {
  const _CatalogBody({
    required this.storyId,
    required this.editable,
    required this.soundtrackValue,
    required this.catalogValue,
  });

  final String storyId;
  final bool editable;
  final AsyncValue<StorySoundtrackState> soundtrackValue;
  final AsyncValue<MusicCatalogState> catalogValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (catalogValue.isLoading) {
      return const _InlineLoading(
        key: ValueKey('soundtrack-selection.catalog.loading'),
      );
    }

    if (catalogValue.hasError) {
      return _InlineFailure(
        title: l10n.soundtrackCatalogLoadFailureTitle,
        message: l10n.musicFailureUnavailable,
        retryKey: const ValueKey('soundtrack-selection.catalog.retry'),
        onRetry: () {
          ref.read(musicCatalogProvider.notifier).retryLoad();
        },
      );
    }

    final state = catalogValue.asData?.value;
    final loadFailure = state?.loadFailure;
    if (loadFailure != null) {
      return _InlineFailure(
        title: l10n.soundtrackCatalogLoadFailureTitle,
        message: musicFailureMessage(l10n, loadFailure),
        retryKey: const ValueKey('soundtrack-selection.catalog.retry'),
        onRetry: () {
          ref.read(musicCatalogProvider.notifier).retryLoad();
        },
      );
    }

    final tracks = state?.tracks ?? const <MusicTrack>[];
    if (tracks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
        child: Text(
          l10n.soundtrackCatalogEmpty,
          key: const ValueKey('soundtrack-selection.catalog.empty'),
          style: _bodyStyle,
        ),
      );
    }

    final soundtrackState = soundtrackValue.asData?.value;
    final selectedTrackId =
        soundtrackState?.soundtrack?.effectiveSoundtrack?.id;
    final disabled = !editable ||
        soundtrackState == null ||
        !soundtrackState.isLoaded ||
        soundtrackState.isMutating;

    return Column(
      children: [
        for (var index = 0; index < tracks.length; index += 1) ...[
          if (index > 0) const SizedBox(height: 10),
          _TrackRow(
            key: ValueKey('soundtrack-selection.track.${tracks[index].id}'),
            track: tracks[index],
            selected: tracks[index].id == selectedTrackId,
            disabled: disabled,
            onTap: disabled
                ? null
                : () {
                    ref
                        .read(storySoundtrackProvider(storyId).notifier)
                        .setSoundtrack(tracks[index].id);
                  },
          ),
        ],
      ],
    );
  }
}

class _NoMusicRow extends ConsumerWidget {
  const _NoMusicRow({
    required this.storyId,
    required this.editable,
    required this.soundtrackValue,
  });

  final String storyId;
  final bool editable;
  final AsyncValue<StorySoundtrackState> soundtrackValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = soundtrackValue.asData?.value;
    final selected = state?.soundtrack?.isNoMusic == true;
    final disabled =
        !editable || state == null || !state.isLoaded || state.isMutating;

    return _OptionRow(
      key: const ValueKey('soundtrack-selection.no-music-row'),
      leading: Icons.music_off_rounded,
      title: AppLocalizations.of(context).soundtrackNoMusic,
      subtitle: null,
      selected: selected,
      disabled: disabled,
      onTap: disabled
          ? null
          : () {
              ref
                  .read(storySoundtrackProvider(storyId).notifier)
                  .removeSoundtrack();
            },
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.selected,
    required this.disabled,
    required this.onTap,
    super.key,
  });

  final MusicTrack track;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _OptionRow(
      leading: Icons.library_music_rounded,
      title: track.title,
      subtitle:
          '${track.artist} · ${formatMusicDuration(track.durationSeconds)}',
      selected: selected,
      disabled: disabled,
      onTap: onTap,
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.disabled,
    required this.onTap,
    super.key,
  });

  final IconData leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = disabled ? 0.58 : 1.0;
    final borderColor = selected
        ? _pickerAccent.withValues(alpha: 0.42)
        : _pickerWarmBorder.withValues(alpha: 0.72);
    final iconColor = disabled
        ? _pickerMuted.withValues(alpha: 0.62)
        : selected
            ? _pickerAccent
            : _pickerMuted;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: selected
            ? _pickerAccentSoft.withValues(alpha: 0.54)
            : _pickerWarmWhite.withValues(alpha: 0.84),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                Icon(leading, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _pickerInk,
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _pickerMuted,
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 10),
                  const _SelectedIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedIndicator extends StatelessWidget {
  const _SelectedIndicator();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.check_circle_rounded,
      color: _pickerAccent,
      size: 20,
    );
  }
}

class _TrackText extends StatelessWidget {
  const _TrackText({
    required this.track,
  });

  final MusicTrack track;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _pickerInk,
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _bodyStyle,
        ),
      ],
    );
  }
}

class _MutationFailure extends StatelessWidget {
  const _MutationFailure({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('soundtrack-selection.mutation.failure'),
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: _pickerAccent,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: _pickerMuted,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: LinearProgressIndicator(
        minHeight: 3,
        color: _pickerAccent,
        backgroundColor: _pickerAccentSoft,
      ),
    );
  }
}

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({
    required this.title,
    required this.message,
    required this.retryKey,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Key retryKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: _pickerAccent,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$title. $message',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _pickerMuted,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        TextButton(
          key: retryKey,
          onPressed: onRetry,
          child: Text(l10n.retry),
        ),
      ],
    );
  }
}

class _ScreenLoading extends StatelessWidget {
  const _ScreenLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: _pickerAccent,
      ),
    );
  }
}

class _ScreenFailure extends StatelessWidget {
  const _ScreenFailure({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: _pickerAccent,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: _sectionTitleStyle,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: _bodyStyle,
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('soundtrack-selection.story.retry'),
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: _pickerAccent,
                ),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _pickerWarmWhite.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _pickerWarmBorder.withValues(alpha: 0.72),
        ),
      ),
      child: child,
    );
  }
}

const _sectionTitleStyle = TextStyle(
  color: _pickerInk,
  fontSize: 17,
  height: 1.2,
  fontWeight: FontWeight.w700,
  fontFamily: _pickerDisplayFontFamily,
  fontFamilyFallback: _pickerDisplayFontFallback,
  letterSpacing: 0,
);

const _bodyStyle = TextStyle(
  color: _pickerMuted,
  fontSize: 14,
  height: 1.35,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

bool _canEditSoundtrack(StoryRole role) {
  return role == StoryRole.owner || role == StoryRole.coOwner;
}
