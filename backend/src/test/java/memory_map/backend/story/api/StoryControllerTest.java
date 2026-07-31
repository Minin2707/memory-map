package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.story.application.CreateStoryCommand;
import memory_map.backend.story.application.CreateStoryUseCase;
import memory_map.backend.story.domain.Story;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(StoryController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(StoryControllerTest.StoryControllerTestConfiguration.class)
class StoryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeCreateStoryUseCase createStoryUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @Autowired
    private Clock clock;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final Instant RETURNED_CREATED_AT =
            Instant.parse("2026-01-10T10:01:00Z");
    private static final Instant RETURNED_UPDATED_AT =
            Instant.parse("2026-01-10T10:02:00Z");

    @BeforeEach
    void resetFakes() {
        createStoryUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldCreateStoryFromAuthenticatedUserAndRequest()
            throws Exception {

        String response = mockMvc.perform(post("/api/v1/stories")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Our Story",
                                  "description": "The beginning"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.title").value("Returned Story"))
                .andExpect(jsonPath("$.description")
                        .value("Returned description"))
                .andExpect(jsonPath("$.createdAt")
                        .value("2026-01-10T10:01:00Z"))
                .andExpect(jsonPath("$.updatedAt")
                        .value("2026-01-10T10:02:00Z"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        CreateStoryCommand command = createStoryUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isNotNull();
        assertThat(command.title()).isEqualTo("Our Story");
        assertThat(command.description()).isEqualTo("The beginning");
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(createStoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .contains(command.storyId().toString())
                .doesNotContain("ownerId")
                .doesNotContain("role")
                .doesNotContain("token")
                .doesNotContain("googleSubject");
    }

    @Test
    void shouldAllowMissingDescription() throws Exception {

        mockMvc.perform(post("/api/v1/stories")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Our Story"
                                }
                                """))
                .andExpect(status().isCreated());

        assertThat(createStoryUseCase.receivedCommand().description())
                .isNull();
    }

    @Test
    void shouldReturnBadRequestForMissingTitle() throws Exception {

        mockMvc.perform(post("/api/v1/stories")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "description": "The beginning"
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(createStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForNullTitle() throws Exception {

        mockMvc.perform(post("/api/v1/stories")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": null
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(createStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForEmptyTitle() throws Exception {

        mockMvc.perform(post("/api/v1/stories")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": ""
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(createStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForBlankTitle() throws Exception {

        mockMvc.perform(post("/api/v1/stories")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "   "
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(createStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedJson() throws Exception {

        mockMvc.perform(post("/api/v1/stories")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Our Story",
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(createStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectNullCreateStoryUseCaseDependency() {

        assertThatThrownBy(() -> new StoryController(
                null,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("createStoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullCurrentAuthenticatedUserProviderDependency() {

        assertThatThrownBy(() -> new StoryController(
                createStoryUseCase,
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

        assertThatThrownBy(() -> new StoryController(
                createStoryUseCase,
                currentAuthenticatedUserProvider,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class StoryControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(
                    CURRENT_TIME,
                    ZoneOffset.UTC
            );
        }

        @Bean
        FakeCreateStoryUseCase createStoryUseCase() {
            return new FakeCreateStoryUseCase();
        }

        @Bean
        FakeCurrentAuthenticatedUserProvider
        currentAuthenticatedUserProvider() {
            return new FakeCurrentAuthenticatedUserProvider();
        }
    }

    static final class FakeCreateStoryUseCase
            implements CreateStoryUseCase {

        private CreateStoryCommand receivedCommand;
        private int callCount;

        @Override
        public Story create(CreateStoryCommand command) {
            receivedCommand = command;
            callCount++;

            return new Story(
                    command.storyId(),
                    command.authenticatedUser().userId(),
                    "Returned Story",
                    "Returned description",
                    RETURNED_CREATED_AT,
                    RETURNED_UPDATED_AT
            );
        }

        private CreateStoryCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            receivedCommand = null;
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
