package memory_map.backend.invite.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.invite.application.AcceptInviteCommand;
import memory_map.backend.invite.application.AcceptInviteUseCase;
import memory_map.backend.invite.application.CreateInviteCommand;
import memory_map.backend.invite.application.CreateInviteUseCase;
import memory_map.backend.invite.application.CreatedInvite;
import memory_map.backend.invite.application.InviteAcceptanceUnavailableException;
import memory_map.backend.invite.application.InviteCreationUnavailableException;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;
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

import java.net.URI;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(InviteController.class)
@AutoConfigureMockMvc
@Import({
        InviteApiExceptionHandler.class,
        SecurityConfiguration.class,
        InviteControllerTest.InviteControllerTestConfiguration.class
})
class InviteControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeCreateInviteUseCase createInviteUseCase;

    @Autowired
    private FakeAcceptInviteUseCase acceptInviteUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @Autowired
    private Clock clock;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-02-09T10:00:00Z");
    private static final String VALID_ACCESS_TOKEN =
            "valid-access-token";
    private static final String INVALID_ACCESS_TOKEN =
            "invalid-access-token";
    private static final String RAW_INVITE_TOKEN =
            "share-abc-123";
    private static final URI INVITE_LINK =
            URI.create("https://app.memorymap.app/invite/share-abc-123");
    private static final Instant STORY_CREATED_AT =
            Instant.parse("2026-01-10T10:01:00Z");
    private static final Instant STORY_UPDATED_AT =
            Instant.parse("2026-01-10T10:02:00Z");

    @BeforeEach
    void resetFakes() {
        createInviteUseCase.reset();
        acceptInviteUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldCreateInviteFromAuthenticatedUserAndStoryId()
            throws Exception {

        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/invites",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isCreated())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_JSON
                        ))
                .andExpect(jsonPath("$.inviteLink")
                        .value(INVITE_LINK.toString()))
                .andExpect(jsonPath("$.expiresAt")
                        .value("2026-02-09T10:00:00Z"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        CreateInviteCommand command =
                createInviteUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.inviteId()).isNotNull();
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(createInviteUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(command.inviteId().toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("tokenHash")
                .doesNotContain("rawToken")
                .doesNotContain("storyId")
                .doesNotContain("createdBy")
                .doesNotContain("createdAt")
                .doesNotContain("usedAt");
    }

    @Test
    void shouldAcceptInviteFromAuthenticatedUserAndToken()
            throws Exception {

        String response = mockMvc.perform(post(
                        "/api/v1/invites/{token}/accept",
                        RAW_INVITE_TOKEN
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_JSON
                        ))
                .andExpect(jsonPath("$.id")
                        .value(STORY_ID.toString()))
                .andExpect(jsonPath("$.title").value("Accepted Story"))
                .andExpect(jsonPath("$.description")
                        .value("Accepted description"))
                .andExpect(jsonPath("$.role").value("CO_OWNER"))
                .andExpect(jsonPath("$.createdAt")
                        .value("2026-01-10T10:01:00Z"))
                .andExpect(jsonPath("$.updatedAt")
                        .value("2026-01-10T10:02:00Z"))
                .andExpect(jsonPath("$.inviteLink").doesNotExist())
                .andExpect(jsonPath("$.expiresAt").doesNotExist())
                .andExpect(jsonPath("$.usedAt").doesNotExist())
                .andExpect(jsonPath("$.token").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        AcceptInviteCommand command =
                acceptInviteUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.rawInviteToken()).isEqualTo(RAW_INVITE_TOKEN);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(acceptInviteUseCase.callCount()).isEqualTo(1);
        assertThat(createInviteUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain(RAW_INVITE_TOKEN)
                .doesNotContain("invite")
                .doesNotContain("tokenHash")
                .doesNotContain("rawToken")
                .doesNotContain("expiresAt")
                .doesNotContain("usedAt")
                .doesNotContain("createdBy");
    }

    @Test
    void shouldReturnNotFoundWhenInviteCreationIsUnavailable()
            throws Exception {

        createInviteUseCase.failWith(
                new InviteCreationUnavailableException()
        );

        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/invites",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_PROBLEM_JSON
                        ))
                .andExpect(jsonPath("$.title").value("Not Found"))
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.detail")
                        .value("Invite could not be created"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(createInviteUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("InviteCreationUnavailableException")
                .doesNotContain("stackTrace")
                .doesNotContain("tokenHash")
                .doesNotContain("rawToken")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnNotFoundWhenInviteAcceptanceIsUnavailable()
            throws Exception {

        acceptInviteUseCase.failWith(
                new InviteAcceptanceUnavailableException()
        );

        String response = mockMvc.perform(post(
                        "/api/v1/invites/{token}/accept",
                        RAW_INVITE_TOKEN
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_PROBLEM_JSON
                        ))
                .andExpect(jsonPath("$.title").value("Not Found"))
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.detail")
                        .value("Invite could not be accepted"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/invites/accept"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(acceptInviteUseCase.callCount()).isEqualTo(1);
        assertThat(createInviteUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain(RAW_INVITE_TOKEN)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("InviteAcceptanceUnavailableException")
                .doesNotContain("stackTrace")
                .doesNotContain("tokenHash")
                .doesNotContain("rawToken")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryId() throws Exception {

        mockMvc.perform(post("/api/v1/stories/not-a-uuid/invites")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createInviteUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectRequestWithoutBearerToken() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/invites",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createInviteUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectRequestWithInvalidBearerToken() throws Exception {

        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/invites",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + INVALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createInviteUseCase.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
    }

    @Test
    void shouldRejectAcceptInviteWithoutBearerToken() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/invites/{token}/accept",
                        RAW_INVITE_TOKEN
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createInviteUseCase.callCount()).isZero();
        assertThat(acceptInviteUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectAcceptInviteWithInvalidBearerToken()
            throws Exception {

        String response = mockMvc.perform(post(
                        "/api/v1/invites/{token}/accept",
                        RAW_INVITE_TOKEN
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + INVALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createInviteUseCase.callCount()).isZero();
        assertThat(acceptInviteUseCase.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
        assertThat(response).doesNotContain(RAW_INVITE_TOKEN);
    }

    @Test
    void shouldRejectNullCreateInviteUseCaseDependency() {

        assertThatThrownBy(() -> new InviteController(
                null,
                acceptInviteUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("createInviteUseCase must not be null");
    }

    @Test
    void shouldRejectNullAcceptInviteUseCaseDependency() {

        assertThatThrownBy(() -> new InviteController(
                createInviteUseCase,
                null,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("acceptInviteUseCase must not be null");
    }

    @Test
    void shouldRejectNullCurrentAuthenticatedUserProviderDependency() {

        assertThatThrownBy(() -> new InviteController(
                createInviteUseCase,
                acceptInviteUseCase,
                null,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "currentAuthenticatedUserProvider must not be null"
                );
    }

    @Test
    void shouldRejectNullClockDependency() {

        assertThatThrownBy(() -> new InviteController(
                createInviteUseCase,
                acceptInviteUseCase,
                currentAuthenticatedUserProvider,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class InviteControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(
                    CURRENT_TIME,
                    ZoneOffset.UTC
            );
        }

        @Bean
        FakeCreateInviteUseCase createInviteUseCase() {
            return new FakeCreateInviteUseCase();
        }

        @Bean
        FakeAcceptInviteUseCase acceptInviteUseCase() {
            return new FakeAcceptInviteUseCase();
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

    static final class FakeCreateInviteUseCase
            implements CreateInviteUseCase {

        private CreateInviteCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public CreatedInvite createInvite(CreateInviteCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return new CreatedInvite(
                    INVITE_LINK,
                    EXPIRES_AT
            );
        }

        private CreateInviteCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedCommand = null;
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeAcceptInviteUseCase
            implements AcceptInviteUseCase {

        private AcceptInviteCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public UserStory acceptInvite(AcceptInviteCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return new UserStory(
                    new Story(
                            STORY_ID,
                            USER_ID,
                            "Accepted Story",
                            "Accepted description",
                            STORY_CREATED_AT,
                            STORY_UPDATED_AT
                    ),
                    StoryRole.CO_OWNER
            );
        }

        private AcceptInviteCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedCommand = null;
            exception = null;
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
