import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_notifier.dart';
import 'package:memory_map/app/language/app_language_preference_state.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class ProfileLanguageScreen extends ConsumerWidget {
  const ProfileLanguageScreen({
    required this.onBack,
    super.key,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final languageValue = ref.watch(appLanguagePreferenceProvider);
    final languageState =
        languageValue.asData?.value ?? const AppLanguagePreferenceState();

    return Scaffold(
      key: const ValueKey('profile-language.screen'),
      backgroundColor: const Color(0xFFFFF8F6),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      key: const ValueKey('profile-language.back-action'),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: l10n.profileBackLabel,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l10n.profileLanguageTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    if (languageState.hasPersistenceFailure) ...[
                      _LanguageFailureBanner(
                        message: l10n.languageChangeFailure,
                      ),
                      const SizedBox(height: 12),
                    ],
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 22,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _LanguageOptionRow(
                            key: const ValueKey(
                              'profile-language.option.system',
                            ),
                            title: l10n.languageSystemOption,
                            subtitle: l10n.languageSystemSubtitle,
                            preference: AppLanguagePreference.system,
                            selectedPreference: languageState.preference,
                            isSaving: languageState.isSaving,
                          ),
                          const _LanguageDivider(),
                          _LanguageOptionRow(
                            key: const ValueKey('profile-language.option.ru'),
                            title: l10n.languageRussianOption,
                            preference: AppLanguagePreference.russian,
                            selectedPreference: languageState.preference,
                            isSaving: languageState.isSaving,
                          ),
                          const _LanguageDivider(),
                          _LanguageOptionRow(
                            key: const ValueKey('profile-language.option.en'),
                            title: l10n.languageEnglishOption,
                            preference: AppLanguagePreference.english,
                            selectedPreference: languageState.preference,
                            isSaving: languageState.isSaving,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionRow extends ConsumerWidget {
  const _LanguageOptionRow({
    required this.title,
    required this.preference,
    required this.selectedPreference,
    required this.isSaving,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final AppLanguagePreference preference;
  final AppLanguagePreference selectedPreference;
  final bool isSaving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = preference == selectedPreference;

    return InkWell(
      onTap: isSaving
          ? null
          : () async {
              await ref
                  .read(appLanguagePreferenceProvider.notifier)
                  .selectPreference(preference);
            },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
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
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isSaving && isSelected)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF5D72),
                ),
              )
            else if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                key: ValueKey(
                  'profile-language.selected.${preference.serializedValue}',
                ),
                color: const Color(0xFFFF5D72),
              )
            else
              const Icon(
                Icons.radio_button_unchecked_rounded,
                color: Color(0xFFD0D5DD),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageDivider extends StatelessWidget {
  const _LanguageDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 18,
      endIndent: 18,
      color: Color(0xFFF2F4F7),
    );
  }
}

class _LanguageFailureBanner extends StatelessWidget {
  const _LanguageFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFD92D20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFD92D20),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
