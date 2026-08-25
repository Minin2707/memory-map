import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/music/application/music_catalog_notifier.dart';
import 'package:memory_map/features/music/application/music_catalog_state.dart';
import 'package:memory_map/features/music/application/story_soundtrack_notifier.dart';
import 'package:memory_map/features/music/application/story_soundtrack_state.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/presentation/music_duration_format.dart';
import 'package:memory_map/features/music/presentation/music_failure_message.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
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
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F8FA),
          surfaceTintColor: const Color(0xFFF7F8FA),
          elevation: 0,
          leading: IconButton(
            key: const ValueKey('soundtrack-selection.back-action'),
            tooltip: l10n.storyDetailsBackLabel,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(l10n.soundtrackChooseTitle),
        ),
        body: _SoundtrackSelectionBody(
          storyId: storyId,
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
    required this.storyValue,
    required this.soundtrackValue,
    required this.catalogValue,
  });

  final String storyId;
  final AsyncValue<StoryDetailsState> storyValue;
  final AsyncValue<StorySoundtrackState> soundtrackValue;
  final AsyncValue<MusicCatalogState> catalogValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (storyValue.isLoading) {
      return const _ScreenLoading();
    }

    if (storyValue.hasError) {
      return _ScreenFailure(
        title: l10n.storyDetailsLoadFailureTitle,
        message: l10n.storyFailureUnknown,
        onRetry: () {
          ref.read(storyDetailsProvider(storyId).notifier).retryLoad();
        },
      );
    }

    final storyState = storyValue.asData?.value;
    final storyFailure = storyState?.loadFailure;
    if (storyFailure != null) {
      return _ScreenFailure(
        title: l10n.storyDetailsLoadFailureTitle,
        message: storyFailureMessage(l10n, storyFailure),
        onRetry: () {
          ref.read(storyDetailsProvider(storyId).notifier).retryLoad();
        },
      );
    }

    final userStory = storyState?.userStory;
    if (userStory == null) {
      return _ScreenFailure(
        title: l10n.storyDetailsLoadFailureTitle,
        message: l10n.storyFailureUnknown,
        onRetry: () {
          ref.read(storyDetailsProvider(storyId).notifier).retryLoad();
        },
      );
    }

    final editable = _canEditSoundtrack(userStory.role);

    return ListView(
      key: const ValueKey('soundtrack-selection.screen'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        _HeaderCard(
          title: userStory.story.title,
          editable: editable,
        ),
        const SizedBox(height: 16),
        _StorySoundtrackPanel(
          storyId: storyId,
          editable: editable,
          soundtrackValue: soundtrackValue,
        ),
        const SizedBox(height: 16),
        _CatalogPanel(
          storyId: storyId,
          editable: editable,
          soundtrackValue: soundtrackValue,
          catalogValue: catalogValue,
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.editable,
  });

  final String title;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _Panel(
      child: Row(
        children: [
          const Icon(
            Icons.music_note_rounded,
            color: Color(0xFFFF5D72),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.soundtrackTitle,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (!editable)
            Text(
              l10n.soundtrackReadOnly,
              style: const TextStyle(
                color: Color(0xFF8A93A3),
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
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
      return const _Panel(
        child: _InlineLoading(
          key: ValueKey('soundtrack-selection.soundtrack.loading'),
        ),
      );
    }

    if (soundtrackValue.hasError) {
      return _Panel(
        child: _InlineFailure(
          title: l10n.soundtrackLoadFailureTitle,
          message: l10n.musicFailureUnavailable,
          retryKey: const ValueKey('soundtrack-selection.soundtrack.retry'),
          onRetry: () {
            ref.read(storySoundtrackProvider(storyId).notifier).retryLoad();
          },
        ),
      );
    }

    final state = soundtrackValue.asData?.value;
    final loadFailure = state?.loadFailure;
    if (loadFailure != null) {
      return _Panel(
        child: _InlineFailure(
          title: l10n.soundtrackLoadFailureTitle,
          message: musicFailureMessage(l10n, loadFailure),
          retryKey: const ValueKey('soundtrack-selection.soundtrack.retry'),
          onRetry: () {
            ref.read(storySoundtrackProvider(storyId).notifier).retryLoad();
          },
        ),
      );
    }

    final soundtrack = state?.soundtrack;
    final unavailableTrack = soundtrack?.isSelectedUnavailable == true
        ? soundtrack!.selectedSoundtrack
        : null;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.soundtrackCurrentSelection,
            style: _sectionTitleStyle,
          ),
          const SizedBox(height: 12),
          if (unavailableTrack == null)
            _CurrentSelectionText(soundtrack: soundtrack)
          else
            _UnavailableSelection(
              track: unavailableTrack,
              editable: editable,
            ),
          if (state?.mutationFailure != null) ...[
            const SizedBox(height: 12),
            _MutationFailure(message: l10n.soundtrackUpdateFailure),
          ],
          if (state?.isMutating == true) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 3,
              color: Color(0xFFFF5D72),
              backgroundColor: Color(0xFFFFE6EA),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentSelectionText extends StatelessWidget {
  const _CurrentSelectionText({
    required this.soundtrack,
  });

  final StorySoundtrack? soundtrack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final track = soundtrack?.selectedSoundtrack;

    if (track == null) {
      return Text(
        l10n.soundtrackNoMusic,
        style: _bodyStyle,
      );
    }

    return _TrackText(track: track);
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
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD6DC)),
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
              color: Color(0xFFFF5D72),
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

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.soundtrackCatalogTitle, style: _sectionTitleStyle),
          const SizedBox(height: 12),
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
      ),
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
      trailing: selected
          ? _SelectedBadge(text: AppLocalizations.of(context).soundtrackSelected)
          : null,
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
      trailing: selected
          ? _SelectedBadge(text: AppLocalizations.of(context).soundtrackSelected)
          : null,
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
    required this.trailing,
    required this.disabled,
    required this.onTap,
    super.key,
  });

  final IconData leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = disabled ? 0.58 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: const Color(0xFFF7F8FA),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFEFF1F4)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                Icon(leading, color: const Color(0xFFFF5D72), size: 24),
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
                          color: Color(0xFF1F2937),
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
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
                            color: Color(0xFF6B7280),
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
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFFFF5D72),
          size: 19,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFF5D72),
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
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
            color: Color(0xFF1F2937),
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w900,
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
          color: Color(0xFFFF5D72),
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xFF6B7280),
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
        color: Color(0xFFFF5D72),
        backgroundColor: Color(0xFFFFE6EA),
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
          color: Color(0xFFFF5D72),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$title. $message',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
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
        color: Color(0xFFFF5D72),
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
                color: Color(0xFFFF5D72),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFF1F4)),
      ),
      child: child,
    );
  }
}

const _sectionTitleStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontSize: 17,
  height: 1.2,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _bodyStyle = TextStyle(
  color: Color(0xFF6B7280),
  fontSize: 14,
  height: 1.35,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

bool _canEditSoundtrack(StoryRole role) {
  return role == StoryRole.owner || role == StoryRole.coOwner;
}
