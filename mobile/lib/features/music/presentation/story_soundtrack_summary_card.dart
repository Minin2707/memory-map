import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/music/application/story_soundtrack_notifier.dart';
import 'package:memory_map/features/music/application/story_soundtrack_state.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/presentation/music_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class StorySoundtrackSummaryCard extends ConsumerWidget {
  const StorySoundtrackSummaryCard({
    required this.storyId,
    required this.editable,
    required this.onSelected,
    super.key,
  });

  final String storyId;
  final bool editable;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundtrackValue = ref.watch(storySoundtrackProvider(storyId));
    final enabled = editable && onSelected != null;

    return Material(
      key: const ValueKey('story-details.soundtrack-summary'),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFEFF1F4)),
      ),
      child: InkWell(
        onTap: enabled ? onSelected : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
          child: Row(
            children: [
              const _SoundtrackIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: _SoundtrackSummaryContent(
                  storyId: storyId,
                  soundtrackValue: soundtrackValue,
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8A93A3),
                  size: 26,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundtrackSummaryContent extends ConsumerWidget {
  const _SoundtrackSummaryContent({
    required this.storyId,
    required this.soundtrackValue,
  });

  final String storyId;
  final AsyncValue<StorySoundtrackState> soundtrackValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (soundtrackValue.isLoading) {
      return _SummaryText(
        title: l10n.soundtrackTitle,
        subtitle: l10n.soundtrackLoading,
      );
    }

    if (soundtrackValue.hasError) {
      return _SummaryFailure(
        message: l10n.soundtrackLoadFailureTitle,
        onRetry: () {
          ref.read(storySoundtrackProvider(storyId).notifier).retryLoad();
        },
      );
    }

    final state = soundtrackValue.asData?.value;
    final loadFailure = state?.loadFailure;
    if (loadFailure != null) {
      return _SummaryFailure(
        message:
            '${l10n.soundtrackLoadFailureTitle}. '
            '${musicFailureMessage(l10n, loadFailure)}',
        onRetry: () {
          ref.read(storySoundtrackProvider(storyId).notifier).retryLoad();
        },
      );
    }

    final soundtrack = state?.soundtrack;
    if (soundtrack == null || soundtrack.isNoMusic) {
      return _SummaryText(
        title: l10n.soundtrackTitle,
        subtitle: l10n.soundtrackNoMusic,
      );
    }

    return _SoundtrackSummary(soundtrack: soundtrack);
  }
}

class _SoundtrackSummary extends StatelessWidget {
  const _SoundtrackSummary({
    required this.soundtrack,
  });

  final StorySoundtrack soundtrack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = soundtrack.selectedSoundtrack;
    if (selected == null) {
      return _SummaryText(
        title: l10n.soundtrackTitle,
        subtitle: l10n.soundtrackNoMusic,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryTitle(text: l10n.soundtrackTitle),
        const SizedBox(height: 5),
        Text(
          selected.title,
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
        const SizedBox(height: 3),
        Text(
          soundtrack.isSelectedUnavailable
              ? '${selected.artist} · ${l10n.soundtrackCurrentlyUnavailable}'
              : selected.artist,
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
    );
  }
}

class _SummaryText extends StatelessWidget {
  const _SummaryText({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryTitle(text: title),
        const SizedBox(height: 6),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SummaryTitle extends StatelessWidget {
  const _SummaryTitle({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 17,
        height: 1.2,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _SummaryFailure extends StatelessWidget {
  const _SummaryFailure({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            message,
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
          key: const ValueKey('story-details.soundtrack-summary.retry-action'),
          onPressed: onRetry,
          child: Text(l10n.retry),
        ),
      ],
    );
  }
}

class _SoundtrackIcon extends StatelessWidget {
  const _SoundtrackIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6EA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Color(0xFFFF5D72),
        size: 26,
      ),
    );
  }
}
