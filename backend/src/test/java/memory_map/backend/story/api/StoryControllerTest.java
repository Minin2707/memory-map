package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.story.application.CreateStoryCommand;
import memory_map.backend.story.application.CreateStoryUseCase;
import memory_map.backend.story.application.GetStoriesUseCase;
import memory_map.backend.story.application.GetStoryUseCase;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.StoryPhotoPreview;
import memory_map.backend.story.application.UpdateStoryCommand;
import memory_map.backend.story.application.UpdateStoryUseCase;
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
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(StoryController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import({
        StoryApiExceptionHandler.class,
        StoryControllerTest.StoryControllerTestConfiguration.class
})
class StoryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeCreateStoryUseCase createStoryUseCase;

    @Autowired
    private FakeGetStoriesUseCase getStoriesUseCase;

    @Autowired
    private FakeGetStoryUseCase getStoryUseCase;

    @Autowired
    private FakeUpdateStoryUseCase updateStoryUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @Autowired
    private Clock clock;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID FIRST_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID SECOND_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final String THUMBNAIL_URL =
            "/api/v1/media/%s/thumbnail".formatted(MEDIA_ID);
    private static final String DISPLAY_URL =
            "/api/v1/media/%s/display".formatted(MEDIA_ID);
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final Instant RETURNED_CREATED_AT =
            Instant.parse("2026-01-10T10:01:00Z");
    private static final Instant RETURNED_UPDATED_AT =
            Instant.parse("2026-01-10T10:02:00Z");

    @BeforeEach
    void resetFakes() {
        createStoryUseCase.reset();
        getStoriesUseCase.reset();
        getStoryUseCase.reset();
        updateStoryUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldReturnStories() throws Exception {

        UserStory first = userStory(
                FIRST_STORY_ID,
                "First Story",
                "First description",
                StoryRole.OWNER,
                24,
                2,
                new StoryPhotoPreview(THUMBNAIL_URL, DISPLAY_URL),
                RETURNED_CREATED_AT,
                RETURNED_UPDATED_AT
        );
        UserStory second = userStory(
                SECOND_STORY_ID,
                "Second Story",
                null,
                StoryRole.EDITOR,
                0,
                1,
                null,
                CURRENT_TIME,
                RETURNED_UPDATED_AT
        );
        getStoriesUseCase.userStories(List.of(first, second));

        String response = mockMvc.perform(get("/api/v1/stories"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id")
                        .value(FIRST_STORY_ID.toString()))
                .andExpect(jsonPath("$[0].title")
                        .value("First Story"))
                .andExpect(jsonPath("$[0].description")
                        .value("First description"))
                .andExpect(jsonPath("$[0].role")
                        .value("OWNER"))
                .andExpect(jsonPath("$[0].memoryCount")
                        .value(24))
                .andExpect(jsonPath("$[0].participantCount")
                        .value(2))
                .andExpect(jsonPath("$[0].previewPhoto.thumbnailUrl")
                        .value(THUMBNAIL_URL))
                .andExpect(jsonPath("$[0].previewPhoto.displayUrl")
                        .value(DISPLAY_URL))
                .andExpect(jsonPath("$[0].createdAt")
                        .value("2026-01-10T10:01:00Z"))
                .andExpect(jsonPath("$[0].updatedAt")
                        .value("2026-01-10T10:02:00Z"))
                .andExpect(jsonPath("$[1].id")
                        .value(SECOND_STORY_ID.toString()))
                .andExpect(jsonPath("$[1].title")
                        .value("Second Story"))
                .andExpect(jsonPath("$[1].description")
                        .value((Object) null))
                .andExpect(jsonPath("$[1].role")
                        .value("EDITOR"))
                .andExpect(jsonPath("$[1].memoryCount")
                        .value(0))
                .andExpect(jsonPath("$[1].participantCount")
                        .value(1))
                .andExpect(jsonPath("$[1].previewPhoto")
                        .value((Object) null))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getStoriesUseCase.callCount()).isEqualTo(1);
        assertThat(getStoriesUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(createStoryUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain("ownerId")
                .doesNotContain("userId")
                .doesNotContain("googleSubject")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken")
                .doesNotContain("joinedAt")
                .doesNotContain("storageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio");
    }

    @Test
    void shouldReturnEmptyArrayWhenUserHasNoStories() throws Exception {

        getStoriesUseCase.userStories(List.of());

        mockMvc.perform(get("/api/v1/stories"))
                .andExpect(status().isOk())
                .andExpect(content().string("[]"));

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getStoriesUseCase.callCount()).isEqualTo(1);
    }

    @Test
    void shouldReturnStoryById() throws Exception {

        UserStory userStory = userStory(
                FIRST_STORY_ID,
                "First Story",
                null,
                StoryRole.EDITOR,
                8,
                3,
                new StoryPhotoPreview(THUMBNAIL_URL, DISPLAY_URL),
                RETURNED_CREATED_AT,
                RETURNED_UPDATED_AT
        );
        getStoryUseCase.userStory(userStory);

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                ))
                .andExpect(status().isOk())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_JSON
                        ))
                .andExpect(jsonPath("$.id")
                        .value(FIRST_STORY_ID.toString()))
                .andExpect(jsonPath("$.title").value("First Story"))
                .andExpect(jsonPath("$.description")
                        .value((Object) null))
                .andExpect(jsonPath("$.role").value("EDITOR"))
                .andExpect(jsonPath("$.memoryCount").value(8))
                .andExpect(jsonPath("$.participantCount").value(3))
                .andExpect(jsonPath("$.previewPhoto.thumbnailUrl")
                        .value(THUMBNAIL_URL))
                .andExpect(jsonPath("$.previewPhoto.displayUrl")
                        .value(DISPLAY_URL))
                .andExpect(jsonPath("$.createdAt")
                        .value("2026-01-10T10:01:00Z"))
                .andExpect(jsonPath("$.updatedAt")
                        .value("2026-01-10T10:02:00Z"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getStoryUseCase.callCount()).isEqualTo(1);
        assertThat(getStoryUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(getStoryUseCase.receivedStoryId())
                .isEqualTo(FIRST_STORY_ID);
        assertThat(createStoryUseCase.callCount()).isZero();
        assertThat(getStoriesUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain("ownerId")
                .doesNotContain("userId")
                .doesNotContain("googleSubject")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken")
                .doesNotContain("joinedAt")
                .doesNotContain("archived")
                .doesNotContain("storageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio");
    }

    @Test
    void shouldReturnNotFoundWhenStoryIsUnavailable()
            throws Exception {

        getStoryUseCase.failWith(new StoryNotFoundException());

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                ))
                .andExpect(status().isNotFound())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_PROBLEM_JSON
                        ))
                .andExpect(jsonPath("$.title").value("Not Found"))
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.detail")
                        .value("Story was not found"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/stories"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getStoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(FIRST_STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("StoryNotFoundException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldRejectMalformedStoryId() throws Exception {

        mockMvc.perform(get("/api/v1/stories/not-a-uuid"))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(getStoryUseCase.callCount()).isZero();
        assertThat(createStoryUseCase.callCount()).isZero();
        assertThat(getStoriesUseCase.callCount()).isZero();
    }

    @Test
    void shouldUpdateStoryTitleOnly() throws Exception {

        String response = mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Returned Story"))
                .andExpect(jsonPath("$.description")
                        .value("Returned description"))
                .andExpect(jsonPath("$.role").value("OWNER"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        UpdateStoryCommand command =
                updateStoryUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(FIRST_STORY_ID);
        assertThat(command.title().isProvided()).isTrue();
        assertThat(command.title().value()).isEqualTo("Updated Story");
        assertThat(command.description().isProvided()).isFalse();
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(updateStoryUseCase.callCount()).isEqualTo(1);
        assertThat(getStoryUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain("ownerId")
                .doesNotContain("userId")
                .doesNotContain("googleSubject")
                .doesNotContain("joinedAt")
                .doesNotContain("archived");
    }

    @Test
    void shouldUpdateStoryDescriptionOnly() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "description": "Updated description"
                                }
                                """))
                .andExpect(status().isOk());

        UpdateStoryCommand command =
                updateStoryUseCase.receivedCommand();

        assertThat(command.title().isProvided()).isFalse();
        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value())
                .isEqualTo("Updated description");
    }

    @Test
    void shouldClearStoryDescription() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "description": null
                                }
                                """))
                .andExpect(status().isOk());

        UpdateStoryCommand command =
                updateStoryUseCase.receivedCommand();

        assertThat(command.title().isProvided()).isFalse();
        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value()).isNull();
    }

    @Test
    void shouldUpdateStoryTitleAndDescription() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story",
                                  "description": "Updated description"
                                }
                                """))
                .andExpect(status().isOk());

        UpdateStoryCommand command =
                updateStoryUseCase.receivedCommand();

        assertThat(command.title().isProvided()).isTrue();
        assertThat(command.title().value()).isEqualTo("Updated Story");
        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value())
                .isEqualTo("Updated description");
    }

    @Test
    void shouldUpdateStoryTitleAndClearDescription() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story",
                                  "description": null
                                }
                                """))
                .andExpect(status().isOk());

        UpdateStoryCommand command =
                updateStoryUseCase.receivedCommand();

        assertThat(command.title().value()).isEqualTo("Updated Story");
        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value()).isNull();
    }

    @Test
    void shouldReturnBadRequestForEmptyUpdatePatch() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());

        assertThat(updateStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForNullUpdateTitle() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": null
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(updateStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForEmptyUpdateTitle() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": ""
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(updateStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForBlankUpdateTitle() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "   "
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(updateStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedPatchJson() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story",
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(updateStoryUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectMalformedPatchStoryId() throws Exception {

        mockMvc.perform(patch("/api/v1/stories/not-a-uuid")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story"
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(updateStoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundWhenUpdateStoryIsUnavailable()
            throws Exception {

        updateStoryUseCase.failWith(new StoryNotFoundException());

        String response = mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        FIRST_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story"
                                }
                                """))
                .andExpect(status().isNotFound())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_PROBLEM_JSON
                        ))
                .andExpect(jsonPath("$.title").value("Not Found"))
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.detail")
                        .value("Story was not found"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/stories"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(updateStoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(FIRST_STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("StoryNotFoundException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
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
                getStoriesUseCase,
                getStoryUseCase,
                updateStoryUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("createStoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullGetStoriesUseCaseDependency() {

        assertThatThrownBy(() -> new StoryController(
                createStoryUseCase,
                null,
                getStoryUseCase,
                updateStoryUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("getStoriesUseCase must not be null");
    }

    @Test
    void shouldRejectNullGetStoryUseCaseDependency() {

        assertThatThrownBy(() -> new StoryController(
                createStoryUseCase,
                getStoriesUseCase,
                null,
                updateStoryUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("getStoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullUpdateStoryUseCaseDependency() {

        assertThatThrownBy(() -> new StoryController(
                createStoryUseCase,
                getStoriesUseCase,
                getStoryUseCase,
                null,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("updateStoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullCurrentAuthenticatedUserProviderDependency() {

        assertThatThrownBy(() -> new StoryController(
                createStoryUseCase,
                getStoriesUseCase,
                getStoryUseCase,
                updateStoryUseCase,
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
                getStoriesUseCase,
                getStoryUseCase,
                updateStoryUseCase,
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
        FakeGetStoriesUseCase getStoriesUseCase() {
            return new FakeGetStoriesUseCase();
        }

        @Bean
        FakeGetStoryUseCase getStoryUseCase() {
            return new FakeGetStoryUseCase();
        }

        @Bean
        FakeUpdateStoryUseCase updateStoryUseCase() {
            return new FakeUpdateStoryUseCase();
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
                    null,
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

    static final class FakeGetStoriesUseCase
            implements GetStoriesUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private List<UserStory> userStories = List.of();
        private int callCount;

        @Override
        public List<UserStory> getStories(
                AuthenticatedUser authenticatedUser
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            callCount++;

            return userStories;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private int callCount() {
            return callCount;
        }

        private void userStories(List<UserStory> userStories) {
            this.userStories = userStories;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            userStories = List.of();
            callCount = 0;
        }
    }

    static final class FakeGetStoryUseCase
            implements GetStoryUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedStoryId;
        private UserStory userStory = StoryControllerTest.userStory(
                FIRST_STORY_ID,
                "Returned Story",
                "Returned description",
                StoryRole.OWNER,
                RETURNED_CREATED_AT,
                RETURNED_UPDATED_AT
        );
        private RuntimeException exception;
        private int callCount;

        @Override
        public UserStory getStory(
                AuthenticatedUser authenticatedUser,
                UUID storyId
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedStoryId = storyId;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return userStory;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private int callCount() {
            return callCount;
        }

        private void userStory(UserStory userStory) {
            this.userStory = userStory;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedStoryId = null;
            userStory = StoryControllerTest.userStory(
                    FIRST_STORY_ID,
                    "Returned Story",
                    "Returned description",
                    StoryRole.OWNER,
                    RETURNED_CREATED_AT,
                    RETURNED_UPDATED_AT
            );
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeUpdateStoryUseCase
            implements UpdateStoryUseCase {

        private UpdateStoryCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public UserStory updateStory(UpdateStoryCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return StoryControllerTest.userStory(
                    command.storyId(),
                    "Returned Story",
                    "Returned description",
                    StoryRole.OWNER,
                    RETURNED_CREATED_AT,
                    RETURNED_UPDATED_AT
            );
        }

        private UpdateStoryCommand receivedCommand() {
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

    private static UserStory userStory(
            UUID storyId,
            String title,
            String description,
            StoryRole role,
            Instant createdAt,
            Instant updatedAt
    ) {
        return userStory(
                storyId,
                title,
                description,
                role,
                0,
                1,
                null,
                createdAt,
                updatedAt
        );
    }

    private static UserStory userStory(
            UUID storyId,
            String title,
            String description,
            StoryRole role,
            int memoryCount,
            int participantCount,
            StoryPhotoPreview previewPhoto,
            Instant createdAt,
            Instant updatedAt
    ) {
        return new UserStory(
                new Story(
                        storyId,
                        USER_ID,
                        title,
                        description,
                        null,
                        createdAt,
                        updatedAt
                ),
                role,
                memoryCount,
                participantCount,
                previewPhoto
        );
    }
}
