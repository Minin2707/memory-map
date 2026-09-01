package memory_map.backend.notification.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.notification.application.CountUnreadNotificationsUseCase;
import memory_map.backend.notification.application.ListNotificationsUseCase;
import memory_map.backend.notification.application.MarkAllNotificationsReadUseCase;
import memory_map.backend.notification.application.MarkNotificationReadUseCase;
import memory_map.backend.notification.application.NotificationActorView;
import memory_map.backend.notification.application.NotificationMemoryView;
import memory_map.backend.notification.application.NotificationNotFoundException;
import memory_map.backend.notification.application.NotificationReadModel;
import memory_map.backend.notification.application.NotificationStoryView;
import memory_map.backend.notification.domain.NotificationType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(NotificationController.class)
@AutoConfigureMockMvc
@Import({
        NotificationApiExceptionHandler.class,
        SecurityConfiguration.class,
        NotificationControllerTest.NotificationControllerTestConfiguration.class
})
class NotificationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeListNotificationsUseCase listNotificationsUseCase;

    @Autowired
    private FakeCountUnreadNotificationsUseCase
            countUnreadNotificationsUseCase;

    @Autowired
    private FakeMarkNotificationReadUseCase markNotificationReadUseCase;

    @Autowired
    private FakeMarkAllNotificationsReadUseCase
            markAllNotificationsReadUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID ACTOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID NOTIFICATION_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final String VALID_ACCESS_TOKEN = "valid-access-token";
    private static final String INVALID_ACCESS_TOKEN = "invalid-access-token";

    @BeforeEach
    void resetFakes() {
        listNotificationsUseCase.reset();
        countUnreadNotificationsUseCase.reset();
        markNotificationReadUseCase.reset();
        markAllNotificationsReadUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldReturnBoundedNotificationsForCurrentUser() throws Exception {
        listNotificationsUseCase.notifications(List.of(
                notification(NotificationType.MEMORY_CREATED, true),
                new NotificationReadModel(
                        UUID.fromString(
                                "00000000-0000-0000-0000-000000000032"
                        ),
                        NotificationType.PARTICIPANT_JOINED,
                        new NotificationActorView(
                                ACTOR_ID,
                                "Actor User",
                                null
                        ),
                        new NotificationStoryView(STORY_ID, "Our Story"),
                        null,
                        CURRENT_TIME.minusSeconds(60),
                        null
                )
        ));

        String response = mockMvc.perform(get("/api/v1/notifications")
                        .param("limit", "500")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(content()
                        .contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id")
                        .value(NOTIFICATION_ID.toString()))
                .andExpect(jsonPath("$[0].type").value("MEMORY_CREATED"))
                .andExpect(jsonPath("$[0].actor.userId")
                        .value(ACTOR_ID.toString()))
                .andExpect(jsonPath("$[0].actor.displayName")
                        .value("Actor User"))
                .andExpect(jsonPath("$[0].actor.avatarUrl")
                        .value("/api/v1/stories/%s/participants/%s/avatar/%d"
                                .formatted(
                                        STORY_ID,
                                        ACTOR_ID,
                                        CURRENT_TIME.toEpochMilli()
                                )))
                .andExpect(jsonPath("$[0].story.storyId")
                        .value(STORY_ID.toString()))
                .andExpect(jsonPath("$[0].story.title")
                        .value("Our Story"))
                .andExpect(jsonPath("$[0].memory.memoryId")
                        .value(MEMORY_ID.toString()))
                .andExpect(jsonPath("$[0].memory.title")
                        .value("First Memory"))
                .andExpect(jsonPath("$[0].createdAt")
                        .value("2026-01-10T10:00:00Z"))
                .andExpect(jsonPath("$[0].read").value(true))
                .andExpect(jsonPath("$[1].memory").value((Object) null))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(listNotificationsUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(listNotificationsUseCase.receivedLimit()).isEqualTo(100);
        assertThat(response)
                .doesNotContain("email")
                .doesNotContain("storageKey")
                .doesNotContain("minio");
    }

    @Test
    void shouldUseDefaultLimitForInvalidLimit() throws Exception {
        mockMvc.perform(get("/api/v1/notifications")
                        .param("limit", "0")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk());

        assertThat(listNotificationsUseCase.receivedLimit()).isEqualTo(50);
    }

    @Test
    void shouldReturnUnreadCount() throws Exception {
        countUnreadNotificationsUseCase.count = 3;

        mockMvc.perform(get("/api/v1/notifications/unread-count")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(3));

        assertThat(countUnreadNotificationsUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
    }

    @Test
    void shouldMarkNotificationReadWithServerTime() throws Exception {
        mockMvc.perform(patch(
                        "/api/v1/notifications/{notificationId}/read",
                        NOTIFICATION_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        assertThat(markNotificationReadUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(markNotificationReadUseCase.receivedNotificationId())
                .isEqualTo(NOTIFICATION_ID);
        assertThat(markNotificationReadUseCase.receivedReadAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnNotFoundWhenNotificationDoesNotBelongToUser()
            throws Exception {
        markNotificationReadUseCase.exception =
                new NotificationNotFoundException();

        String response = mockMvc.perform(patch(
                        "/api/v1/notifications/{notificationId}/read",
                        NOTIFICATION_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Notification was not found"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(NOTIFICATION_ID.toString())
                .doesNotContain(USER_ID.toString());
    }

    @Test
    void shouldMarkAllNotificationsReadWithServerTime() throws Exception {
        mockMvc.perform(patch("/api/v1/notifications/read-all")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        assertThat(markAllNotificationsReadUseCase
                .receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(markAllNotificationsReadUseCase.receivedReadAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectUnauthenticatedRequests() throws Exception {
        mockMvc.perform(get("/api/v1/notifications"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/v1/notifications/unread-count"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(patch(
                        "/api/v1/notifications/{notificationId}/read",
                        NOTIFICATION_ID
                ))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(patch("/api/v1/notifications/read-all"))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(listNotificationsUseCase.callCount()).isZero();
        assertThat(countUnreadNotificationsUseCase.callCount()).isZero();
        assertThat(markNotificationReadUseCase.callCount()).isZero();
        assertThat(markAllNotificationsReadUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectInvalidBearerToken() throws Exception {
        String response = mockMvc.perform(get("/api/v1/notifications")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + INVALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(listNotificationsUseCase.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new NotificationController(
                null,
                countUnreadNotificationsUseCase,
                markNotificationReadUseCase,
                markAllNotificationsReadUseCase,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("listNotificationsUseCase must not be null");

        assertThatThrownBy(() -> new NotificationController(
                listNotificationsUseCase,
                null,
                markNotificationReadUseCase,
                markAllNotificationsReadUseCase,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "countUnreadNotificationsUseCase must not be null"
                );

        assertThatThrownBy(() -> new NotificationController(
                listNotificationsUseCase,
                countUnreadNotificationsUseCase,
                null,
                markAllNotificationsReadUseCase,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("markNotificationReadUseCase must not be null");

        assertThatThrownBy(() -> new NotificationController(
                listNotificationsUseCase,
                countUnreadNotificationsUseCase,
                markNotificationReadUseCase,
                null,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "markAllNotificationsReadUseCase must not be null"
                );

        assertThatThrownBy(() -> new NotificationController(
                listNotificationsUseCase,
                countUnreadNotificationsUseCase,
                markNotificationReadUseCase,
                markAllNotificationsReadUseCase,
                null,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "currentAuthenticatedUserProvider must not be null"
                );

        assertThatThrownBy(() -> new NotificationController(
                listNotificationsUseCase,
                countUnreadNotificationsUseCase,
                markNotificationReadUseCase,
                markAllNotificationsReadUseCase,
                currentAuthenticatedUserProvider,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    private static NotificationReadModel notification(
            NotificationType type,
            boolean read
    ) {
        return new NotificationReadModel(
                NOTIFICATION_ID,
                type,
                new NotificationActorView(
                        ACTOR_ID,
                        "Actor User",
                        "/api/v1/stories/%s/participants/%s/avatar/%d"
                                .formatted(
                                        STORY_ID,
                                        ACTOR_ID,
                                        CURRENT_TIME.toEpochMilli()
                                )
                ),
                new NotificationStoryView(STORY_ID, "Our Story"),
                new NotificationMemoryView(MEMORY_ID, "First Memory"),
                CURRENT_TIME,
                read ? CURRENT_TIME.plusSeconds(60) : null
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class NotificationControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(CURRENT_TIME, ZoneOffset.UTC);
        }

        @Bean
        FakeListNotificationsUseCase listNotificationsUseCase() {
            return new FakeListNotificationsUseCase();
        }

        @Bean
        FakeCountUnreadNotificationsUseCase
        countUnreadNotificationsUseCase() {
            return new FakeCountUnreadNotificationsUseCase();
        }

        @Bean
        FakeMarkNotificationReadUseCase markNotificationReadUseCase() {
            return new FakeMarkNotificationReadUseCase();
        }

        @Bean
        FakeMarkAllNotificationsReadUseCase markAllNotificationsReadUseCase() {
            return new FakeMarkAllNotificationsReadUseCase();
        }

        @Bean
        @Primary
        FakeCurrentAuthenticatedUserProvider
        fakeCurrentAuthenticatedUserProvider() {
            return new FakeCurrentAuthenticatedUserProvider();
        }

        @Bean
        JwtDecoder jwtDecoder() {
            return token -> {
                if (!VALID_ACCESS_TOKEN.equals(token)) {
                    throw new BadJwtException("Access token is invalid");
                }

                return Jwt.withTokenValue(token)
                        .headers(headers -> headers.putAll(Map.of(
                                "alg",
                                "none"
                        )))
                        .subject(USER_ID.toString())
                        .issuedAt(CURRENT_TIME)
                        .expiresAt(CURRENT_TIME.plusSeconds(900))
                        .build();
            };
        }
    }

    static final class FakeListNotificationsUseCase
            implements ListNotificationsUseCase {

        private List<NotificationReadModel> notifications = List.of();
        private AuthenticatedUser receivedAuthenticatedUser;
        private int receivedLimit;
        private int callCount;

        @Override
        public List<NotificationReadModel> listNotifications(
                AuthenticatedUser authenticatedUser,
                int limit
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedLimit = limit;
            callCount++;

            return notifications;
        }

        private void notifications(
                List<NotificationReadModel> notifications
        ) {
            this.notifications = notifications;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private int receivedLimit() {
            return receivedLimit;
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            notifications = List.of();
            receivedAuthenticatedUser = null;
            receivedLimit = 0;
            callCount = 0;
        }
    }

    static final class FakeCountUnreadNotificationsUseCase
            implements CountUnreadNotificationsUseCase {

        private long count;
        private AuthenticatedUser receivedAuthenticatedUser;
        private int callCount;

        @Override
        public long countUnread(AuthenticatedUser authenticatedUser) {
            receivedAuthenticatedUser = authenticatedUser;
            callCount++;

            return count;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            count = 0;
            receivedAuthenticatedUser = null;
            callCount = 0;
        }
    }

    static final class FakeMarkNotificationReadUseCase
            implements MarkNotificationReadUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedNotificationId;
        private Instant receivedReadAt;
        private RuntimeException exception;
        private int callCount;

        @Override
        public void markRead(
                AuthenticatedUser authenticatedUser,
                UUID notificationId,
                Instant readAt
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedNotificationId = notificationId;
            receivedReadAt = readAt;
            callCount++;

            if (exception != null) {
                throw exception;
            }
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private UUID receivedNotificationId() {
            return receivedNotificationId;
        }

        private Instant receivedReadAt() {
            return receivedReadAt;
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedNotificationId = null;
            receivedReadAt = null;
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeMarkAllNotificationsReadUseCase
            implements MarkAllNotificationsReadUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private Instant receivedReadAt;
        private int callCount;

        @Override
        public void markAllRead(
                AuthenticatedUser authenticatedUser,
                Instant readAt
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedReadAt = readAt;
            callCount++;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private Instant receivedReadAt() {
            return receivedReadAt;
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedReadAt = null;
            callCount = 0;
        }
    }

    static final class FakeCurrentAuthenticatedUserProvider
            implements CurrentAuthenticatedUserProvider {

        private int callCount;

        @Override
        public AuthenticatedUser getCurrentUser() {
            callCount++;

            return new AuthenticatedUser(USER_ID);
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            callCount = 0;
        }
    }
}
