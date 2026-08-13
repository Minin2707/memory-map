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
    final selected = onTap;

    return Semantics(
      container: true,
      button: selected != null,
      label: selected == null
          ? memory.title
          : l10n.memoryOpenLabel(memory.title),
      child: Material(
        key: const ValueKey('story-map.memory-preview'),
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 12,
        shadowColor: const Color(0x260F172A),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: selected == null
              ? null
              : () {
                  selected(memory);
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewVisual(memory: memory, previewPhoto: previewPhoto),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        memory.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PreviewMetaRow(
                        icon: Icons.calendar_today_rounded,
                        text: formatMemoryDate(l10n, memory.eventDate),
                      ),
                      if (visiblePlaceName != null) ...[
                        const SizedBox(height: 6),
                        _PreviewMetaRow(
                          icon: Icons.place_rounded,
                          text: visiblePlaceName,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onClose != null)
                      IconButton(
                        key: const ValueKey('story-map.memory-preview.close'),
                        onPressed: onClose,
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF2F4F7),
                          foregroundColor: const Color(0xFF6B7280),
                        ),
                      ),
                    if (selected != null) ...[
                      if (onClose != null) const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF8A93A3),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
      return _PreviewIcon(memory: memory);
    }

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 58,
          height: 64,
          child: AuthenticatedMediaPathImage(
            thumbnailPath: preview.thumbnailPath,
            fit: BoxFit.cover,
            placeholder: _PreviewIcon(memory: memory),
            errorBuilder: (_) => _PreviewIcon(memory: memory),
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
        width: 58,
        height: 64,
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
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              memory.eventDate.month.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Color(0xFFFF5D72),
                fontSize: 12,
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
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF8A93A3)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4B5563),
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

String? _visibleText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value;
}
