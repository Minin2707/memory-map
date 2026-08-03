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

  @override
  String get invitePageTitle => 'Пригласить участника';

  @override
  String get inviteCreatedPageTitle => 'Приглашение создано';

  @override
  String get inviteBackLabel => 'Вернуться к истории';

  @override
  String get inviteHeroTitle => 'Пригласите близкого человека';

  @override
  String get inviteHeroSubtitle =>
      'Поделитесь одноразовой ссылкой, чтобы он мог присоединиться к вашей истории.';

  @override
  String get inviteLinkLabel => 'Ссылка-приглашение';

  @override
  String get inviteSingleUseDescription =>
      'Ссылка одноразовая. После принятия приглашения она перестанет работать.';

  @override
  String get inviteExpirationLabel => 'Срок действия';

  @override
  String get inviteExpirationDescription =>
      'Приглашение действительно до даты, которую вернул сервер.';

  @override
  String get inviteWhatCanDoTitle => 'Что можно сделать с этой ссылкой?';

  @override
  String get inviteInstructionShare => 'Поделиться в любом мессенджере.';

  @override
  String get inviteInstructionCopy => 'Скопировать и отправить самостоятельно.';

  @override
  String get inviteInstructionOneUse =>
      'Попросить получателя использовать её только один раз.';

  @override
  String get inviteCreateButton => 'Создать приглашение';

  @override
  String get inviteCreatingButton => 'Создаём приглашение...';

  @override
  String get inviteSuccessTitle => 'Приглашение готово!';

  @override
  String get inviteSuccessSubtitle =>
      'Поделитесь ссылкой с близким человеком. Она одноразовая и безопасная.';

  @override
  String get inviteLinkSemanticsLabel => 'Ссылка-приглашение';

  @override
  String get inviteCopyAction => 'Копировать';

  @override
  String get inviteCopiedFeedback => 'Ссылка-приглашение скопирована.';

  @override
  String get inviteCopyFailure => 'Не удалось скопировать ссылку-приглашение.';

  @override
  String get inviteShareAction => 'Поделиться';

  @override
  String get inviteShareReadyFeedback => 'Открыты варианты отправки.';

  @override
  String get inviteShareFailure =>
      'Не удалось поделиться ссылкой-приглашением.';

  @override
  String get inviteLinkCannotBeRestoredWarning =>
      'Скопируйте или отправьте эту ссылку до выхода с экрана. Повторно показать её нельзя.';

  @override
  String get inviteImportantTitle => 'Важно';

  @override
  String get inviteImportantSingleUse =>
      'Эту ссылку можно использовать только один раз.';

  @override
  String get inviteImportantAfterAccept =>
      'После принятия приглашения ссылка станет недействительной.';

  @override
  String get inviteImportantExpiration =>
      'Приглашение автоматически истечёт после окончания срока действия.';

  @override
  String get inviteDoneAction => 'Готово';

  @override
  String get inviteFailureValidation =>
      'Запрос приглашения содержит ошибку. Попробуйте ещё раз.';

  @override
  String get inviteFailureUnauthorized =>
      'Сеанс требует внимания. Попробуйте ещё раз.';

  @override
  String get inviteFailureNotFound => 'Эта история недоступна для приглашений.';

  @override
  String get inviteFailureNetworkUnavailable =>
      'Нет подключения к интернету. Проверьте соединение и повторите попытку.';

  @override
  String get inviteFailureRequestTimedOut =>
      'Время ожидания истекло. Попробуйте ещё раз.';

  @override
  String get inviteFailureServerFailure =>
      'Сервер временно недоступен. Попробуйте ещё раз.';

  @override
  String get inviteFailureUnknown => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get acceptInvitePageTitle => 'Приглашение';

  @override
  String get acceptInviteBackLabel => 'Вернуться к историям';

  @override
  String get acceptInviteHeroTitle => 'Вас пригласили в историю';

  @override
  String get acceptInviteHeroDescription =>
      'Примите приглашение, чтобы присоединиться. История откроется после подтверждения доступа сервером.';

  @override
  String get acceptInviteDetailsAccessTitle => 'Приватный доступ';

  @override
  String get acceptInviteDetailsAccessBody =>
      'Детали истории скрыты, пока вы не примете приглашение.';

  @override
  String get acceptInviteDetailsSingleUseTitle => 'Одноразовая ссылка';

  @override
  String get acceptInviteDetailsSingleUseBody =>
      'Приглашение можно принять только один раз, и срок его действия может истечь.';

  @override
  String get acceptInviteAcceptAction => 'Принять приглашение';

  @override
  String get acceptInviteAcceptingAction => 'Принимаем приглашение...';

  @override
  String get acceptInviteRetryAction => 'Попробовать снова';

  @override
  String get acceptInviteCancelAction => 'Отмена';

  @override
  String get acceptInviteBackToStoriesAction => 'Вернуться к историям';

  @override
  String get acceptInviteInvalidLinkTitle => 'Приглашение недоступно';

  @override
  String get acceptInviteInvalidLinkDescription =>
      'Это приглашение нельзя открыть.';

  @override
  String get acceptInviteUnavailable => 'Это приглашение нельзя принять.';

  @override
  String get acceptInviteFailureUnauthorized =>
      'Сеанс требует внимания. Войдите снова.';

  @override
  String get acceptInviteFailureUnknown =>
      'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get acceptInviteAcceptSemanticsLabel => 'Принять приглашение';

  @override
  String get acceptInviteCancelSemanticsLabel => 'Отменить приглашение';

  @override
  String get acceptInviteErrorSemanticsLabel => 'Ошибка приглашения';
}
