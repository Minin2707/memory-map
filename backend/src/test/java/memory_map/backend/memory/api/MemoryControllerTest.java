package memory_map.backend.memory.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.memory.application.CreateMemoryCommand;
import memory_map.backend.memory.application.CreateMemoryUseCase;
import memory_map.backend.memory.application.DeleteMemoryCommand;
import memory_map.backend.memory.application.DeleteMemoryUseCase;
import memory_map.backend.memory.application.GetMemoryUseCase;
import memory_map.backend.memory.application.GetStoryMemoriesUseCase;
import memory_map.backend.memory.application.MemoryCreationUnavailableException;
import memory_map.backend.memory.application.MemoryDeletionUnavailableException;
import memory_map.backend.memory.application.MemoryNotFoundException;
import memory_map.backend.memory.application.MemoryUpdateUnavailableException;
import memory_map.backend.memory.application.UpdateMemoryCommand;
import memory_map.backend.memory.application.UpdateMemoryUseCase;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.story.application.StoryNotFoundException;
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
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(MemoryController.class)
@AutoConfigureMockMvc
@Import({
        MemoryApiExceptionHandler.class,
        SecurityConfiguration.class,
        MemoryControllerTest.MemoryControllerTestConfiguration.class
})
class MemoryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeCreateMemoryUseCase createMemoryUseCase;

    @Autowired
    private FakeGetStoryMemoriesUseCase getStoryMemoriesUseCase;

    @Autowired
    private FakeGetMemoryUseCase getMemoryUseCase;

    @Autowired
    private FakeUpdateMemoryUseCase updateMemoryUseCase;

    @Autowired
    private FakeDeleteMemoryUseCase deleteMemoryUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @Autowired
    private Clock clock;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID SECOND_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final UUID THIRD_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000023");
    private static final UUID CLIENT_SUPPLIED_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000099");
    private static final UUID CLIENT_SUPPLIED_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000088");
    private static final UUID CLIENT_SUPPLIED_CREATED_BY =
            UUID.fromString("00000000-0000-0000-0000-000000000077");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 18);
    private static final String VALID_ACCESS_TOKEN = "valid-access-token";
    private static final String INVALID_ACCESS_TOKEN = "invalid-access-token";

    @BeforeEach
    void resetFakes() {
        createMemoryUseCase.reset();
        getStoryMemoriesUseCase.reset();
        getMemoryUseCase.reset();
        updateMemoryUseCase.reset();
        deleteMemoryUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldReturnStoryMemories() throws Exception {

        Memory first = memory(
                MEMORY_ID,
                "Second by title",
                "First description",
                "Tbilisi",
                LocalDate.of(2024, 5, 18)
        );
        Memory second = memory(
                SECOND_MEMORY_ID,
                "First by title",
                null,
                null,
                LocalDate.of(2024, 5, 17)
        );
        getStoryMemoriesUseCase.memories(List.of(first, second));

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
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
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id")
                        .value(MEMORY_ID.toString()))
                .andExpect(jsonPath("$[0].storyId")
                        .value(STORY_ID.toString()))
                .andExpect(jsonPath("$[0].createdBy")
                        .value(USER_ID.toString()))
                .andExpect(jsonPath("$[0].title")
                        .value("Second by title"))
                .andExpect(jsonPath("$[0].description")
                        .value("First description"))
                .andExpect(jsonPath("$[0].placeName")
                        .value("Tbilisi"))
                .andExpect(jsonPath("$[0].latitude")
                        .value(41.6938))
                .andExpect(jsonPath("$[0].longitude")
                        .value(44.8015))
                .andExpect(jsonPath("$[0].eventDate")
                        .value("2024-05-18"))
                .andExpect(jsonPath("$[0].createdAt")
                        .value("2026-01-10T10:00:00Z"))
                .andExpect(jsonPath("$[0].updatedAt")
                        .value("2026-01-10T10:00:00Z"))
                .andExpect(jsonPath("$[1].id")
                        .value(SECOND_MEMORY_ID.toString()))
                .andExpect(jsonPath("$[1].description")
                        .value((Object) null))
                .andExpect(jsonPath("$[1].placeName")
                        .value((Object) null))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getStoryMemoriesUseCase.callCount()).isEqualTo(1);
        assertThat(getStoryMemoriesUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(getStoryMemoriesUseCase.receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(createMemoryUseCase.callCount()).isZero();
        assertThat(getMemoryUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain("ownerId")
                .doesNotContain("role")
                .doesNotContain("permission")
                .doesNotContain("media")
                .doesNotContain("photos");
    }

    @Test
    void shouldReturnEmptyArrayWhenAccessibleStoryHasNoMemories()
            throws Exception {

        getStoryMemoriesUseCase.memories(List.of());

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(content().string("[]"));

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getStoryMemoriesUseCase.callCount()).isEqualTo(1);
    }

    @Test
    void shouldPreserveStoryMemoriesOrderFromUseCase() throws Exception {

        getStoryMemoriesUseCase.memories(List.of(
                memory(SECOND_MEMORY_ID, "B", null, null, EVENT_DATE),
                memory(MEMORY_ID, "A", null, null, EVENT_DATE.minusDays(1)),
                memory(THIRD_MEMORY_ID, "C", null, null, EVENT_DATE)
        ));

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id")
                        .value(SECOND_MEMORY_ID.toString()))
                .andExpect(jsonPath("$[1].id")
                        .value(MEMORY_ID.toString()))
                .andExpect(jsonPath("$[2].id")
                        .value(THIRD_MEMORY_ID.toString()));
    }

    @Test
    void shouldReturnNotFoundWhenStoryMemoriesAreUnavailable()
            throws Exception {

        getStoryMemoriesUseCase.failWith(new StoryNotFoundException());

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
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
                        .value("Story was not found"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/stories"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getStoryMemoriesUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("membership")
                .doesNotContain("role")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnMemoryById() throws Exception {

        Memory memory = memory(
                MEMORY_ID,
                "Quiet evening",
                null,
                null,
                EVENT_DATE
        );
        getMemoryUseCase.memory(memory);

        String response = mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
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
                        .value(MEMORY_ID.toString()))
                .andExpect(jsonPath("$.storyId")
                        .value(STORY_ID.toString()))
                .andExpect(jsonPath("$.createdBy")
                        .value(USER_ID.toString()))
                .andExpect(jsonPath("$.title")
                        .value("Quiet evening"))
                .andExpect(jsonPath("$.description")
                        .value((Object) null))
                .andExpect(jsonPath("$.placeName")
                        .value((Object) null))
                .andExpect(jsonPath("$.latitude")
                        .value(41.6938))
                .andExpect(jsonPath("$.longitude")
                        .value(44.8015))
                .andExpect(jsonPath("$.eventDate")
                        .value("2024-05-18"))
                .andExpect(jsonPath("$.createdAt")
                        .value("2026-01-10T10:00:00Z"))
                .andExpect(jsonPath("$.updatedAt")
                        .value("2026-01-10T10:00:00Z"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getMemoryUseCase.callCount()).isEqualTo(1);
        assertThat(getMemoryUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(getMemoryUseCase.receivedMemoryId())
                .isEqualTo(MEMORY_ID);
        assertThat(createMemoryUseCase.callCount()).isZero();
        assertThat(getStoryMemoriesUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain("ownerId")
                .doesNotContain("role")
                .doesNotContain("permission")
                .doesNotContain("media")
                .doesNotContain("photos");
    }

    @Test
    void shouldReturnNotFoundWhenMemoryIsUnavailable()
            throws Exception {

        getMemoryUseCase.failWith(new MemoryNotFoundException());

        String response = mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
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
                        .value("Memory was not found"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/memories"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getMemoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("Quiet evening")
                .doesNotContain("role")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldUpdateMemoryTitleOnly() throws Exception {

        String response = mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated title"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_JSON
                        ))
                .andExpect(jsonPath("$.id").value(MEMORY_ID.toString()))
                .andExpect(jsonPath("$.title").value("Updated title"))
                .andExpect(jsonPath("$.description")
                        .value("Old city walk"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        UpdateMemoryCommand command =
                updateMemoryUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.title().isProvided()).isTrue();
        assertThat(command.title().value()).isEqualTo("Updated title");
        assertThat(command.description().isProvided()).isFalse();
        assertThat(command.placeName().isProvided()).isFalse();
        assertThat(command.latitude().isProvided()).isFalse();
        assertThat(command.longitude().isProvided()).isFalse();
        assertThat(command.eventDate().isProvided()).isFalse();
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(updateMemoryUseCase.callCount()).isEqualTo(1);
        assertThat(createMemoryUseCase.callCount()).isZero();
        assertThat(getStoryMemoriesUseCase.callCount()).isZero();
        assertThat(getMemoryUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain("ownerId")
                .doesNotContain("role")
                .doesNotContain("permission")
                .doesNotContain("media")
                .doesNotContain("photos");
    }

    @Test
    void shouldClearMemoryDescriptionWhenExplicitNullIsProvided()
            throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "description": null
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.description").value((Object) null));

        UpdateMemoryCommand command =
                updateMemoryUseCase.receivedCommand();

        assertThat(command.title().isProvided()).isFalse();
        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value()).isNull();
    }

    @Test
    void shouldKeepDescriptionNotProvidedWhenDescriptionIsAbsent()
            throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "X"
                                }
                                """))
                .andExpect(status().isOk());

        UpdateMemoryCommand command =
                updateMemoryUseCase.receivedCommand();

        assertThat(command.title().isProvided()).isTrue();
        assertThat(command.title().value()).isEqualTo("X");
        assertThat(command.description().isProvided()).isFalse();
    }

    @Test
    void shouldClearMemoryPlaceNameWhenExplicitNullIsProvided()
            throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "placeName": null
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.placeName").value((Object) null));

        UpdateMemoryCommand command =
                updateMemoryUseCase.receivedCommand();

        assertThat(command.placeName().isProvided()).isTrue();
        assertThat(command.placeName().value()).isNull();
    }

    @Test
    void shouldPreserveEmptyOptionalPatchStrings() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "description": "",
                                  "placeName": ""
                                }
                                """))
                .andExpect(status().isOk());

        UpdateMemoryCommand command =
                updateMemoryUseCase.receivedCommand();

        assertThat(command.description().value()).isEmpty();
        assertThat(command.placeName().value()).isEmpty();
    }

    @Test
    void shouldUpdateMemoryLocation() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "latitude": 41.7151,
                                  "longitude": 44.8271
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.latitude").value(41.7151))
                .andExpect(jsonPath("$.longitude").value(44.8271));

        UpdateMemoryCommand command =
                updateMemoryUseCase.receivedCommand();

        assertThat(command.latitude().isProvided()).isTrue();
        assertThat(command.latitude().value()).isEqualTo(41.7151);
        assertThat(command.longitude().isProvided()).isTrue();
        assertThat(command.longitude().value()).isEqualTo(44.8271);
    }

    @Test
    void shouldUpdateMemoryEventDate() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "eventDate": "2035-12-01"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.eventDate").value("2035-12-01"));

        assertThat(updateMemoryUseCase.receivedCommand().eventDate().value())
                .isEqualTo(LocalDate.of(2035, 12, 1));
    }

    @Test
    void shouldUpdateMemoryMultipleFields() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "New",
                                  "description": null,
                                  "latitude": 41.7,
                                  "longitude": 44.8,
                                  "eventDate": "2024-01-01"
                                }
                                """))
                .andExpect(status().isOk());

        UpdateMemoryCommand command =
                updateMemoryUseCase.receivedCommand();

        assertThat(command.title().value()).isEqualTo("New");
        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value()).isNull();
        assertThat(command.placeName().isProvided()).isFalse();
        assertThat(command.latitude().value()).isEqualTo(41.7);
        assertThat(command.longitude().value()).isEqualTo(44.8);
        assertThat(command.eventDate().value())
                .isEqualTo(LocalDate.of(2024, 1, 1));
    }

    @Test
    void shouldIgnoreClientSuppliedServerOwnedFieldsWhenUpdating()
            throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "id": "%s",
                                  "memoryId": "%s",
                                  "storyId": "%s",
                                  "createdBy": "%s",
                                  "createdAt": "2000-01-01T00:00:00Z",
                                  "updatedAt": "2000-01-01T00:00:00Z",
                                  "title": "Updated title"
                                }
                                """.formatted(
                                CLIENT_SUPPLIED_MEMORY_ID,
                                CLIENT_SUPPLIED_MEMORY_ID,
                                CLIENT_SUPPLIED_STORY_ID,
                                CLIENT_SUPPLIED_CREATED_BY
                        )))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(MEMORY_ID.toString()))
                .andExpect(jsonPath("$.storyId").value(STORY_ID.toString()))
                .andExpect(jsonPath("$.createdBy").value(USER_ID.toString()))
                .andExpect(jsonPath("$.updatedAt")
                        .value("2026-01-10T10:00:00Z"));

        UpdateMemoryCommand command =
                updateMemoryUseCase.receivedCommand();

        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnNotFoundWhenMemoryUpdateIsUnavailable()
            throws Exception {

        updateMemoryUseCase.failWith(new MemoryUpdateUnavailableException());

        String response = mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated title"
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
                        .value("Memory could not be updated"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/memories"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(updateMemoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("Updated title")
                .doesNotContain("role")
                .doesNotContain("author")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnBadRequestForEmptyUpdatePatch() throws Exception {
        assertUpdateBadRequest("{}");
    }

    @Test
    void shouldReturnBadRequestForNullUpdateTitle() throws Exception {
        assertUpdateBadRequest("""
                {
                  "title": null
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForBlankUpdateTitle() throws Exception {
        assertUpdateBadRequest("""
                {
                  "title": "   "
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForTooLongUpdateTitle() throws Exception {
        assertUpdateBadRequest("""
                {
                  "title": "%s"
                }
                """.formatted("a".repeat(256)));
    }

    @Test
    void shouldReturnBadRequestForTooLongUpdatePlaceName() throws Exception {
        assertUpdateBadRequest("""
                {
                  "placeName": "%s"
                }
                """.formatted("a".repeat(256)));
    }

    @Test
    void shouldReturnBadRequestForHalfUpdateLocation() throws Exception {
        assertUpdateBadRequest("""
                {
                  "latitude": 41.7
                }
                """);
        assertUpdateBadRequest("""
                {
                  "longitude": 44.8
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForNullUpdateLocationValues()
            throws Exception {
        assertUpdateBadRequest("""
                {
                  "latitude": null,
                  "longitude": 44.8
                }
                """);
        assertUpdateBadRequest("""
                {
                  "latitude": 41.7,
                  "longitude": null
                }
                """);
        assertUpdateBadRequest("""
                {
                  "latitude": null,
                  "longitude": null
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForInvalidUpdateCoordinates()
            throws Exception {
        assertUpdateBadRequest("""
                {
                  "latitude": 91.0,
                  "longitude": 44.8
                }
                """);
        assertUpdateBadRequest("""
                {
                  "latitude": 41.7,
                  "longitude": -181.0
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForNullUpdateEventDate() throws Exception {
        assertUpdateBadRequest("""
                {
                  "eventDate": null
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForMalformedUpdateEventDate()
            throws Exception {
        assertUpdateBadRequest("""
                {
                  "eventDate": "01-12-2035"
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForMalformedPatchMemoryId()
            throws Exception {

        mockMvc.perform(patch("/api/v1/memories/not-a-uuid")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated title"
                                }
                                """))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(updateMemoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectUpdateMemoryWithoutBearerToken() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated title"
                                }
                                """))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(updateMemoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectUpdateMemoryWithInvalidBearerToken() throws Exception {

        String response = mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + INVALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated title"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(updateMemoryUseCase.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
    }

    @Test
    void shouldDeleteMemoryAndReturnNoContent() throws Exception {

        String response = mockMvc.perform(delete(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""))
                .andReturn()
                .getResponse()
                .getContentAsString();

        DeleteMemoryCommand command =
                deleteMemoryUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(deleteMemoryUseCase.callCount()).isEqualTo(1);
        assertThat(createMemoryUseCase.callCount()).isZero();
        assertThat(getStoryMemoriesUseCase.callCount()).isZero();
        assertThat(getMemoryUseCase.callCount()).isZero();
        assertThat(updateMemoryUseCase.callCount()).isZero();
        assertThat(response).isEmpty();
    }

    @Test
    void shouldReturnNotFoundWhenMemoryDeletionIsUnavailable()
            throws Exception {

        deleteMemoryUseCase.failWith(
                new MemoryDeletionUnavailableException()
        );

        String response = mockMvc.perform(delete(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
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
                        .value("Memory could not be deleted"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/memories"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(deleteMemoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("author")
                .doesNotContain("ownerId")
                .doesNotContain("Old city walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("MemoryDeletionUnavailableException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnBadRequestForMalformedMemoryIdWhenDeletingMemory()
            throws Exception {

        mockMvc.perform(delete("/api/v1/memories/not-a-uuid")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(deleteMemoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectDeleteMemoryWithoutBearerToken() throws Exception {

        mockMvc.perform(delete(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(deleteMemoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectDeleteMemoryWithInvalidBearerToken() throws Exception {

        String response = mockMvc.perform(delete(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
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
        assertThat(deleteMemoryUseCase.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
    }

    @Test
    void shouldCreateMemoryFromAuthenticatedUserPathAndRequest()
            throws Exception {

        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isCreated())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_JSON
                        ))
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.storyId").value(STORY_ID.toString()))
                .andExpect(jsonPath("$.createdBy")
                        .value(USER_ID.toString()))
                .andExpect(jsonPath("$.title")
                        .value("First day in Tbilisi"))
                .andExpect(jsonPath("$.description")
                        .value("Old city walk"))
                .andExpect(jsonPath("$.placeName").value("Tbilisi"))
                .andExpect(jsonPath("$.latitude").value(41.6938))
                .andExpect(jsonPath("$.longitude").value(44.8015))
                .andExpect(jsonPath("$.eventDate").value("2024-05-18"))
                .andExpect(jsonPath("$.createdAt")
                        .value("2026-01-10T10:00:00Z"))
                .andExpect(jsonPath("$.updatedAt")
                        .value("2026-01-10T10:00:00Z"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        CreateMemoryCommand command =
                createMemoryUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.memoryId()).isNotNull();
        assertThat(command.title()).isEqualTo("First day in Tbilisi");
        assertThat(command.description()).isEqualTo("Old city walk");
        assertThat(command.placeName()).isEqualTo("Tbilisi");
        assertThat(command.latitude()).isEqualTo(41.6938);
        assertThat(command.longitude()).isEqualTo(44.8015);
        assertThat(command.eventDate()).isEqualTo(EVENT_DATE);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(createMemoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain("ownerId")
                .doesNotContain("role")
                .doesNotContain("googleSubject")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken")
                .doesNotContain("media")
                .doesNotContain("photos");
    }

    @Test
    void shouldPreserveNullableOptionalFields() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Quiet evening",
                                  "latitude": 41.6938,
                                  "longitude": 44.8015,
                                  "eventDate": "2024-05-18"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.description").value((Object) null))
                .andExpect(jsonPath("$.placeName").value((Object) null));

        CreateMemoryCommand command =
                createMemoryUseCase.receivedCommand();
        assertThat(command.description()).isNull();
        assertThat(command.placeName()).isNull();
    }

    @Test
    void shouldIgnoreClientSuppliedServerOwnedFields() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "id": "%s",
                                  "memoryId": "%s",
                                  "storyId": "%s",
                                  "createdBy": "%s",
                                  "createdAt": "2000-01-01T00:00:00Z",
                                  "updatedAt": "2000-01-01T00:00:00Z",
                                  "title": "First day in Tbilisi",
                                  "description": "Old city walk",
                                  "placeName": "Tbilisi",
                                  "latitude": 41.6938,
                                  "longitude": 44.8015,
                                  "eventDate": "2024-05-18"
                                }
                                """.formatted(
                                CLIENT_SUPPLIED_MEMORY_ID,
                                CLIENT_SUPPLIED_MEMORY_ID,
                                CLIENT_SUPPLIED_STORY_ID,
                                CLIENT_SUPPLIED_CREATED_BY
                        )))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.storyId").value(STORY_ID.toString()))
                .andExpect(jsonPath("$.createdBy")
                        .value(USER_ID.toString()))
                .andExpect(jsonPath("$.createdAt")
                        .value("2026-01-10T10:00:00Z"))
                .andExpect(jsonPath("$.updatedAt")
                        .value("2026-01-10T10:00:00Z"));

        CreateMemoryCommand command =
                createMemoryUseCase.receivedCommand();

        assertThat(command.memoryId())
                .isNotEqualTo(CLIENT_SUPPLIED_MEMORY_ID);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnNotFoundWhenMemoryCreationIsUnavailable()
            throws Exception {

        createMemoryUseCase.failWith(
                new MemoryCreationUnavailableException()
        );

        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isNotFound())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_PROBLEM_JSON
                        ))
                .andExpect(jsonPath("$.title").value("Not Found"))
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.detail")
                        .value("Memory could not be created"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/stories/memories"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(createMemoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("MemoryCreationUnavailableException")
                .doesNotContain("stackTrace")
                .doesNotContain("Old city walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryId() throws Exception {

        mockMvc.perform(post("/api/v1/stories/not-a-uuid/memories")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createMemoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryIdWhenListingMemories()
            throws Exception {

        mockMvc.perform(get("/api/v1/stories/not-a-uuid/memories")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(getStoryMemoriesUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedMemoryIdWhenGettingMemory()
            throws Exception {

        mockMvc.perform(get("/api/v1/memories/not-a-uuid")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(getMemoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForBlankTitle() throws Exception {
        assertBadRequest("""
                {
                  "title": "   ",
                  "latitude": 41.6938,
                  "longitude": 44.8015,
                  "eventDate": "2024-05-18"
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForTooLongTitle() throws Exception {
        String title = "a".repeat(256);

        assertBadRequest("""
                {
                  "title": "%s",
                  "latitude": 41.6938,
                  "longitude": 44.8015,
                  "eventDate": "2024-05-18"
                }
                """.formatted(title));
    }

    @Test
    void shouldReturnBadRequestForTooLongPlaceName() throws Exception {
        String placeName = "a".repeat(256);

        assertBadRequest("""
                {
                  "title": "First day in Tbilisi",
                  "placeName": "%s",
                  "latitude": 41.6938,
                  "longitude": 44.8015,
                  "eventDate": "2024-05-18"
                }
                """.formatted(placeName));
    }

    @Test
    void shouldReturnBadRequestForMissingLatitude() throws Exception {
        assertBadRequest("""
                {
                  "title": "First day in Tbilisi",
                  "longitude": 44.8015,
                  "eventDate": "2024-05-18"
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForMissingLongitude() throws Exception {
        assertBadRequest("""
                {
                  "title": "First day in Tbilisi",
                  "latitude": 41.6938,
                  "eventDate": "2024-05-18"
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForLatitudeOutsideRange() throws Exception {
        assertBadRequest("""
                {
                  "title": "First day in Tbilisi",
                  "latitude": 91.0,
                  "longitude": 44.8015,
                  "eventDate": "2024-05-18"
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForLongitudeOutsideRange() throws Exception {
        assertBadRequest("""
                {
                  "title": "First day in Tbilisi",
                  "latitude": 41.6938,
                  "longitude": -181.0,
                  "eventDate": "2024-05-18"
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForMissingEventDate() throws Exception {
        assertBadRequest("""
                {
                  "title": "First day in Tbilisi",
                  "latitude": 41.6938,
                  "longitude": 44.8015
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForMalformedEventDate() throws Exception {
        assertBadRequest("""
                {
                  "title": "First day in Tbilisi",
                  "latitude": 41.6938,
                  "longitude": 44.8015,
                  "eventDate": "18-05-2024"
                }
                """);
    }

    @Test
    void shouldReturnBadRequestForMalformedJson() throws Exception {
        assertBadRequest("""
                {
                  "title": "First day in Tbilisi",
                }
                """);
    }

    @Test
    void shouldAcceptFutureEventDate() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Future plan",
                                  "latitude": 41.6938,
                                  "longitude": 44.8015,
                                  "eventDate": "2027-02-14"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.eventDate").value("2027-02-14"));

        assertThat(createMemoryUseCase.receivedCommand().eventDate())
                .isEqualTo(LocalDate.of(2027, 2, 14));
    }

    @Test
    void shouldRejectRequestWithoutBearerToken() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createMemoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectListMemoriesRequestWithoutBearerToken()
            throws Exception {

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(getStoryMemoriesUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectGetMemoryRequestWithoutBearerToken()
            throws Exception {

        mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(getMemoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectRequestWithInvalidBearerToken() throws Exception {

        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + INVALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createMemoryUseCase.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
    }

    @Test
    void shouldRejectListMemoriesRequestWithInvalidBearerToken()
            throws Exception {

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
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
        assertThat(getStoryMemoriesUseCase.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
    }

    @Test
    void shouldRejectGetMemoryRequestWithInvalidBearerToken()
            throws Exception {

        String response = mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
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
        assertThat(getMemoryUseCase.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
    }

    @Test
    void shouldRejectNullCreateMemoryUseCaseDependency() {

        assertThatThrownBy(() -> new MemoryController(
                null,
                getStoryMemoriesUseCase,
                getMemoryUseCase,
                updateMemoryUseCase,
                deleteMemoryUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("createMemoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullGetStoryMemoriesUseCaseDependency() {

        assertThatThrownBy(() -> new MemoryController(
                createMemoryUseCase,
                null,
                getMemoryUseCase,
                updateMemoryUseCase,
                deleteMemoryUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("getStoryMemoriesUseCase must not be null");
    }

    @Test
    void shouldRejectNullGetMemoryUseCaseDependency() {

        assertThatThrownBy(() -> new MemoryController(
                createMemoryUseCase,
                getStoryMemoriesUseCase,
                null,
                updateMemoryUseCase,
                deleteMemoryUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("getMemoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullUpdateMemoryUseCaseDependency() {

        assertThatThrownBy(() -> new MemoryController(
                createMemoryUseCase,
                getStoryMemoriesUseCase,
                getMemoryUseCase,
                null,
                deleteMemoryUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("updateMemoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullDeleteMemoryUseCaseDependency() {

        assertThatThrownBy(() -> new MemoryController(
                createMemoryUseCase,
                getStoryMemoriesUseCase,
                getMemoryUseCase,
                updateMemoryUseCase,
                null,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("deleteMemoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullCurrentAuthenticatedUserProviderDependency() {

        assertThatThrownBy(() -> new MemoryController(
                createMemoryUseCase,
                getStoryMemoriesUseCase,
                getMemoryUseCase,
                updateMemoryUseCase,
                deleteMemoryUseCase,
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

        assertThatThrownBy(() -> new MemoryController(
                createMemoryUseCase,
                getStoryMemoriesUseCase,
                getMemoryUseCase,
                updateMemoryUseCase,
                deleteMemoryUseCase,
                currentAuthenticatedUserProvider,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    private void assertBadRequest(String request) throws Exception {
        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isBadRequest())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createMemoryUseCase.callCount()).isZero();
        assertThat(getStoryMemoriesUseCase.callCount()).isZero();
        assertThat(getMemoryUseCase.callCount()).isZero();
        assertThat(deleteMemoryUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain("Old city walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("stackTrace");
    }

    private void assertUpdateBadRequest(String request) throws Exception {
        String response = mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isBadRequest())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(createMemoryUseCase.callCount()).isZero();
        assertThat(getStoryMemoriesUseCase.callCount()).isZero();
        assertThat(getMemoryUseCase.callCount()).isZero();
        assertThat(updateMemoryUseCase.callCount()).isZero();
        assertThat(deleteMemoryUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain("Updated title")
                .doesNotContain("Old city walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.7")
                .doesNotContain("44.8")
                .doesNotContain("stackTrace")
                .doesNotContain("UpdateMemoryCommand")
                .doesNotContain("UpdateMemoryRequest");
    }

    private static String validRequest() {
        return """
                {
                  "title": "First day in Tbilisi",
                  "description": "Old city walk",
                  "placeName": "Tbilisi",
                  "latitude": 41.6938,
                  "longitude": 44.8015,
                  "eventDate": "2024-05-18"
                }
                """;
    }

    private static Memory memory(
            UUID id,
            String title,
            String description,
            String placeName,
            LocalDate eventDate
    ) {
        return new Memory(
                id,
                STORY_ID,
                USER_ID,
                title,
                description,
                placeName,
                41.6938,
                44.8015,
                eventDate,
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class MemoryControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(
                    CURRENT_TIME,
                    ZoneOffset.UTC
            );
        }

        @Bean
        FakeCreateMemoryUseCase createMemoryUseCase() {
            return new FakeCreateMemoryUseCase();
        }

        @Bean
        FakeGetStoryMemoriesUseCase getStoryMemoriesUseCase() {
            return new FakeGetStoryMemoriesUseCase();
        }

        @Bean
        FakeGetMemoryUseCase getMemoryUseCase() {
            return new FakeGetMemoryUseCase();
        }

        @Bean
        FakeUpdateMemoryUseCase updateMemoryUseCase() {
            return new FakeUpdateMemoryUseCase();
        }

        @Bean
        FakeDeleteMemoryUseCase deleteMemoryUseCase() {
            return new FakeDeleteMemoryUseCase();
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

    static final class FakeCreateMemoryUseCase
            implements CreateMemoryUseCase {

        private CreateMemoryCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public Memory createMemory(CreateMemoryCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return new Memory(
                    command.memoryId(),
                    command.storyId(),
                    command.authenticatedUser().userId(),
                    command.title(),
                    command.description(),
                    command.placeName(),
                    command.latitude(),
                    command.longitude(),
                    command.eventDate(),
                    command.currentTime(),
                    command.currentTime()
            );
        }

        private CreateMemoryCommand receivedCommand() {
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

    static final class FakeGetStoryMemoriesUseCase
            implements GetStoryMemoriesUseCase {

        private List<Memory> memories = List.of();
        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedStoryId;
        private RuntimeException exception;
        private int callCount;

        @Override
        public List<Memory> getMemories(
                AuthenticatedUser authenticatedUser,
                UUID storyId
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedStoryId = storyId;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return memories;
        }

        private void memories(List<Memory> memories) {
            this.memories = memories;
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

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            memories = List.of();
            receivedAuthenticatedUser = null;
            receivedStoryId = null;
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeGetMemoryUseCase implements GetMemoryUseCase {

        private Memory memory = MemoryControllerTest.memory(
                MEMORY_ID,
                "First day in Tbilisi",
                "Old city walk",
                "Tbilisi",
                EVENT_DATE
        );
        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedMemoryId;
        private RuntimeException exception;
        private int callCount;

        @Override
        public Memory getMemory(
                AuthenticatedUser authenticatedUser,
                UUID memoryId
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedMemoryId = memoryId;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return memory;
        }

        private void memory(Memory memory) {
            this.memory = memory;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private UUID receivedMemoryId() {
            return receivedMemoryId;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            memory = MemoryControllerTest.memory(
                    MEMORY_ID,
                    "First day in Tbilisi",
                    "Old city walk",
                    "Tbilisi",
                    EVENT_DATE
            );
            receivedAuthenticatedUser = null;
            receivedMemoryId = null;
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeUpdateMemoryUseCase
            implements UpdateMemoryUseCase {

        private UpdateMemoryCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public Memory updateMemory(UpdateMemoryCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            String title = command.title().isProvided()
                    ? command.title().value()
                    : "First day in Tbilisi";
            String description = command.description().isProvided()
                    ? command.description().value()
                    : "Old city walk";
            String placeName = command.placeName().isProvided()
                    ? command.placeName().value()
                    : "Tbilisi";
            double latitude = command.latitude().isProvided()
                    ? command.latitude().value()
                    : 41.6938;
            double longitude = command.longitude().isProvided()
                    ? command.longitude().value()
                    : 44.8015;
            LocalDate eventDate = command.eventDate().isProvided()
                    ? command.eventDate().value()
                    : EVENT_DATE;

            return new Memory(
                    command.memoryId(),
                    STORY_ID,
                    USER_ID,
                    title,
                    description,
                    placeName,
                    latitude,
                    longitude,
                    eventDate,
                    CURRENT_TIME,
                    command.currentTime()
            );
        }

        private UpdateMemoryCommand receivedCommand() {
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

    static final class FakeDeleteMemoryUseCase
            implements DeleteMemoryUseCase {

        private DeleteMemoryCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public void deleteMemory(DeleteMemoryCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }
        }

        private DeleteMemoryCommand receivedCommand() {
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
