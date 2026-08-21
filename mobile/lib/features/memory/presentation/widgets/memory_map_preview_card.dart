import 'package:flutter/material.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class MemoryMapPreviewCard extends StatelessWidget {
  const MemoryMapPreviewCard({
    required this.memory,
    this.previewPhoto,
    this.onTap,
    this.onClose,
    super.key,
  });

  final Memory memory;
  final MemoryPhotoPreview? previewPhoto;
  final ValueChanged<Memory>? onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visiblePlaceName = _visibleText(memory.placeName);
    final visibleDescription = _visibleText(memory.description);

    return Semantics(
      container: true,
      label: memory.title,
      child: Material(
        key: const ValueKey('story-map.memory-preview'),
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 10,
        shadowColor: const Color(0x220F172A),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewVisual(memory: memory, previewPhoto: previewPhoto),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PreviewText(
                      title: memory.title,
                      date: formatMemoryDate(l10n, memory.eventDate),
                      placeName: visiblePlaceName,
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      key: const ValueKey('story-map.memory-preview.close'),
                      onPressed: onClose,
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF2F4F7),
                        foregroundColor: const Color(0xFF6B7280),
                        fixedSize: const Size.square(34),
                        minimumSize: const Size.square(34),
                        shape: const CircleBorder(),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
              if (visibleDescription != null) ...[
                const SizedBox(height: 10),
                Text(
                  visibleDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey(
                    'story-map.memory-preview.details-action',
                  ),
                  onPressed: () {
                    onTap!(memory);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5D72),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  child: Text(l10n.storyMapShowDetailsAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  const _PreviewText({
    required this.title,
    required this.date,
    required this.placeName,
  });

  final String title;
  final String date;
  final String? placeName;

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
            color: Color(0xFF1F2937),
            fontSize: 17,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        _PreviewMetaRow(
          icon: Icons.calendar_today_rounded,
          text: date,
          maxLines: 1,
        ),
        if (placeName != null) ...[
          const SizedBox(height: 5),
          _PreviewMetaRow(
            icon: Icons.place_rounded,
            text: placeName!,
            maxLines: 1,
          ),
        ],
      ],
    );
  }
}

class _PreviewVisual extends StatelessWidget {
  const _PreviewVisual({
    required this.memory,
    required this.previewPhoto,
  });

  final Memory memory;
  final MemoryPhotoPreview? previewPhoto;

  @override
  Widget build(BuildContext context) {
    final preview = previewPhoto;
    if (preview == null) {
      return Semantics(
        image: true,
        label: memory.title,
        child: _PreviewIcon(memory: memory),
      );
    }

    return Semantics(
      image: true,
      label: memory.title,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 70,
            height: 74,
            child: AuthenticatedMediaPathImage(
              key: ValueKey('story-map.memory-preview.photo.${preview.mediaId}'),
              thumbnailPath: preview.thumbnailPath,
              fit: BoxFit.cover,
              placeholder: _PreviewIcon(memory: memory),
              errorBuilder: (_) => _PreviewIcon(memory: memory),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewIcon extends StatelessWidget {
  const _PreviewIcon({
    required this.memory,
  });

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('story-map.memory-preview.no-photo'),
        width: 70,
        height: 74,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE6EA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              memory.eventDate.day.toString(),
              style: const TextStyle(
                color: Color(0xFFFF5D72),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              memory.eventDate.month.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Color(0xFFFF5D72),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMetaRow extends StatelessWidget {
  const _PreviewMetaRow({
    required this.icon,
    required this.text,
    required this.maxLines,
  });

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8A93A3)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

String? _visibleText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value;
}
