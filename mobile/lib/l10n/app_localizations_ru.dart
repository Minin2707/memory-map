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

  @override
  String storiesGreeting(String displayName) {
    return 'Привет, $displayName! 👋';
  }

  @override
  String get storiesSubtitle => 'Здесь живут ваши совместные воспоминания';

  @override
  String get storiesSectionTitle => 'Ваши истории';

  @override
  String get storiesCreateAction => 'Создать историю';

  @override
  String get storiesEmptyTitle => 'У вас пока нет историй';

  @override
  String get storiesEmptyDescription =>
      'Создайте свою первую историю и сохраните важные моменты вместе';

  @override
  String get storiesLoadFailureTitle => 'Не удалось загрузить истории';

  @override
  String get storiesRefreshFailureTitle => 'Не удалось обновить истории';

  @override
  String get storyFailureValidation =>
      'Запрос содержит ошибку. Попробуйте ещё раз.';

  @override
  String get storyFailureUnauthorized =>
      'Сеанс требует внимания. Попробуйте ещё раз.';

  @override
  String get storyFailureNotFound => 'История недоступна.';

  @override
  String get storyFailureNetworkUnavailable =>
      'Нет подключения к интернету. Проверьте соединение и повторите попытку.';

  @override
  String get storyFailureRequestTimedOut =>
      'Время ожидания истекло. Попробуйте ещё раз.';

  @override
  String get storyFailureServerFailure =>
      'Сервер временно недоступен. Попробуйте ещё раз.';

  @override
  String get storyFailureUnknown => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get storyRoleOwner => 'Владелец';

  @override
  String get storyRoleCoOwner => 'Совладелец';

  @override
  String get storyRoleEditor => 'Редактор';

  @override
  String get storyRoleViewer => 'Читатель';

  @override
  String get storiesNotificationUnavailableLabel =>
      'Уведомления пока недоступны';

  @override
  String storiesAvatarLabel(String displayName) {
    return 'Аватар пользователя $displayName';
  }

  @override
  String storiesOpenStoryLabel(String title) {
    return 'Открыть историю $title';
  }

  @override
  String get cancel => 'Отмена';

  @override
  String get createStoryPageTitle => 'Создание истории';

  @override
  String get createStoryBackLabel => 'Вернуться к историям';

  @override
  String get createStoryHeroTitle => 'Новая история';

  @override
  String get createStoryHeroSubtitle =>
      'Создайте пространство для ваших совместных воспоминаний';

  @override
  String get createStoryTitleLabel => 'Название истории';

  @override
  String get createStoryTitleHint => 'Например: Наша история';

  @override
  String get createStoryTitleHelp =>
      'Название будет видно всем участникам истории';

  @override
  String get createStoryTitleRequired => 'Введите название истории.';

  @override
  String get createStoryTitleBlank => 'Название истории не может быть пустым.';

  @override
  String get createStoryDescriptionLabel => 'Описание';

  @override
  String get createStoryDescriptionOptional => 'необязательно';

  @override
  String get createStoryDescriptionHint =>
      'Добавьте короткую заметку об этой истории';

  @override
  String get createStoryWhyTitle => 'Зачем нужно название?';

  @override
  String get createStoryWhyDescription =>
      'Хорошее название помогает вспомнить, о чём ваша история, и делает её особенной.';

  @override
  String get createStoryIdeasTitle => 'Идеи для названия';

  @override
  String get createStoryIdeaOne => 'Наша история';

  @override
  String get createStoryIdeaTwo => 'Лучшие моменты вместе';

  @override
  String get createStoryIdeaThree => 'Путешествия и приключения';

  @override
  String get createStorySubmitButton => 'Создать историю';

  @override
  String get createStoryCreatingButton => 'Создаём историю...';

  @override
  String get storyDetailsPageTitle => 'История';

  @override
  String get storyDetailsBackLabel => 'Вернуться к историям';

  @override
  String get storyDetailsEditAction => 'Редактировать историю';

  @override
  String get storyDetailsLoadFailureTitle => 'Не удалось загрузить историю';

  @override
  String get storyDetailsDescriptionTitle => 'Об этой истории';

  @override
  String get storyDetailsNoDescription => 'Описания пока нет.';

  @override
  String get storyDetailsInfoTitle => 'Информация об истории';

  @override
  String get storyDetailsCreatedLabel => 'Создана';

  @override
  String get storyDetailsUpdatedLabel => 'Обновлена';

  @override
  String get storyDetailsRefreshFailureTitle => 'Не удалось обновить историю';

  @override
  String get storyDetailsSectionsTitle => 'Разделы';

  @override
  String get storyDetailsMemoriesAction => 'Воспоминания';

  @override
  String get storyDetailsParticipantsAction => 'Участники';

  @override
  String get storyDetailsMapAction => 'Карта';

  @override
  String get editStoryPageTitle => 'Редактирование истории';

  @override
  String get editStoryBackLabel => 'Вернуться к истории';

  @override
  String get editStoryHeroTitle => 'Детали истории';

  @override
  String get editStoryHeroSubtitle =>
      'Обновите название и заметку, которые видят участники истории';

  @override
  String get editStoryTitleLabel => 'Название истории';

  @override
  String get editStoryTitleHint => 'Например: Наша история';

  @override
  String get editStoryTitleHelp =>
      'Название остаётся видимым всем участникам истории';

  @override
  String get editStoryTitleRequired => 'Введите название истории.';

  @override
  String get editStoryTitleBlank => 'Название истории не может быть пустым.';

  @override
  String get editStoryDescriptionLabel => 'Описание';

  @override
  String get editStoryDescriptionOptional => 'необязательно';

  @override
  String get editStoryDescriptionHint =>
      'Добавьте короткую заметку об этой истории';

  @override
  String get editStoryDescriptionHelp =>
      'Очистите поле, чтобы удалить текущее описание';

  @override
  String get editStorySaveButton => 'Сохранить изменения';

  @override
  String get editStorySavingButton => 'Сохраняем изменения...';

  @override
  String get editStoryNoChangesHint => 'Измените поле, чтобы сохранить.';

  @override
  String get editStoryUnavailableTitle => 'Редактирование недоступно';

  @override
  String get editStoryUnavailableDescription =>
      'Эту историю нельзя редактировать отсюда.';

  @override
  String get editStoryUnavailableBackAction => 'Вернуться к истории';
}
