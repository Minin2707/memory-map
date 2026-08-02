import 'package:flutter/material.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class StoriesEmptyState extends StatelessWidget {
  const StoriesEmptyState({
    this.onCreateStory,
    super.key,
  });

  final VoidCallback? onCreateStory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            offset: Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _EmptyIllustration(),
          const SizedBox(height: 22),
          Text(
            l10n.storiesEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.storiesEmptyDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('stories.empty.create-action'),
            onPressed: onCreateStory,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.storiesCreateAction),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5D72),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 54),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 164,
        height: 122,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 10,
              left: 12,
              child: Container(
                width: 64,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E5EA),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 12,
              child: Container(
                width: 92,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EEF2),
                  borderRadius: BorderRadius.circular(34),
                ),
              ),
            ),
            Container(
              width: 74,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B7D),
                borderRadius: BorderRadius.circular(38),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33FF6B7D),
                    offset: Offset(0, 10),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
