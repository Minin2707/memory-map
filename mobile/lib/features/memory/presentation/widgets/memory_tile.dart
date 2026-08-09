import 'package:flutter/material.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class MemoryTile extends StatelessWidget {
  const MemoryTile({
    required this.memory,
    this.onSelected,
    super.key,
  });

  final Memory memory;
  final ValueChanged<Memory>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final placeName = _visibleText(memory.placeName);
    final selected = onSelected;

    return Semantics(
      container: true,
      button: selected != null,
      label: selected == null
          ? memory.title
          : l10n.memoryOpenLabel(memory.title),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: selected == null
            ? null
            : () {
                selected(memory);
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateMarker(memory: memory),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    _MetaRow(
                      icon: Icons.calendar_today_rounded,
                      text: formatMemoryDate(l10n, memory.eventDate),
                    ),
                    if (placeName != null) ...[
                      const SizedBox(height: 6),
                      _MetaRow(
                        icon: Icons.place_rounded,
                        text: placeName,
                      ),
                    ],
                  ],
                ),
              ),
              if (selected != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8A93A3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateMarker extends StatelessWidget {
  const _DateMarker({
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
              _monthNumber(memory.eventDate.month),
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({
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

String _monthNumber(int month) {
  return month.toString().padLeft(2, '0');
}
