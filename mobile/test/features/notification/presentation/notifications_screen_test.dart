import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/notification/application/notification_application_providers.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';
import 'package:memory_map/features/notification/domain/notification_repository.dart';
import 'package:memory_map/features/notification/presentation/notifications_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  testWidgets('shouldRenderAllNotificationTypesAndAvatarVariants', (
    WidgetTester tester,
  ) async {
    final mediaRepository = media_fixtures.FakeMediaRepository();
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[
        participantJoinedNotification(
          avatarUrl: '/api/v1/me/avatar',
        ),
        memoryCreatedNotification(
          id: 'notification-created',
          read: true,
          avatarUrl: 'https://example.com/avatar.png',
        ),
        photosAddedNotification(
          id: 'notification-photos',
          avatarUrl: null,
        ),
      ];

    await pumpScreen(
      tester,
      repository,
      mediaRepository: mediaRepository,
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Morgan joined a story'), findsOneWidget);
    expect(find.text('Ada added First picnic'), findsOneWidget);
    expect(find.text('Grace added photos to Beach morning'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('notifications.item.unread-indicator.notification-joined'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(
          'notifications.item.unread-indicator.notification-created',
        ),
      ),
      findsNothing,
    );
    expect(
      mediaRepository.receivedBinaryPaths,
      contains('/api/v1/me/avatar'),
    );

    final networkAvatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byKey(
          const ValueKey('notifications.item.avatar.notification-created'),
        ),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(networkAvatar.foregroundImage, isA<NetworkImage>());
    expect(
      (networkAvatar.foregroundImage as NetworkImage).url,
      'https://example.com/avatar.png',
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('notifications.item.avatar.notification-photos'),
        ),
        matching: find.text('G'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shouldMarkJoinedNotificationReadAndNavigateParticipants', (
    WidgetTester tester,
  ) async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[
        participantJoinedNotification(),
      ];
    String? selectedStoryId;

    await pumpScreen(
      tester,
      repository,
      onParticipantsSelected: (storyId) {
        selectedStoryId = storyId;
      },
    );

    await tester.tap(
      find.byKey(const ValueKey('notifications.item.notification-joined')),
    );
    await tester.pumpAndSettle();

    expect(repository.markReadIds, <String>['notification-joined']);
    expect(selectedStoryId, 'story-1');
  });

  testWidgets('shouldMarkMemoryCreatedReadAndNavigateMemoryDetails', (
    WidgetTester tester,
  ) async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[
        memoryCreatedNotification(),
      ];
    String? selectedStoryId;
    String? selectedMemoryId;

    await pumpScreen(
      tester,
      repository,
      onMemorySelected: (storyId, memoryId) {
        selectedStoryId = storyId;
        selectedMemoryId = memoryId;
      },
    );

    await tester.tap(
      find.byKey(const ValueKey('notifications.item.notification-created')),
    );
    await tester.pumpAndSettle();

    expect(repository.markReadIds, <String>['notification-created']);
    expect(selectedStoryId, 'story-1');
    expect(selectedMemoryId, 'memory-a');
  });

  testWidgets('shouldMarkPhotosAddedReadAndNavigateMemoryDetails', (
    WidgetTester tester,
  ) async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[
        photosAddedNotification(),
      ];
    String? selectedStoryId;
    String? selectedMemoryId;

    await pumpScreen(
      tester,
      repository,
      onMemorySelected: (storyId, memoryId) {
        selectedStoryId = storyId;
        selectedMemoryId = memoryId;
      },
    );

    await tester.tap(
      find.byKey(const ValueKey('notifications.item.notification-photos')),
    );
    await tester.pumpAndSettle();

    expect(repository.markReadIds, <String>['notification-photos']);
    expect(selectedStoryId, 'story-1');
    expect(selectedMemoryId, 'memory-b');
  });

  testWidgets('shouldMarkDeletedTargetReadWithoutNavigation', (
    WidgetTester tester,
  ) async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[
        memoryCreatedNotification(
          story: const NotificationStoryReference(
            storyId: null,
            title: null,
          ),
          memory: const NotificationMemoryReference(
            memoryId: null,
            title: null,
          ),
        ),
      ];
    var navigationCalls = 0;

    await pumpScreen(
      tester,
      repository,
      onMemorySelected: (_, __) {
        navigationCalls += 1;
      },
    );

    await tester.tap(
      find.byKey(const ValueKey('notifications.item.notification-created')),
    );
    await tester.pumpAndSettle();

    expect(repository.markReadIds, <String>['notification-created']);
    expect(navigationCalls, 0);
    expect(find.text('This story item is no longer available'), findsOneWidget);
  });

  testWidgets('shouldMarkAllReadAndClearUnreadState', (
    WidgetTester tester,
  ) async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 2
      ..notificationsResult = <NotificationItem>[
        participantJoinedNotification(),
        memoryCreatedNotification(),
      ];

    await pumpScreen(tester, repository);

    expect(find.byKey(const ValueKey('notifications.mark-all-action')),
        findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('notifications.mark-all-action')),
    );
    await tester.pumpAndSettle();

    expect(repository.markAllReadCalls, 1);
    expect(find.byKey(const ValueKey('notifications.mark-all-action')),
        findsNothing);
    expect(
      find.byKey(
        const ValueKey('notifications.item.unread-indicator.notification-joined'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey(
          'notifications.item.unread-indicator.notification-created',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('shouldRenderRussianNotificationCopy', (
    WidgetTester tester,
  ) async {
    final repository = FakeNotificationRepository()
      ..notificationsResult = <NotificationItem>[
        participantJoinedNotification(),
      ];

    await pumpScreen(
      tester,
      repository,
      locale: const Locale('ru'),
    );

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Morgan присоединился к истории'), findsOneWidget);
  });
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeNotificationRepository repository, {
  Locale locale = const Locale('en'),
  void Function(String storyId)? onParticipantsSelected,
  void Function(String storyId, String memoryId)? onMemorySelected,
  media_fixtures.FakeMediaRepository? mediaRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        mediaRepositoryProvider.overrideWithValue(
          mediaRepository ?? media_fixtures.FakeMediaRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationsScreen(
          onParticipantsSelected: onParticipantsSelected,
          onMemorySelected: onMemorySelected,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

NotificationItem participantJoinedNotification({
  String id = 'notification-joined',
  bool read = false,
  String? avatarUrl,
}) {
  return NotificationItem(
    id: id,
    type: NotificationType.participantJoined,
    actor: NotificationActor(
      userId: 'actor-joined',
      displayName: 'Morgan',
      avatarUrl: avatarUrl,
    ),
    story: const NotificationStoryReference(
      storyId: 'story-1',
      title: 'Our story',
    ),
    memory: null,
    createdAt: DateTime.utc(2026, 8, 9, 10),
    read: read,
  );
}

NotificationItem memoryCreatedNotification({
  String id = 'notification-created',
  bool read = false,
  String? avatarUrl,
  NotificationStoryReference? story = const NotificationStoryReference(
    storyId: 'story-1',
    title: 'Our story',
  ),
  NotificationMemoryReference? memory = const NotificationMemoryReference(
    memoryId: 'memory-a',
    title: 'First picnic',
  ),
}) {
  return NotificationItem(
    id: id,
    type: NotificationType.memoryCreated,
    actor: NotificationActor(
      userId: 'actor-created',
      displayName: 'Ada',
      avatarUrl: avatarUrl,
    ),
    story: story,
    memory: memory,
    createdAt: DateTime.utc(2026, 8, 9, 11),
    read: read,
  );
}

NotificationItem photosAddedNotification({
  String id = 'notification-photos',
  bool read = false,
  String? avatarUrl,
}) {
  return NotificationItem(
    id: id,
    type: NotificationType.photosAdded,
    actor: NotificationActor(
      userId: 'actor-photos',
      displayName: 'Grace',
      avatarUrl: avatarUrl,
    ),
    story: const NotificationStoryReference(
      storyId: 'story-1',
      title: 'Our story',
    ),
    memory: const NotificationMemoryReference(
      memoryId: 'memory-b',
      title: 'Beach morning',
    ),
    createdAt: DateTime.utc(2026, 8, 9, 12),
    read: read,
  );
}

final class FakeNotificationRepository implements NotificationRepository {
  int unreadCount = 0;
  int markAllReadCalls = 0;
  List<NotificationItem> notificationsResult = <NotificationItem>[];
  final List<String> markReadIds = <String>[];

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    return notificationsResult;
  }

  @override
  Future<int> getUnreadCount() async {
    return unreadCount;
  }

  @override
  Future<void> markRead(String notificationId) async {
    markReadIds.add(notificationId);
    unreadCount = (unreadCount - 1).clamp(0, 999).toInt();
    notificationsResult = notificationsResult
        .map(
          (notification) => notification.id == notificationId
              ? notification.copyWith(read: true)
              : notification,
        )
        .toList();
  }

  @override
  Future<void> markAllRead() async {
    markAllReadCalls += 1;
    unreadCount = 0;
    notificationsResult = notificationsResult
        .map((notification) => notification.copyWith(read: true))
        .toList();
  }
}
