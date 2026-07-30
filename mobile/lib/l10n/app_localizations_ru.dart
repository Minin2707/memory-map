// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Memory Map';

  @override
  String get loginHeadline => 'У каждого места есть история';

  @override
  String get loginDescription =>
      'Создавайте личную карту воспоминаний и делитесь ею с теми, кто вам дорог.';

  @override
  String get continueWithGoogle => 'Продолжить с Google';

  @override
  String get signingIn => 'Выполняется вход…';

  @override
  String get loginLegalPrefix => 'Продолжая, вы соглашаетесь с';

  @override
  String get privacyPolicy => 'Политикой конфиденциальности';

  @override
  String get termsOfUse => 'Условиями использования';

  @override
  String get legalSeparator => 'и';

  @override
  String get authCancelled => 'Вход был отменён.';

  @override
  String get googleAuthenticationUnavailable =>
      'Вход через Google недоступен на этом устройстве.';

  @override
  String get googleAuthenticationFailed =>
      'Не удалось войти через Google. Попробуйте ещё раз.';

  @override
  String get backendUnauthorized => 'Сервер отклонил вход. Попробуйте ещё раз.';

  @override
  String get requestValidationFailed =>
      'Запрос содержит ошибку. Попробуйте ещё раз.';

  @override
  String get networkUnavailable =>
      'Нет подключения к интернету. Проверьте соединение и повторите попытку.';

  @override
  String get requestTimedOut => 'Время ожидания истекло. Попробуйте ещё раз.';

  @override
  String get serverFailure => 'Сервер временно недоступен. Попробуйте ещё раз.';

  @override
  String get secureStorageFailure =>
      'Не удалось безопасно сохранить сеанс. Попробуйте ещё раз.';

  @override
  String get corruptSession =>
      'Локальные данные сеанса повреждены. Попробуйте ещё раз.';

  @override
  String get unknownAuthFailure => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get checkingSession => 'Проверяем ваш сеанс…';

  @override
  String get restoreSessionTitle => 'Не удалось восстановить сеанс';

  @override
  String get retry => 'Повторить';

  @override
  String get unexpectedErrorTitle => 'Что-то пошло не так';

  @override
  String get unexpectedErrorDescription =>
      'Перезапустите приложение или попробуйте ещё раз.';

  @override
  String get tryAgain => 'Попробовать снова';

  @override
  String welcomeUser(String displayName) {
    return 'Добро пожаловать, $displayName';
  }

  @override
  String get fallbackDisplayName => 'друг';

  @override
  String get authenticatedSessionReady => 'Сеанс авторизации готов';

  @override
  String get logOut => 'Выйти';

  @override
  String get loggingOut => 'Выполняется выход…';

  @override
  String get tryLogoutAgain => 'Попробовать выйти снова';
}
