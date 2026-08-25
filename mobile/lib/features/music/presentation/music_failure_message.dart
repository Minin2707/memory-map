import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String musicFailureMessage(AppLocalizations l10n, MusicFailure failure) {
  return switch (failure) {
    MusicNetworkUnavailable() => l10n.musicFailureNetworkUnavailable,
    MusicRequestTimedOut() => l10n.musicFailureRequestTimedOut,
    MusicUnauthorized() => l10n.musicFailureUnavailable,
    MusicUnavailable() => l10n.musicFailureUnavailable,
    MusicServerFailure() => l10n.serverFailure,
    MusicValidationFailure() => l10n.musicFailureUnavailable,
    UnknownMusicFailure() => l10n.musicFailureUnknown,
  };
}
