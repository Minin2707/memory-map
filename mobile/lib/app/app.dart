import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_notifier.dart';
import 'package:memory_map/app/router.dart';
import 'package:memory_map/app/theme.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class MemoryMapApp extends ConsumerWidget {
  const MemoryMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final languageState = ref.watch(appLanguagePreferenceProvider).asData?.value;
    final locale = languageState?.preference.toFlutterLocale();

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: resolveMemoryStoryLocale,
      routerConfig: router,
    );
  }
}
