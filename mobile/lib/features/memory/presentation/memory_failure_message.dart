import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String memoryFailureMessage(
  AppLocalizations l10n,
  MemoryFailure failure,
) {
  return switch (failure) {
    MemoryValidationFailure() => l10n.memoryFailureValidation,
    MemoryUnauthorized() => l10n.memoryFailureUnauthorized,
    MemoryStoryUnavailable() => l10n.memoryFailureStoryUnavailable,
    MemoryNotFound() => l10n.memoryFailureNotFound,
    MemoryCreationUnavailable() => l10n.memoryFailureCreationUnavailable,
    MemoryUpdateUnavailable() => l10n.memoryFailureUpdateUnavailable,
    MemoryDeletionUnavailable() => l10n.memoryFailureDeletionUnavailable,
    MemoryNetworkUnavailable() => l10n.memoryFailureNetworkUnavailable,
    MemoryRequestTimedOut() => l10n.memoryFailureRequestTimedOut,
    MemoryServerFailure() => l10n.memoryFailureServerFailure,
    UnknownMemoryFailure() => l10n.memoryFailureUnknown,
  };
}
