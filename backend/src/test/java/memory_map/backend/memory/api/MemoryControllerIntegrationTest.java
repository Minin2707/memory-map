package memory_map.backend.memory.api;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Import(MemoryControllerIntegrationTest.MemoryControllerIntegrationTestConfiguration.class)
class MemoryControllerIntegrationTest extends IntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private AccessTokenService accessTokenService;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private MediaFileRepository mediaFileRepository;

    @Autowired
    private TestStorageService storageService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID CLIENT_SUPPLIED_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000099");
    private static final UUID CLIENT_SUPPLIED_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000088");
    private static final UUID CLIENT_SUPPLIED_CREATED_BY =
            UUID.fromString("00000000-0000-0000-0000-000000000077");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID SECOND_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final UUID THIRD_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000023");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final UUID OTHER_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000033");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        storageService.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldListMemoriesForEveryParticipantRole(StoryRole role)
            throws Exception {

        Fixture fixture = authorizedFixture(role);
        Memory second = saveMemory(memory(
                SECOND_MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "Second",
                null,
                null,
                52.520008,
                13.404954,
                LocalDate.of(2024, 5, 19),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        ));
        Memory first = saveMemory(memory(
                MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "First",
                "Old city walk",
                "Tbilisi",
                41.6938,
                44.8015,
                LocalDate.of(2024, 5, 18),
                BASE_TIME,
                BASE_TIME
        ));

        JsonNode response = getStoryMemories(
                validAccessToken(fixture.requester().id()),
                fixture.story().id(),
                200
        );

        assertThat(response.isArray()).isTrue();
        assertThat(response.size()).isEqualTo(2);
        assertMemoryResponseMatches(response.get(0), first);
        assertMemoryResponseMatches(response.get(1), second);
        assertThat(response.get(0).at("/previewPhoto").isNull()).isTrue();
        assertThat(response.get(1).at("/previewPhoto").isNull()).isTrue();
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldGetMemoryForEveryParticipantRole(StoryRole role)
            throws Exception {

        Fixture fixture = authorizedFixture(role);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));

        JsonNode response = getMemory(
                validAccessToken(fixture.requester().id()),
                memory.id(),
                200
        );

        assertMemoryResponseMatches(response, memory);
        assertThat(response.at("/previewPhoto").isNull()).isTrue();
    }

    @Test
    void shouldListMemoriesWithPreviewPhoto() throws Exception {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        saveMediaFile(MEDIA_ID, memory.id());

        JsonNode response = getStoryMemories(
                validAccessToken(fixture.requester().id()),
                fixture.story().id(),
                200
        );

        assertThat(response.get(0).at("/previewPhoto/mediaId").asText())
                .isEqualTo(MEDIA_ID.toString());
        assertThat(response.get(0).at("/previewPhoto/thumbnailUrl").asText())
                .isEqualTo("/api/v1/media/%s/thumbnail".formatted(MEDIA_ID));
        assertThat(response.toString())
                .doesNotContain("displayStorageKey")
                .doesNotContain("thumbnailStorageKey")
                .doesNotContain("storageKey")
                .doesNotContain("display-key")
                .doesNotContain("thumbnail-key")
                .doesNotContain("bucket")
                .doesNotContain("MinIO")
                .doesNotContain("displayUrl");
    }

    @Test
    void shouldGetMemoryWithPreviewPhoto() throws Exception {

        Fixture fixture = authorizedFixture(StoryRole.EDITOR);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        saveMediaFile(MEDIA_ID, memory.id());

        JsonNode response = getMemory(
                validAccessToken(fixture.requester().id()),
                memory.id(),
                200
        );

        assertThat(response.at("/previewPhoto/mediaId").asText())
                .isEqualTo(MEDIA_ID.toString());
        assertThat(response.at("/previewPhoto/thumbnailUrl").asText())
                .isEqualTo("/api/v1/media/%s/thumbnail".formatted(MEDIA_ID));
        assertThat(response.toString())
                .doesNotContain("displayStorageKey")
                .doesNotContain("thumbnailStorageKey")
                .doesNotContain("storageKey")
                .doesNotContain("display-key")
                .doesNotContain("thumbnail-key")
                .doesNotContain("bucket")
                .doesNotContain("MinIO")
                .doesNotContain("displayUrl");
    }

    @Test
    void shouldReturnEmptyArrayForAccessibleStoryWithoutMemories()
            throws Exception {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);

        JsonNode response = getStoryMemories(
                validAccessToken(fixture.requester().id()),
                fixture.story().id(),
                200
        );

        assertThat(response.isArray()).isTrue();
        assertThat(response.size()).isZero();
    }

    @Test
    void shouldListMemoriesInCanonicalOrder() throws Exception {

        Fixture fixture = authorizedFixture(StoryRole.OWNER);
        Memory a = saveMemory(memory(
                THIRD_MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "A",
                "Later event date",
                "Tbilisi",
                41.0,
                44.0,
                LocalDate.of(2020, 1, 2),
                BASE_TIME,
                BASE_TIME
        ));
        Memory b = saveMemory(memory(
                SECOND_MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "B",
                "Same event, later creation",
                "Tbilisi",
                42.0,
                45.0,
                LocalDate.of(2020, 1, 1),
                BASE_TIME.plusSeconds(2),
                BASE_TIME.plusSeconds(2)
        ));
        Memory c = saveMemory(memory(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                fixture.story().id(),
                fixture.owner().id(),
                "C",
                "Same event and creation, later id",
                "Tbilisi",
                43.0,
                46.0,
                LocalDate.of(2020, 1, 1),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        ));
        Memory d = saveMemory(memory(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                fixture.story().id(),
                fixture.owner().id(),
                "D",
                "Same event and creation, earlier id",
                "Tbilisi",
                44.0,
                47.0,
                LocalDate.of(2020, 1, 1),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        ));

        JsonNode response = getStoryMemories(
                validAccessToken(fixture.requester().id()),
                fixture.story().id(),
                200
        );

        assertThat(response.get(0).at("/id").asText())
                .isEqualTo(d.id().toString());
        assertThat(response.get(1).at("/id").asText())
                .isEqualTo(c.id().toString());
        assertThat(response.get(2).at("/id").asText())
                .isEqualTo(b.id().toString());
        assertThat(response.get(3).at("/id").asText())
                .isEqualTo(a.id().toString());
    }

    @Test
    void shouldReturnSafeNotFoundForUnavailableStoryMemories()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode outsiderResponse = getStoryMemories(
                validAccessToken(outsider.id()),
                story.id(),
                404
        );
        JsonNode missingResponse = getStoryMemories(
                validAccessToken(outsider.id()),
                OTHER_STORY_ID,
                404
        );

        assertStoryNotFoundBodyIsSafe(outsiderResponse);
        assertStoryNotFoundBodyIsSafe(missingResponse);
        assertSamePublicProblem(outsiderResponse, missingResponse);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldDenyListForParticipantOfAnotherStory() throws Exception {

        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Target Story");
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                owner.id(),
                "Other Story"
        );
        saveParticipant(otherStory.id(), requester.id(), StoryRole.VIEWER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode response = getStoryMemories(
                validAccessToken(requester.id()),
                story.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldDenyListForOwnerIdWithoutMembership() throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Detached Owner Story");
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode response = getStoryMemories(
                validAccessToken(owner.id()),
                story.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldDenyListForFormerAuthorWithoutMembership() throws Exception {

        User owner = saveUser(OWNER_ID);
        User formerAuthor = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        Memory memory = saveMemory(defaultMemory(
                story.id(),
                formerAuthor.id()
        ));

        JsonNode response = getStoryMemories(
                validAccessToken(formerAuthor.id()),
                story.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldReturnSafeNotFoundForUnavailableMemory()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode outsiderResponse = getMemory(
                validAccessToken(outsider.id()),
                memory.id(),
                404
        );
        JsonNode missingResponse = getMemory(
                validAccessToken(outsider.id()),
                UUID.randomUUID(),
                404
        );

        assertMemoryNotFoundBodyIsSafe(outsiderResponse);
        assertMemoryNotFoundBodyIsSafe(missingResponse);
        assertSamePublicProblem(outsiderResponse, missingResponse);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldDenyGetForParticipantOfAnotherStory() throws Exception {

        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Target Story");
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                owner.id(),
                "Other Story"
        );
        saveParticipant(otherStory.id(), requester.id(), StoryRole.EDITOR);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode response = getMemory(
                validAccessToken(requester.id()),
                memory.id(),
                404
        );

        assertMemoryNotFoundBodyIsSafe(response);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldDenyGetForOwnerIdWithoutMembership() throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Detached Owner Story");
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode response = getMemory(
                validAccessToken(owner.id()),
                memory.id(),
                404
        );

        assertMemoryNotFoundBodyIsSafe(response);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldDenyGetForFormerAuthorWithoutMembership() throws Exception {

        User owner = saveUser(OWNER_ID);
        User formerAuthor = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        Memory memory = saveMemory(defaultMemory(
                story.id(),
                formerAuthor.id()
        ));

        JsonNode response = getMemory(
                validAccessToken(formerAuthor.id()),
                memory.id(),
                404
        );

        assertMemoryNotFoundBodyIsSafe(response);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldReturnExactNullableFieldsForGet() throws Exception {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);
        Memory memory = saveMemory(memory(
                MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "Quiet evening",
                null,
                null,
                52.520008,
                13.404954,
                LocalDate.of(2024, 2, 14),
                BASE_TIME,
                BASE_TIME.plusSeconds(1)
        ));

        JsonNode response = getMemory(
                validAccessToken(fixture.requester().id()),
                memory.id(),
                200
        );

        assertMemoryResponseMatches(response, memory);
        assertThat(response.at("/description").isNull()).isTrue();
        assertThat(response.at("/placeName").isNull()).isTrue();
        assertThat(response.toString())
                .doesNotContain("ownerId")
                .doesNotContain("role")
                .doesNotContain("SRID")
                .doesNotContain("POINT");
    }

    @Test
    void shouldPatchMemoryForOwnerAndPersistAuthoritativeFields()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User author = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), author.id()));

        JsonNode response = patchMemory(
                validAccessToken(owner.id()),
                memory.id(),
                """
                {
                  "title": "Updated memory"
                }
                """,
                200
        );

        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertMemoryResponseMatches(response, persisted);
        assertThat(persisted.id()).isEqualTo(memory.id());
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.createdBy()).isEqualTo(author.id());
        assertThat(persisted.createdAt()).isEqualTo(memory.createdAt());
        assertThat(persisted.title()).isEqualTo("Updated memory");
        assertThat(persisted.description()).isEqualTo(memory.description());
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldPatchMemoryForCoOwnerAndAuthorRoles() throws Exception {

        assertRoleCanPatchMemory(StoryRole.CO_OWNER, false);
        cleanDatabase();
        assertRoleCanPatchMemory(StoryRole.EDITOR, true);
        cleanDatabase();
        assertRoleCanPatchMemory(StoryRole.VIEWER, true);
    }

    @Test
    void shouldReturnSafeNotFoundForNonAuthorEditorAndViewer()
            throws Exception {

        assertDeniedPatchRoleKeepsMemoryUnchanged(StoryRole.EDITOR);
        cleanDatabase();
        assertDeniedPatchRoleKeepsMemoryUnchanged(StoryRole.VIEWER);
    }

    @Test
    void shouldReturnSafeNotFoundForFormerAuthorAndOwnerIdOnly()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User formerAuthor = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        Memory memory = saveMemory(defaultMemory(
                story.id(),
                formerAuthor.id()
        ));

        JsonNode formerAuthorResponse = patchMemory(
                validAccessToken(formerAuthor.id()),
                memory.id(),
                """
                {
                  "title": "Updated memory"
                }
                """,
                404
        );

        assertMemoryUpdateUnavailableBodyIsSafe(formerAuthorResponse);
        assertMemoryUnchanged(memory);

        cleanDatabase();

        User detachedOwner = saveUser(USER_ID);
        Story detachedStory = saveStory(
                STORY_ID,
                detachedOwner.id(),
                "Detached Owner Story"
        );
        Memory detachedMemory = saveMemory(defaultMemory(
                detachedStory.id(),
                detachedOwner.id()
        ));

        JsonNode ownerIdOnlyResponse = patchMemory(
                validAccessToken(detachedOwner.id()),
                detachedMemory.id(),
                """
                {
                  "title": "Updated memory"
                }
                """,
                404
        );

        assertMemoryUpdateUnavailableBodyIsSafe(ownerIdOnlyResponse);
        assertMemoryUnchanged(detachedMemory);
    }

    @Test
    void shouldDistinguishAbsentDescriptionFromExplicitNullThroughDatabase()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        patchMemory(
                validAccessToken(owner.id()),
                memory.id(),
                """
                {
                  "title": "Title changed"
                }
                """,
                200
        );

        Memory afterTitlePatch = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertThat(afterTitlePatch.title()).isEqualTo("Title changed");
        assertThat(afterTitlePatch.description()).isEqualTo("Old city walk");

        JsonNode clearResponse = patchMemory(
                validAccessToken(owner.id()),
                memory.id(),
                """
                {
                  "description": null
                }
                """,
                200
        );

        Memory afterClear = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertThat(clearResponse.at("/description").isNull()).isTrue();
        assertThat(afterClear.description()).isNull();
        assertThat(afterClear.title()).isEqualTo("Title changed");
    }

    @Test
    void shouldPatchLocationAndKeepSrid4326() throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        patchMemory(
                validAccessToken(owner.id()),
                memory.id(),
                """
                {
                  "latitude": 41.7151,
                  "longitude": 44.8271
                }
                """,
                200
        );

        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertThat(persisted.latitude()).isCloseTo(41.7151, within(0.000001));
        assertThat(persisted.longitude()).isCloseTo(44.8271, within(0.000001));
        assertThat(locationSrid(memory.id())).isEqualTo(4326);
    }

    @Test
    void shouldPatchMultipleFieldsWithoutResettingOmittedFields()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode response = patchMemory(
                validAccessToken(owner.id()),
                memory.id(),
                """
                {
                  "title": "Updated memory",
                  "description": "",
                  "placeName": null,
                  "eventDate": "2035-12-01"
                }
                """,
                200
        );

        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertMemoryResponseMatches(response, persisted);
        assertThat(persisted.title()).isEqualTo("Updated memory");
        assertThat(persisted.description()).isEmpty();
        assertThat(persisted.placeName()).isNull();
        assertThat(persisted.latitude()).isCloseTo(
                memory.latitude(),
                within(0.000001)
        );
        assertThat(persisted.longitude()).isCloseTo(
                memory.longitude(),
                within(0.000001)
        );
        assertThat(persisted.eventDate()).isEqualTo(
                LocalDate.of(2035, 12, 1)
        );
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnOkAndKeepUpdatedAtForSameValuePatch()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode response = patchMemory(
                validAccessToken(owner.id()),
                memory.id(),
                """
                {
                  "title": "First day in Tbilisi"
                }
                """,
                200
        );

        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertMemoryResponseMatches(response, memory);
        assertThat(persisted).isEqualTo(memory);
        assertThat(persisted.updatedAt()).isEqualTo(memory.updatedAt());
    }

    @Test
    void shouldReturnBadRequestAndNotMutateMemoryForInvalidPatch()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));
        String accessToken = validAccessToken(owner.id());

        patchMemory(accessToken, memory.id(), "{}", 400);
        assertMemoryUnchanged(memory);

        patchMemory(
                accessToken,
                memory.id(),
                """
                {
                  "latitude": 41.7
                }
                """,
                400
        );
        assertMemoryUnchanged(memory);

        patchMemory(
                accessToken,
                memory.id(),
                """
                {
                  "title": null
                }
                """,
                400
        );
        assertMemoryUnchanged(memory);

        patchMemory(
                accessToken,
                memory.id(),
                """
                {
                  "latitude": 91.0,
                  "longitude": 44.8
                }
                """,
                400
        );
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldRejectPatchMemoryWithoutBearerTokenAndWithInvalidToken()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        memory.id()
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated memory"
                                }
                                """))
                .andExpect(status().isUnauthorized());

        String response = mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        memory.id()
                )
                        .header(HttpHeaders.AUTHORIZATION, "Bearer not-a-jwt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated memory"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response).doesNotContain("not-a-jwt");
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldReturnBadRequestForMalformedPatchMemoryId()
            throws Exception {

        String accessToken = validAccessToken(saveUser(USER_ID).id());

        mockMvc.perform(patch("/api/v1/memories/not-a-uuid")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated memory"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void shouldDeleteMemoryForOwnerAndLeaveStoryParticipantsAndOtherMemory()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User author = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        StoryParticipant authorParticipant = new StoryParticipant(
                story.id(),
                author.id(),
                StoryRole.EDITOR,
                BASE_TIME
        );
        storyParticipantRepository.save(authorParticipant);
        Memory target = saveMemory(defaultMemory(story.id(), author.id()));
        Memory other = saveMemory(memory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                "Second memory",
                "Still here",
                "Kutaisi",
                42.2679,
                42.6946,
                LocalDate.of(2024, 5, 19),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        ));

        JsonNode response = deleteMemory(
                validAccessToken(owner.id()),
                target.id(),
                204
        );

        assertThat(response.size()).isZero();
        assertThat(memoryRepository.findById(target.id())).isEmpty();
        assertThat(memoryRepository.findById(other.id())).contains(other);
        assertThat(storyRepository.findById(story.id())).contains(story);
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .isPresent();
        assertThat(storyParticipantRepository.find(story.id(), author.id()))
                .contains(authorParticipant);
    }

    @Test
    void shouldDeleteMemoryForCoOwnerAndAuthorRoles() throws Exception {

        assertRoleCanDeleteMemory(StoryRole.CO_OWNER, false);
        cleanDatabase();
        assertRoleCanDeleteMemory(StoryRole.EDITOR, true);
        cleanDatabase();
        assertRoleCanDeleteMemory(StoryRole.VIEWER, true);
    }

    @Test
    void shouldReturnSafeNotFoundForNonAuthorEditorAndViewerDelete()
            throws Exception {

        assertDeniedDeleteRoleKeepsMemoryUnchanged(StoryRole.EDITOR);
        cleanDatabase();
        assertDeniedDeleteRoleKeepsMemoryUnchanged(StoryRole.VIEWER);
    }

    @Test
    void shouldReturnSafeNotFoundForUnavailableDeleteCases()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode outsiderResponse = deleteMemory(
                validAccessToken(outsider.id()),
                memory.id(),
                404
        );
        JsonNode missingResponse = deleteMemory(
                validAccessToken(outsider.id()),
                UUID.randomUUID(),
                404
        );

        assertMemoryDeletionUnavailableBodyIsSafe(outsiderResponse);
        assertMemoryDeletionUnavailableBodyIsSafe(missingResponse);
        assertSamePublicProblem(outsiderResponse, missingResponse);
        assertMemoryUnchanged(memory);

        cleanDatabase();

        User detachedOwner = saveUser(USER_ID);
        Story detachedStory = saveStory(
                STORY_ID,
                detachedOwner.id(),
                "Detached Owner Story"
        );
        Memory detachedMemory = saveMemory(defaultMemory(
                detachedStory.id(),
                detachedOwner.id()
        ));

        JsonNode ownerIdOnlyResponse = deleteMemory(
                validAccessToken(detachedOwner.id()),
                detachedMemory.id(),
                404
        );

        assertMemoryDeletionUnavailableBodyIsSafe(ownerIdOnlyResponse);
        assertMemoryUnchanged(detachedMemory);

        cleanDatabase();

        User formerOwner = saveUser(OWNER_ID);
        User formerAuthor = saveUser(USER_ID);
        Story formerStory = saveStory(
                STORY_ID,
                formerOwner.id(),
                "Former Story"
        );
        Memory formerMemory = saveMemory(defaultMemory(
                formerStory.id(),
                formerAuthor.id()
        ));

        JsonNode formerAuthorResponse = deleteMemory(
                validAccessToken(formerAuthor.id()),
                formerMemory.id(),
                404
        );

        assertMemoryDeletionUnavailableBodyIsSafe(formerAuthorResponse);
        assertMemoryUnchanged(formerMemory);
    }

    @Test
    void shouldReturnSafeNotFoundForParticipantOfAnotherStoryDelete()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Target Story");
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                owner.id(),
                "Other Story"
        );
        saveParticipant(otherStory.id(), requester.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode response = deleteMemory(
                validAccessToken(requester.id()),
                memory.id(),
                404
        );

        assertMemoryDeletionUnavailableBodyIsSafe(response);
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldReturnNoContentFirstThenNotFoundForRepeatedDelete()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));
        String accessToken = validAccessToken(owner.id());

        deleteMemory(accessToken, memory.id(), 204);
        JsonNode secondResponse = deleteMemory(accessToken, memory.id(), 404);

        assertMemoryDeletionUnavailableBodyIsSafe(secondResponse);
        assertThat(memoryRepository.findById(memory.id())).isEmpty();
    }

    @Test
    void shouldCascadeDeleteMediaMetadataThroughRestDelete()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory target = saveMemory(defaultMemory(story.id(), owner.id()));
        Memory otherMemory = saveMemory(memory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                "Second memory",
                "Still here",
                "Kutaisi",
                42.2679,
                42.6946,
                LocalDate.of(2024, 5, 19),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        ));
        MediaFile first = saveMediaFile(MEDIA_ID, target.id());
        MediaFile second = saveMediaFile(SECOND_MEDIA_ID, target.id());
        MediaFile other = saveMediaFile(OTHER_MEDIA_ID, otherMemory.id());

        deleteMemory(validAccessToken(owner.id()), target.id(), 204);

        assertThat(memoryRepository.findById(target.id())).isEmpty();
        assertThat(mediaFileRepository.findById(first.id())).isEmpty();
        assertThat(mediaFileRepository.findById(second.id())).isEmpty();
        assertThat(memoryRepository.findById(otherMemory.id()))
                .contains(otherMemory);
        assertThat(mediaFileRepository.findById(other.id()))
                .contains(other);
        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey(first.thumbnailStorageKey()),
                new StorageKey(first.displayStorageKey()),
                new StorageKey(second.thumbnailStorageKey()),
                new StorageKey(second.displayStorageKey())
        );
    }

    @Test
    void shouldRejectDeleteMemoryWithoutBearerTokenAndWithInvalidToken()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        mockMvc.perform(delete(
                        "/api/v1/memories/{memoryId}",
                        memory.id()
                ))
                .andExpect(status().isUnauthorized());

        String response = mockMvc.perform(delete(
                        "/api/v1/memories/{memoryId}",
                        memory.id()
                )
                        .header(HttpHeaders.AUTHORIZATION, "Bearer not-a-jwt"))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response).doesNotContain("not-a-jwt");
        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldReturnBadRequestForMalformedDeleteMemoryId()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        mockMvc.perform(delete("/api/v1/memories/not-a-uuid")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(owner.id())
                        ))
                .andExpect(status().isBadRequest());

        assertMemoryUnchanged(memory);
    }

    @Test
    void shouldAgreeAcrossGetAndListAfterDelete() throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory target = saveMemory(defaultMemory(story.id(), owner.id()));
        Memory other = saveMemory(memory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                "Second memory",
                "Still here",
                "Kutaisi",
                42.2679,
                42.6946,
                LocalDate.of(2024, 5, 19),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        ));
        String accessToken = validAccessToken(owner.id());

        deleteMemory(accessToken, target.id(), 204);
        JsonNode getResponse = getMemory(accessToken, target.id(), 404);
        JsonNode listResponse = getStoryMemories(accessToken, story.id(), 200);

        assertMemoryNotFoundBodyIsSafe(getResponse);
        assertThat(listResponse.isArray()).isTrue();
        assertThat(listResponse.size()).isEqualTo(1);
        assertMemoryResponseMatches(listResponse.get(0), other);
    }

    @Test
    void shouldCreateMemoryForOwnerAndPersistAuthoritativeFields()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        JsonNode response = postMemory(
                validAccessToken(owner.id()),
                story.id(),
                validRequest(),
                201
        );

        UUID memoryId = UUID.fromString(response.at("/id").asText());
        Memory persisted = memoryRepository.findById(memoryId)
                .orElseThrow();

        assertMemoryResponseMatches(response, persisted);
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.createdBy()).isEqualTo(owner.id());
        assertThat(persisted.title()).isEqualTo("First day in Tbilisi");
        assertThat(persisted.description()).isEqualTo("Old city walk");
        assertThat(persisted.placeName()).isEqualTo("Tbilisi");
        assertThat(persisted.latitude()).isCloseTo(41.6938, within(0.000001));
        assertThat(persisted.longitude()).isCloseTo(44.8015, within(0.000001));
        assertThat(persisted.eventDate().toString()).isEqualTo("2024-05-18");
        assertThat(persisted.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
        assertThat(locationSrid(memoryId)).isEqualTo(4326);
        assertThat(memoryCount()).isEqualTo(1);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR"})
    void shouldCreateMemoryForOtherAllowedRoles(StoryRole role)
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User participant = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Shared Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), participant.id(), role);

        JsonNode response = postMemory(
                validAccessToken(participant.id()),
                story.id(),
                validRequest(),
                201
        );

        Memory persisted = memoryRepository.findById(
                UUID.fromString(response.at("/id").asText())
        ).orElseThrow();

        assertThat(persisted.createdBy()).isEqualTo(participant.id());
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(memoryCount()).isEqualTo(1);
    }

    @Test
    void shouldReturnNotFoundForViewerAndCreateNoMemory()
            throws Exception {

        assertDeniedRoleCreatesNoMemory(StoryRole.VIEWER);
    }

    @Test
    void shouldReturnNotFoundForOutsiderAndCreateNoMemory()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        JsonNode response = postMemory(
                validAccessToken(outsider.id()),
                story.id(),
                validRequest(),
                404
        );

        assertMemoryCreationUnavailableBodyIsSafe(response);
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundForMissingStoryAndCreateNoMemory()
            throws Exception {

        User user = saveUser(USER_ID);

        JsonNode response = postMemory(
                validAccessToken(user.id()),
                STORY_ID,
                validRequest(),
                404
        );

        assertMemoryCreationUnavailableBodyIsSafe(response);
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldReturnSameNotFoundForViewerAndMissingStory()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User viewer = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        saveParticipant(story.id(), viewer.id(), StoryRole.VIEWER);

        JsonNode viewerResponse = postMemory(
                validAccessToken(viewer.id()),
                story.id(),
                validRequest(),
                404
        );
        JsonNode missingResponse = postMemory(
                validAccessToken(viewer.id()),
                OTHER_STORY_ID,
                validRequest(),
                404
        );

        assertThat(viewerResponse.at("/title").asText())
                .isEqualTo(missingResponse.at("/title").asText());
        assertThat(viewerResponse.at("/status").asInt())
                .isEqualTo(missingResponse.at("/status").asInt());
        assertThat(viewerResponse.at("/detail").asText())
                .isEqualTo(missingResponse.at("/detail").asText());
        assertMemoryCreationUnavailableBodyIsSafe(viewerResponse);
        assertMemoryCreationUnavailableBodyIsSafe(missingResponse);
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundForParticipantOfAnotherStory()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User user = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Target Story");
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                owner.id(),
                "Other Story"
        );
        saveParticipant(otherStory.id(), user.id(), StoryRole.EDITOR);

        JsonNode response = postMemory(
                validAccessToken(user.id()),
                story.id(),
                validRequest(),
                404
        );

        assertMemoryCreationUnavailableBodyIsSafe(response);
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundForOwnerWithoutMembership()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Detached Owner Story");

        JsonNode response = postMemory(
                validAccessToken(owner.id()),
                story.id(),
                validRequest(),
                404
        );

        assertMemoryCreationUnavailableBodyIsSafe(response);
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldIgnoreClientSuppliedServerOwnedFields()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        JsonNode response = postMemory(
                validAccessToken(owner.id()),
                story.id(),
                """
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
                ),
                201
        );

        UUID memoryId = UUID.fromString(response.at("/id").asText());
        Memory persisted = memoryRepository.findById(memoryId)
                .orElseThrow();

        assertThat(memoryId).isNotEqualTo(CLIENT_SUPPLIED_MEMORY_ID);
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.createdBy()).isEqualTo(owner.id());
        assertThat(persisted.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldCreateMultipleMemoriesForSameStory()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        JsonNode first = postMemory(
                validAccessToken(owner.id()),
                story.id(),
                validRequest(),
                201
        );
        JsonNode second = postMemory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "Second day in Tbilisi",
                  "description": "Riverside walk",
                  "placeName": "Mtkvari",
                  "latitude": 41.7000,
                  "longitude": 44.8100,
                  "eventDate": "2024-05-19"
                }
                """,
                201
        );

        assertThat(first.at("/id").asText())
                .isNotEqualTo(second.at("/id").asText());
        assertThat(memoryCount()).isEqualTo(2);
    }

    @Test
    void shouldReturnBadRequestAndCreateNoMemoryForBlankTitle()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        postMemory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "   ",
                  "latitude": 41.6938,
                  "longitude": 44.8015,
                  "eventDate": "2024-05-18"
                }
                """,
                400
        );

        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestAndCreateNoMemoryForInvalidLatitude()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        postMemory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "First day in Tbilisi",
                  "latitude": 91.0,
                  "longitude": 44.8015,
                  "eventDate": "2024-05-18"
                }
                """,
                400
        );

        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestAndCreateNoMemoryForMissingEventDate()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        postMemory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "First day in Tbilisi",
                  "latitude": 41.6938,
                  "longitude": 44.8015
                }
                """,
                400
        );

        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldAllowFutureEventDate() throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story");
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        JsonNode response = postMemory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "Future plan",
                  "latitude": 41.6938,
                  "longitude": 44.8015,
                  "eventDate": "2027-02-14"
                }
                """,
                201
        );

        assertThat(response.at("/eventDate").asText())
                .isEqualTo("2027-02-14");
        assertThat(memoryCount()).isEqualTo(1);
    }

    @Test
    void shouldRejectCreateMemoryWithoutBearerToken() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isUnauthorized());

        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldRejectCreateMemoryWithInvalidBearerToken()
            throws Exception {

        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response).doesNotContain(invalidToken);
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryIdAndCreateNoMemory()
            throws Exception {

        String accessToken = validAccessToken(saveUser(USER_ID).id());

        mockMvc.perform(post("/api/v1/stories/not-a-uuid/memories")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validRequest()))
                .andExpect(status().isBadRequest());

        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldRejectListAndGetWithoutBearerToken() throws Exception {

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                ))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectListAndGetWithInvalidBearerToken() throws Exception {

        String invalidToken = "not-a-jwt";

        String listResponse = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String getResponse = mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(listResponse).doesNotContain(invalidToken);
        assertThat(getResponse).doesNotContain(invalidToken);
    }

    @Test
    void shouldReturnBadRequestForMalformedReadIds() throws Exception {

        String accessToken = validAccessToken(saveUser(USER_ID).id());

        mockMvc.perform(get("/api/v1/stories/not-a-uuid/memories")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().isBadRequest());

        mockMvc.perform(get("/api/v1/memories/not-a-uuid")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().isBadRequest());

        assertThat(memoryCount()).isZero();
    }

    private void assertDeniedRoleCreatesNoMemory(StoryRole role)
            throws Exception {
        User owner = saveUser(OWNER_ID);
        User participant = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        saveParticipant(story.id(), participant.id(), role);

        JsonNode response = postMemory(
                validAccessToken(participant.id()),
                story.id(),
                validRequest(),
                404
        );

        assertMemoryCreationUnavailableBodyIsSafe(response);
        assertThat(memoryCount()).isZero();
    }

    private void assertRoleCanPatchMemory(
            StoryRole role,
            boolean requesterIsAuthor
    ) throws Exception {
        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        User author = requesterIsAuthor
                ? requester
                : owner;
        Story story = saveStory(STORY_ID, owner.id(), "Shared Story");
        saveParticipant(story.id(), requester.id(), role);
        Memory memory = saveMemory(defaultMemory(story.id(), author.id()));

        JsonNode response = patchMemory(
                validAccessToken(requester.id()),
                memory.id(),
                """
                {
                  "description": "Updated description"
                }
                """,
                200
        );

        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertMemoryResponseMatches(response, persisted);
        assertThat(persisted.description())
                .isEqualTo("Updated description");
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.createdBy()).isEqualTo(author.id());
    }

    private void assertDeniedPatchRoleKeepsMemoryUnchanged(StoryRole role)
            throws Exception {
        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        saveParticipant(story.id(), requester.id(), role);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode deniedResponse = patchMemory(
                validAccessToken(requester.id()),
                memory.id(),
                """
                {
                  "title": "Updated memory"
                }
                """,
                404
        );
        JsonNode missingResponse = patchMemory(
                validAccessToken(requester.id()),
                UUID.randomUUID(),
                """
                {
                  "title": "Updated memory"
                }
                """,
                404
        );

        assertMemoryUpdateUnavailableBodyIsSafe(deniedResponse);
        assertMemoryUpdateUnavailableBodyIsSafe(missingResponse);
        assertSamePublicProblem(deniedResponse, missingResponse);
        assertMemoryUnchanged(memory);
    }

    private void assertRoleCanDeleteMemory(
            StoryRole role,
            boolean requesterIsAuthor
    ) throws Exception {
        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        User author = requesterIsAuthor
                ? requester
                : owner;
        Story story = saveStory(STORY_ID, owner.id(), "Shared Story");
        saveParticipant(story.id(), requester.id(), role);
        Memory memory = saveMemory(defaultMemory(story.id(), author.id()));

        JsonNode response = deleteMemory(
                validAccessToken(requester.id()),
                memory.id(),
                204
        );

        assertThat(response.size()).isZero();
        assertThat(memoryRepository.findById(memory.id())).isEmpty();
    }

    private void assertDeniedDeleteRoleKeepsMemoryUnchanged(StoryRole role)
            throws Exception {
        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Private Story");
        saveParticipant(story.id(), requester.id(), role);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        JsonNode deniedResponse = deleteMemory(
                validAccessToken(requester.id()),
                memory.id(),
                404
        );
        JsonNode missingResponse = deleteMemory(
                validAccessToken(requester.id()),
                UUID.randomUUID(),
                404
        );

        assertMemoryDeletionUnavailableBodyIsSafe(deniedResponse);
        assertMemoryDeletionUnavailableBodyIsSafe(missingResponse);
        assertSamePublicProblem(deniedResponse, missingResponse);
        assertMemoryUnchanged(memory);
    }

    private JsonNode deleteMemory(
            String accessToken,
            UUID memoryId,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(delete(
                        "/api/v1/memories/{memoryId}",
                        memoryId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();

        if (response.isBlank()) {
            return jsonMapper.readTree("{}");
        }

        return jsonMapper.readTree(response);
    }

    private JsonNode patchMemory(
            String accessToken,
            UUID memoryId,
            String request,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(patch(
                        "/api/v1/memories/{memoryId}",
                        memoryId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();

        if (response.isBlank()) {
            return jsonMapper.readTree("{}");
        }

        return jsonMapper.readTree(response);
    }

    private JsonNode postMemory(
            String accessToken,
            UUID storyId,
            String request,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/memories",
                        storyId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();

        if (response.isBlank()) {
            return jsonMapper.readTree("{}");
        }

        return jsonMapper.readTree(response);
    }

    private JsonNode getStoryMemories(
            String accessToken,
            UUID storyId,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/memories",
                        storyId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();

        return jsonMapper.readTree(response);
    }

    private JsonNode getMemory(
            String accessToken,
            UUID memoryId,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}",
                        memoryId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();

        return jsonMapper.readTree(response);
    }

    private Fixture authorizedFixture(StoryRole role) {
        User owner = saveUser(OWNER_ID);
        User requester = role == StoryRole.OWNER
                ? owner
                : saveUser(USER_ID);
        Story story = saveStory(STORY_ID, owner.id(), "Shared Story");
        saveParticipant(story.id(), requester.id(), role);

        return new Fixture(owner, requester, story);
    }

    private User saveUser(UUID userId) {
        return userRepository.save(new User(
                userId,
                "google-subject-" + userId,
                "Memory Map User",
                null,
                BASE_TIME,
                BASE_TIME
        ));
    }

    private Story saveStory(
            UUID storyId,
            UUID ownerId,
            String title
    ) {
        return storyRepository.save(new Story(
                storyId,
                ownerId,
                title,
                "The beginning",
                null,
                BASE_TIME,
                BASE_TIME
        ));
    }

    private void saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role
    ) {
        storyParticipantRepository.save(new StoryParticipant(
                storyId,
                userId,
                role,
                BASE_TIME
        ));
    }

    private Memory saveMemory(Memory memory) {
        memoryRepository.save(memory);
        return memory;
    }

    private MediaFile saveMediaFile(UUID mediaFileId, UUID memoryId) {
        MediaFile mediaFile = new MediaFile(
                mediaFileId,
                memoryId,
                memory_map.backend.media.domain.MediaType.PHOTO,
                "display-key-" + mediaFileId,
                1_024L,
                "thumbnail-key-" + mediaFileId,
                128L,
                "image/jpeg",
                BASE_TIME
        );
        mediaFileRepository.save(mediaFile);

        return mediaFile;
    }

    private static Memory defaultMemory(UUID storyId, UUID createdBy) {
        return memory(
                MEMORY_ID,
                storyId,
                createdBy,
                "First day in Tbilisi",
                "Old city walk",
                "Tbilisi",
                41.6938,
                44.8015,
                LocalDate.of(2024, 5, 18),
                BASE_TIME,
                BASE_TIME
        );
    }

    private static Memory memory(
            UUID id,
            UUID storyId,
            UUID createdBy,
            String title,
            String description,
            String placeName,
            double latitude,
            double longitude,
            LocalDate eventDate,
            Instant createdAt,
            Instant updatedAt
    ) {
        return new Memory(
                id,
                storyId,
                createdBy,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                createdAt,
                updatedAt
        );
    }

    private String validAccessToken(UUID userId) {
        return accessTokenService.issueAccessToken(
                userId,
                Instant.now()
        );
    }

    private int memoryCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM memories
                """)
                .query(Integer.class)
                .single();
    }

    private int locationSrid(UUID memoryId) {
        return jdbcClient.sql("""
                SELECT ST_SRID(location::geometry)
                FROM memories
                WHERE id = :id
                """)
                .param("id", memoryId)
                .query(Integer.class)
                .single();
    }

    private void assertMemoryUnchanged(Memory memory) {
        Memory persisted = memoryRepository.findById(memory.id())
                .orElseThrow();

        assertThat(persisted).isEqualTo(memory);
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

    private static void assertMemoryResponseMatches(
            JsonNode response,
            Memory memory
    ) {
        assertThat(response.at("/id").asText())
                .isEqualTo(memory.id().toString());
        assertThat(response.at("/storyId").asText())
                .isEqualTo(memory.storyId().toString());
        assertThat(response.at("/createdBy").asText())
                .isEqualTo(memory.createdBy().toString());
        assertThat(response.at("/title").asText()).isEqualTo(memory.title());
        if (memory.description() == null) {
            assertThat(response.at("/description").isNull()).isTrue();
        } else {
            assertThat(response.at("/description").asText())
                    .isEqualTo(memory.description());
        }
        if (memory.placeName() == null) {
            assertThat(response.at("/placeName").isNull()).isTrue();
        } else {
            assertThat(response.at("/placeName").asText())
                    .isEqualTo(memory.placeName());
        }
        assertThat(Double.parseDouble(response.at("/latitude").asText()))
                .isCloseTo(memory.latitude(), within(0.000001));
        assertThat(Double.parseDouble(response.at("/longitude").asText()))
                .isCloseTo(memory.longitude(), within(0.000001));
        assertThat(response.at("/eventDate").asText())
                .isEqualTo(memory.eventDate().toString());
        assertThat(response.at("/createdAt").asText())
                .isEqualTo(memory.createdAt().toString());
        assertThat(response.at("/updatedAt").asText())
                .isEqualTo(memory.updatedAt().toString());
    }

    private static void assertSamePublicProblem(
            JsonNode first,
            JsonNode second
    ) {
        assertThat(first.at("/title").asText())
                .isEqualTo(second.at("/title").asText());
        assertThat(first.at("/status").asInt())
                .isEqualTo(second.at("/status").asInt());
        assertThat(first.at("/detail").asText())
                .isEqualTo(second.at("/detail").asText());
        assertThat(first.at("/instance").asText())
                .isEqualTo(second.at("/instance").asText());
    }

    private static void assertStoryNotFoundBodyIsSafe(JsonNode response) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Story was not found");
        assertThat(response.at("/instance").asText())
                .isEqualTo("/api/v1/stories");
        assertReadFailureBodyIsSafe(response);
    }

    private static void assertMemoryNotFoundBodyIsSafe(JsonNode response) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Memory was not found");
        assertThat(response.at("/instance").asText())
                .isEqualTo("/api/v1/memories");
        assertReadFailureBodyIsSafe(response);
    }

    private static void assertReadFailureBodyIsSafe(JsonNode response) {
        assertThat(response.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("Old city walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("MemoryNotFoundException")
                .doesNotContain("StoryNotFoundException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    private static void assertMemoryCreationUnavailableBodyIsSafe(
            JsonNode response
    ) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Memory could not be created");
        assertThat(response.at("/instance").asText())
                .isEqualTo("/api/v1/stories/memories");
        assertThat(response.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("Old city walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("MemoryCreationUnavailableException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    private static void assertMemoryUpdateUnavailableBodyIsSafe(
            JsonNode response
    ) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Memory could not be updated");
        assertThat(response.at("/instance").asText())
                .isEqualTo("/api/v1/memories");
        assertThat(response.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("author")
                .doesNotContain("Old city walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.6938")
                .doesNotContain("44.8015")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("MemoryUpdateUnavailableException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    private static void assertMemoryDeletionUnavailableBodyIsSafe(
            JsonNode response
    ) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Memory could not be deleted");
        assertThat(response.at("/instance").asText())
                .isEqualTo("/api/v1/memories");
        assertThat(response.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
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
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("MemoryDeletionUnavailableException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    private record Fixture(

            User owner,

            User requester,

            Story story

    ) {
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class MemoryControllerIntegrationTestConfiguration {

        @Bean
        @Primary
        Clock fixedClock() {
            return Clock.fixed(
                    CURRENT_TIME,
                    ZoneOffset.UTC
            );
        }

        @Bean
        @Primary
        TestStorageService testStorageService() {
            return new TestStorageService();
        }
    }

    static final class TestStorageService implements StorageService {

        private final List<StorageKey> deletedKeys = new ArrayList<>();

        @Override
        public void store(StorageObjectWrite object) {
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            throw new UnsupportedOperationException();
        }

        @Override
        public StoredObject readRange(
                StorageKey storageKey,
                StorageByteRange range
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(StorageKey storageKey) {
            deletedKeys.add(storageKey);
        }

        private void reset() {
            deletedKeys.clear();
        }
    }
}
