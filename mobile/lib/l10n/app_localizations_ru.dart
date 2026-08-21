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
  String storyMemoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count воспоминания',
      many: '$count воспоминаний',
      few: '$count воспоминания',
      one: '$count воспоминание',
      zero: 'Нет воспоминаний',
    );
    return '$_temp0';
  }

  @override
  String storyParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get storyThumbnailLabel => 'Фото истории';

  @override
  String get storyThumbnailUnavailableLabel => 'Фото истории недоступно';

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
  String get storyDetailsPeriodPresent => 'наст. время';

  @override
  String get storyDetailsSectionsTitle => 'Разделы';

  @override
  String get storyDetailsMemoriesAction => 'Воспоминания';

  @override
  String get storyDetailsParticipantsAction => 'Участники';

  @override
  String get storyDetailsParticipantsManageAction => 'Управление';

  @override
  String get storyDetailsMapAction => 'Карта';

  @override
  String get storyDetailsTimelineAction => 'Хронология';

  @override
  String get storyDetailsRecentMemoriesTitle => 'Последние воспоминания';

  @override
  String get storyDetailsSeeAllAction => 'Смотреть все';

  @override
  String get storyDetailsPlaybackStoryAction => 'Воспроизвести историю';

  @override
  String get participantsPageTitle => 'Участники';

  @override
  String get participantsBack => 'Вернуться к истории';

  @override
  String get participantsHeaderTitle => 'Люди в этой истории';

  @override
  String participantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '1 участник',
      zero: 'Нет участников',
    );
    return '$_temp0';
  }

  @override
  String get participantsSectionTitle => 'Участники';

  @override
  String get participantsSectionSubtitle =>
      'Роли определяют, что участники могут делать в этой истории.';

  @override
  String get participantsInvite => 'Пригласить участника';

  @override
  String get participantsLeaveStory => 'Покинуть историю';

  @override
  String get participantsLeaveConfirmTitle => 'Покинуть историю?';

  @override
  String get participantsLeaveConfirmBody =>
      'Вы потеряете доступ к этой истории. Чтобы вернуться, потребуется новое приглашение. Если вы последний владелец, сервер может отклонить действие.';

  @override
  String get participantsLeaveConfirmAction => 'Покинуть';

  @override
  String get participantsLeaveCancel => 'Отмена';

  @override
  String get participantsLeaving => 'Покидаем историю...';

  @override
  String get participantsCurrentUser => 'Вы';

  @override
  String get participantsEmptyTitle => 'Некого показать';

  @override
  String get participantsEmptyBody =>
      'Список участников сейчас пуст. Попробуйте обновить его чуть позже.';

  @override
  String get participantsRetry => 'Повторить';

  @override
  String get participantsRefreshFailed => 'Не удалось обновить участников';

  @override
  String get participantsLoadFailed => 'Не удалось загрузить участников';

  @override
  String get participantsRemoveAction => 'Удалить';

  @override
  String participantsRemoveConfirmTitle(String displayName) {
    return 'Удалить участника $displayName?';
  }

  @override
  String participantsRemoveConfirmBody(String displayName) {
    return '$displayName потеряет доступ к этой истории. Он сможет вернуться по новому приглашению.';
  }

  @override
  String get participantsRemoveConfirmAction => 'Удалить';

  @override
  String get participantsRemoveCancel => 'Отмена';

  @override
  String get participantsRemoving => 'Удаляем участника...';

  @override
  String participantsRemoveSuccess(String displayName) {
    return 'Участник $displayName удалён.';
  }

  @override
  String participantsAvatarLabel(String displayName) {
    return 'Аватар пользователя $displayName';
  }

  @override
  String participantsRemoveParticipantLabel(String displayName) {
    return 'Удалить участника $displayName';
  }

  @override
  String get participantFailureValidation =>
      'Запрос содержит ошибку. Попробуйте ещё раз.';

  @override
  String get participantFailureUnauthorized =>
      'Сеанс требует внимания. Попробуйте ещё раз.';

  @override
  String get participantFailureNotFound => 'Участники недоступны.';

  @override
  String get participantFailureLastOwner =>
      'Последний владелец не может покинуть эту историю.';

  @override
  String get participantFailureCannotRemoveSelf =>
      'Чтобы удалить себя, используйте действие «Покинуть историю».';

  @override
  String get participantFailureOwnerCannotBeRemoved =>
      'Владельца нельзя удалить отсюда.';

  @override
  String get participantFailureNetwork =>
      'Нет подключения к интернету. Проверьте соединение и повторите попытку.';

  @override
  String get participantFailureTimeout =>
      'Время ожидания истекло. Попробуйте ещё раз.';

  @override
  String get participantFailureServer =>
      'Сервер временно недоступен. Попробуйте ещё раз.';

  @override
  String get participantFailureUnknown =>
      'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get storyMemoriesPageTitle => 'Воспоминания';

  @override
  String get storyMemoriesBackLabel => 'Вернуться к истории';

  @override
  String get storyMemoriesRefreshAction => 'Обновить воспоминания';

  @override
  String get storyMemoriesHeaderTitle => 'Воспоминания истории';

  @override
  String storyMemoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count воспоминания',
      many: '$count воспоминаний',
      few: '$count воспоминания',
      one: '1 воспоминание',
      zero: 'Нет воспоминаний',
    );
    return '$_temp0';
  }

  @override
  String get storyMemoriesCreate => 'Добавить воспоминание';

  @override
  String get storyMemoriesEmptyTitle => 'Пока нет воспоминаний';

  @override
  String get storyMemoriesEmptyBody =>
      'Добавьте первое воспоминание, когда появится момент, который хочется сохранить.';

  @override
  String get storyMemoriesLoadFailureTitle =>
      'Не удалось загрузить воспоминания';

  @override
  String get storyMemoriesRefreshFailureTitle =>
      'Не удалось обновить воспоминания';

  @override
  String get storyTimelinePageTitle => 'Хронология';

  @override
  String get storyTimelineBackLabel => 'Вернуться к истории';

  @override
  String get storyTimelineRefreshAction => 'Обновить хронологию';

  @override
  String get storyTimelineTabTimeline => 'Хронология';

  @override
  String get storyTimelineTabMap => 'Карта';

  @override
  String get storyTimelineTabStats => 'Статистика';

  @override
  String get storyTimelineCreate => 'Добавить воспоминание';

  @override
  String get storyTimelineEmptyTitle => 'Хронология пока пуста';

  @override
  String get storyTimelineEmptyBody =>
      'Добавьте воспоминания, чтобы собрать хронологию этой истории.';

  @override
  String get storyTimelineLoadFailureTitle => 'Не удалось загрузить хронологию';

  @override
  String get storyTimelineRefreshFailureTitle =>
      'Не удалось обновить хронологию';

  @override
  String get storyMapPageTitle => 'Карта';

  @override
  String get storyMapBackLabel => 'Вернуться к истории';

  @override
  String get storyMapShowAllAction => 'Показать всё';

  @override
  String get storyMapRefreshAction => 'Обновить карту';

  @override
  String get storyMapShowDetailsAction => 'Подробнее';

  @override
  String get storyMapEmptyTitle => 'На карте пока нет воспоминаний';

  @override
  String get storyMapEmptyBody =>
      'Воспоминания с сохранёнными местами появятся здесь.';

  @override
  String get storyMapLoadFailureTitle => 'Не удалось загрузить карту';

  @override
  String get storyMapRefreshFailureTitle => 'Не удалось обновить карту';

  @override
  String memoryOpenLabel(String title) {
    return 'Открыть воспоминание $title';
  }

  @override
  String get memoryFailureValidation =>
      'Запрос содержит ошибку. Попробуйте ещё раз.';

  @override
  String get memoryFailureUnauthorized =>
      'Сеанс требует внимания. Попробуйте ещё раз.';

  @override
  String get memoryFailureStoryUnavailable =>
      'Воспоминания истории недоступны.';

  @override
  String get memoryFailureNotFound => 'Воспоминание недоступно.';

  @override
  String get memoryFailureCreationUnavailable =>
      'Воспоминание нельзя создать отсюда.';

  @override
  String get memoryFailureUpdateUnavailable =>
      'Воспоминание нельзя обновить отсюда.';

  @override
  String get memoryFailureDeletionUnavailable =>
      'Воспоминание нельзя удалить отсюда.';

  @override
  String get memoryFailureNetworkUnavailable =>
      'Нет подключения к интернету. Проверьте соединение и повторите попытку.';

  @override
  String get memoryFailureRequestTimedOut =>
      'Время ожидания истекло. Попробуйте ещё раз.';

  @override
  String get memoryFailureServerFailure =>
      'Сервер временно недоступен. Попробуйте ещё раз.';

  @override
  String get memoryFailureUnknown => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get createMemoryPageTitle => 'Добавить воспоминание';

  @override
  String get createMemoryBackLabel => 'Назад к воспоминаниям';

  @override
  String get createMemoryTitleLabel => 'Название';

  @override
  String get createMemoryTitleHint => 'Например: Закат на Бали';

  @override
  String get createMemoryTitleRequired => 'Введите название воспоминания.';

  @override
  String get createMemoryTitleBlank =>
      'Название воспоминания не может быть пустым.';

  @override
  String get createMemoryTitleMax =>
      'Название воспоминания должно быть не длиннее 255 символов.';

  @override
  String get createMemoryDescriptionLabel => 'Описание';

  @override
  String get createMemoryDescriptionHint => 'Добавьте заметку об этом моменте';

  @override
  String get createMemoryPlaceNameLabel => 'Подпись места';

  @override
  String get createMemoryPlaceNameHint => 'Например: Пляж Семиньяк';

  @override
  String get createMemoryPlaceNameMax =>
      'Подпись места должна быть не длиннее 255 символов.';

  @override
  String get createMemoryOptionalLabel => 'необязательно';

  @override
  String get createMemoryEventDateLabel => 'Дата события';

  @override
  String get createMemoryEventDateEmpty => 'Дата не выбрана';

  @override
  String get createMemoryChooseDate => 'Выбрать';

  @override
  String get createMemoryChangeDate => 'Изменить';

  @override
  String get createMemoryDateRequired => 'Выберите дату события.';

  @override
  String get createMemoryLocationLabel => 'Место';

  @override
  String get createMemoryLocationEmpty => 'Место не выбрано';

  @override
  String get createMemoryLocationSelected => 'Место выбрано';

  @override
  String get createMemoryChooseLocation => 'Выбрать';

  @override
  String get createMemoryChangeLocation => 'Изменить';

  @override
  String get createMemoryLocationRequired => 'Выберите место.';

  @override
  String get createMemorySubmitButton => 'Создать воспоминание';

  @override
  String get createMemorySubmittingButton => 'Создаём воспоминание...';

  @override
  String get editMemoryPageTitle => 'Редактирование воспоминания';

  @override
  String get editMemoryBackLabel => 'Вернуться к воспоминанию';

  @override
  String get editMemorySaveButton => 'Сохранить изменения';

  @override
  String get editMemorySavingButton => 'Сохраняем изменения...';

  @override
  String get editMemoryNoChangesHint => 'Измените поле, чтобы сохранить.';

  @override
  String get memoryDetailsPageTitle => 'Воспоминание';

  @override
  String get memoryDetailsBackLabel => 'Вернуться к воспоминаниям';

  @override
  String get memoryDetailsRefreshAction => 'Обновить воспоминание';

  @override
  String get memoryDetailsEditAction => 'Редактировать воспоминание';

  @override
  String get memoryDetailsDeleteAction => 'Удалить воспоминание';

  @override
  String get memoryDetailsLoadFailureTitle =>
      'Не удалось загрузить воспоминание';

  @override
  String get memoryDetailsRefreshFailureTitle =>
      'Не удалось обновить воспоминание';

  @override
  String get memoryDetailsDescriptionTitle => 'Заметка';

  @override
  String get memoryDetailsNoDescription => 'Описания пока нет.';

  @override
  String get memoryDetailsPlaceTitle => 'Место';

  @override
  String get memoryDetailsNoPlace => 'Подписи места пока нет.';

  @override
  String get memoryDetailsOpenOnMapAction => 'Открыть на карте';

  @override
  String get memoryDetailsMapUnavailable => 'Предпросмотр карты недоступен.';

  @override
  String get memoryMediaTitle => 'Фото';

  @override
  String get memoryMediaRefreshAction => 'Обновить фото';

  @override
  String get memoryMediaAddPhotoAction => 'Добавить фото';

  @override
  String get memoryMediaEmpty => 'Фото пока нет.';

  @override
  String get memoryMediaSelectingPhoto => 'Выбираем фото...';

  @override
  String get memoryMediaPreparingPhoto => 'Подготавливаем фото...';

  @override
  String get memoryMediaUploadingPhoto => 'Загружаем фото...';

  @override
  String get memoryMediaOpenPhotoLabel => 'Открыть фото';

  @override
  String get memoryMediaClosePhotoAction => 'Закрыть фото';

  @override
  String get deletePhotoAction => 'Удалить фото';

  @override
  String get deletePhotoDialogTitle => 'Удалить фото?';

  @override
  String get deletePhotoDialogBody =>
      'Это фото будет удалено без возможности восстановления.';

  @override
  String get deletePhotoCancel => 'Отмена';

  @override
  String get deletePhotoConfirm => 'Удалить';

  @override
  String get deletePhotoFailure =>
      'Не удалось удалить фото. Попробуйте ещё раз.';

  @override
  String get mediaFailureValidation =>
      'Запрос фото содержит ошибку. Попробуйте ещё раз.';

  @override
  String get mediaFailureUnauthorized =>
      'Сеанс требует внимания. Попробуйте ещё раз.';

  @override
  String get mediaFailureUnavailable => 'Фото недоступны.';

  @override
  String get mediaFailureUploadUnavailable => 'Фото нельзя загрузить отсюда.';

  @override
  String get mediaFailureNetworkUnavailable =>
      'Нет подключения к интернету. Проверьте соединение и повторите попытку.';

  @override
  String get mediaFailureRequestTimedOut =>
      'Время ожидания истекло. Попробуйте ещё раз.';

  @override
  String get mediaFailureServerFailure =>
      'Сервер временно недоступен. Попробуйте ещё раз.';

  @override
  String get mediaFailurePreprocessing =>
      'Не удалось подготовить это фото. Выберите другое изображение.';

  @override
  String get mediaFailureUnknown => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get deleteMemoryDialogTitle => 'Удалить воспоминание?';

  @override
  String get deleteMemoryDialogBody =>
      'Воспоминание будет удалено без возможности восстановления.';

  @override
  String get deleteMemoryCancel => 'Отмена';

  @override
  String get deleteMemoryConfirm => 'Удалить';

  @override
  String get deleteMemoryDeleting => 'Удаляем воспоминание...';

  @override
  String get locationPickerTitle => 'Выберите место';

  @override
  String get locationPickerBackLabel => 'Назад';

  @override
  String get locationPickerInstruction =>
      'Нажмите на карту, чтобы выбрать точную точку для этого воспоминания.';

  @override
  String get locationPickerSelectedTitle => 'Место выбрано';

  @override
  String get locationPickerSelectedDescription =>
      'Подтвердите выбор, когда маркер стоит в нужном месте.';

  @override
  String get locationPickerNoSelectionTitle => 'Место не выбрано';

  @override
  String get locationPickerNoSelectionDescription =>
      'Выберите точку на карте перед подтверждением.';

  @override
  String get locationPickerConfirmAction => 'Подтвердить место';

  @override
  String get locationPickerMapLoading => 'Загружаем карту...';

  @override
  String get locationPickerMapUnavailable =>
      'Карта недоступна. Попробуйте позже.';

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

  @override
  String get playbackTitle => 'Воспроизведение';

  @override
  String get playbackPreviousAction => 'Назад';

  @override
  String get playbackNextAction => 'Далее';

  @override
  String get playbackPauseAction => 'Пауза';

  @override
  String get playbackResumeAction => 'Продолжить';

  @override
  String get playbackReplayAction => 'Повторить';

  @override
  String get playbackCloseAction => 'Закрыть';

  @override
  String get playbackRetryAction => 'Повторить';

  @override
  String get playbackEmptyTitle => 'Пока нечего воспроизводить';

  @override
  String get playbackEmptyBody =>
      'Добавьте воспоминания в эту историю, а затем вернитесь к путешествию.';

  @override
  String get playbackLoadFailureTitle => 'Воспроизведение недоступно';

  @override
  String get playbackLoadFailureBody =>
      'Не удалось загрузить воспоминания этой истории.';

  @override
  String get playbackCameraFailureTitle => 'Движение карты остановлено';

  @override
  String get playbackCameraFailureBody =>
      'Карта не смогла перейти к следующему воспоминанию. Можно повторить или закрыть воспроизведение.';

  @override
  String get playbackFinishedTitle => 'Воспроизведение завершено';

  @override
  String get playbackFinishedBody =>
      'Повторите путешествие по истории или закройте воспроизведение.';

  @override
  String get playbackNoPhotoTitle => 'Без фото';

  @override
  String get playbackPhotoUnavailable => 'Фото недоступно';

  @override
  String get playbackMemoryPhotoLabel => 'Фото воспоминания';
}
