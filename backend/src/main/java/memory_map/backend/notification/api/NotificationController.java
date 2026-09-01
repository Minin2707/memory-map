package memory_map.backend.notification.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.notification.application.CountUnreadNotificationsUseCase;
import memory_map.backend.notification.application.ListNotificationsUseCase;
import memory_map.backend.notification.application.MarkAllNotificationsReadUseCase;
import memory_map.backend.notification.application.MarkNotificationReadUseCase;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private static final int DEFAULT_LIMIT = 50;
    private static final int MAX_LIMIT = 100;
    private static final String DEFAULT_LIMIT_REQUEST_PARAMETER = "50";

    private final ListNotificationsUseCase listNotificationsUseCase;
    private final CountUnreadNotificationsUseCase
            countUnreadNotificationsUseCase;
    private final MarkNotificationReadUseCase markNotificationReadUseCase;
    private final MarkAllNotificationsReadUseCase
            markAllNotificationsReadUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public NotificationController(
            ListNotificationsUseCase listNotificationsUseCase,
            CountUnreadNotificationsUseCase countUnreadNotificationsUseCase,
            MarkNotificationReadUseCase markNotificationReadUseCase,
            MarkAllNotificationsReadUseCase markAllNotificationsReadUseCase,
            CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.listNotificationsUseCase = Objects.requireNonNull(
                listNotificationsUseCase,
                "listNotificationsUseCase must not be null"
        );
        this.countUnreadNotificationsUseCase = Objects.requireNonNull(
                countUnreadNotificationsUseCase,
                "countUnreadNotificationsUseCase must not be null"
        );
        this.markNotificationReadUseCase = Objects.requireNonNull(
                markNotificationReadUseCase,
                "markNotificationReadUseCase must not be null"
        );
        this.markAllNotificationsReadUseCase = Objects.requireNonNull(
                markAllNotificationsReadUseCase,
                "markAllNotificationsReadUseCase must not be null"
        );
        this.currentAuthenticatedUserProvider = Objects.requireNonNull(
                currentAuthenticatedUserProvider,
                "currentAuthenticatedUserProvider must not be null"
        );
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
    }

    @GetMapping
    public List<NotificationResponse> listNotifications(
            @RequestParam(defaultValue = DEFAULT_LIMIT_REQUEST_PARAMETER)
            int limit
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return listNotificationsUseCase.listNotifications(
                authenticatedUser,
                boundedLimit(limit)
        )
                .stream()
                .map(NotificationResponse::from)
                .toList();
    }

    @GetMapping("/unread-count")
    public UnreadNotificationCountResponse countUnread() {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return new UnreadNotificationCountResponse(
                countUnreadNotificationsUseCase.countUnread(authenticatedUser)
        );
    }

    @PatchMapping("/{notificationId}/read")
    public ResponseEntity<Void> markRead(
            @PathVariable UUID notificationId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant readAt = clock.instant();

        markNotificationReadUseCase.markRead(
                authenticatedUser,
                notificationId,
                readAt
        );

        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/read-all")
    public ResponseEntity<Void> markAllRead() {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant readAt = clock.instant();

        markAllNotificationsReadUseCase.markAllRead(
                authenticatedUser,
                readAt
        );

        return ResponseEntity.noContent().build();
    }

    private static int boundedLimit(int limit) {
        if (limit < 1) {
            return DEFAULT_LIMIT;
        }

        return Math.min(limit, MAX_LIMIT);
    }
}
