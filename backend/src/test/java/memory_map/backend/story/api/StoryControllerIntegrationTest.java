package memory_map.backend.story.api;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
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
import org.springframework.test.web.servlet.MvcResult;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Import(StoryControllerIntegrationTest.StoryControllerIntegrationTestConfiguration.class)
class StoryControllerIntegrationTest extends IntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private AccessTokenService accessTokenService;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private MediaFileRepository mediaFileRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OWNER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID SHARED_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID FOREIGN_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000013");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID SECOND_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
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
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldCreateStoryThroughHttpAndPersistOwnerParticipant()
            throws Exception {

        User user = saveUser(USER_ID);

        JsonNode response = postStory(
                validAccessToken(user.id()),
                """
                {
                  "title": "Our Story",
                  "description": "The beginning"
                }
                """,
                201
        );

        UUID storyId = UUID.fromString(response.at("/id").asText());
        Story persistedStory = storyRepository.findById(storyId)
                .orElseThrow();
        StoryParticipant persistedParticipant =
                storyParticipantRepository.find(storyId, user.id())
                        .orElseThrow();
        List<StoryParticipant> participants =
                storyParticipantRepository.findByStoryId(storyId);

        assertThat(response.at("/title").asText()).isEqualTo("Our Story");
        assertThat(response.at("/description").asText())
                .isEqualTo("The beginning");
        assertThat(response.at("/createdAt").asText())
                .isEqualTo("2026-01-10T10:00:00.123456Z");
        assertThat(response.at("/updatedAt").asText())
                .isEqualTo("2026-01-10T10:00:00.123456Z");
        assertThat(response.toString())
                .doesNotContain("ownerId")
                .doesNotContain("role")
                .doesNotContain("token")
                .doesNotContain("googleSubject");

        assertThat(persistedStory.id()).isEqualTo(storyId);
        assertThat(persistedStory.ownerId()).isEqualTo(user.id());
        assertThat(persistedStory.title()).isEqualTo("Our Story");
        assertThat(persistedStory.description()).isEqualTo("The beginning");
        assertThat(persistedStory.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(persistedStory.updatedAt()).isEqualTo(CURRENT_TIME);

        assertThat(persistedParticipant.storyId()).isEqualTo(storyId);
        assertThat(persistedParticipant.userId()).isEqualTo(user.id());
        assertThat(persistedParticipant.role()).isEqualTo(StoryRole.OWNER);
        assertThat(persistedParticipant.joinedAt()).isEqualTo(CURRENT_TIME);
        assertThat(participants).hasSize(1);
    }

    @Test
    void shouldUseJwtSubjectAsOwnerAndIgnoreClientOwnerId()
            throws Exception {

        User user = saveUser(USER_ID);

        JsonNode response = postStory(
                validAccessToken(user.id()),
                """
                {
                  "title": "Our Story",
                  "description": "The beginning",
                  "ownerId": "%s"
                }
                """.formatted(OTHER_USER_ID),
                201
        );

        UUID storyId = UUID.fromString(response.at("/id").asText());
        Story persistedStory = storyRepository.findById(storyId)
                .orElseThrow();
        StoryParticipant persistedParticipant =
                storyParticipantRepository.find(storyId, user.id())
                        .orElseThrow();

        assertThat(persistedStory.ownerId()).isEqualTo(user.id());
        assertThat(persistedStory.ownerId()).isNotEqualTo(OTHER_USER_ID);
        assertThat(persistedParticipant.userId()).isEqualTo(user.id());
        assertThat(response.toString()).doesNotContain("ownerId");
    }

    @Test
    void shouldReturnBadRequestAndNotPersistStoryForBlankTitle()
            throws Exception {

        User user = saveUser(USER_ID);

        postStory(
                validAccessToken(user.id()),
                """
                {
                  "title": "   ",
                  "description": "The beginning"
                }
                """,
                400
        );

        assertThat(storyCount()).isZero();
        assertThat(participantCount()).isZero();
    }

    @Test
    void shouldRejectCreateStoryWithoutBearerToken() throws Exception {

        mockMvc.perform(post("/api/v1/stories")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Our Story"
                                }
                                """))
                .andExpect(status().isUnauthorized());

        assertThat(storyCount()).isZero();
        assertThat(participantCount()).isZero();
    }

    @Test
    void shouldRejectCreateStoryWithInvalidBearerToken() throws Exception {

        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(post("/api/v1/stories")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Our Story"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(invalidToken)
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
        assertThat(storyCount()).isZero();
        assertThat(participantCount()).isZero();
    }

    @Test
    void shouldRejectGetStoriesWithoutBearerToken() throws Exception {

        mockMvc.perform(get("/api/v1/stories"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectGetStoriesWithInvalidBearerToken() throws Exception {

        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(get("/api/v1/stories")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(invalidToken)
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    @Test
    void shouldRejectGetStoryWithoutBearerToken() throws Exception {

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}",
                        OWNER_STORY_ID
                ))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectGetStoryWithInvalidBearerToken() throws Exception {

        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}",
                        OWNER_STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(invalidToken)
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    @Test
    void shouldReturnEmptyArrayWhenAuthenticatedUserHasNoStories()
            throws Exception {

        User user = saveUser(USER_ID);

        mockMvc.perform(get("/api/v1/stories")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(user.id())
                        ))
                .andExpect(status().isOk())
                .andExpect(content().string("[]"));
    }

    @Test
    void shouldReturnParticipantBasedStoriesThroughHttp()
            throws Exception {

        User user = saveUser(USER_ID);
        User otherUser = saveUser(OTHER_USER_ID);
        Story ownerStory = saveStory(
                OWNER_STORY_ID,
                user.id(),
                "Owner Story",
                BASE_TIME.plusSeconds(10)
        );
        Story sharedStory = saveStory(
                SHARED_STORY_ID,
                otherUser.id(),
                "Shared Story",
                BASE_TIME.plusSeconds(20)
        );
        Story foreignStory = saveStory(
                FOREIGN_STORY_ID,
                otherUser.id(),
                "Foreign Story",
                BASE_TIME.plusSeconds(30)
        );

        saveParticipant(
                ownerStory.id(),
                user.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(
                sharedStory.id(),
                otherUser.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(2)
        );
        saveParticipant(
                sharedStory.id(),
                user.id(),
                StoryRole.EDITOR,
                BASE_TIME.plusSeconds(3)
        );
        saveParticipant(
                foreignStory.id(),
                otherUser.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(4)
        );

        JsonNode response = getStories(
                validAccessToken(user.id())
        );

        assertThat(response.size()).isEqualTo(2);
        assertThat(response.get(0).at("/id").asText())
                .isEqualTo(ownerStory.id().toString());
        assertThat(response.get(0).at("/title").asText())
                .isEqualTo("Owner Story");
        assertThat(response.get(0).at("/description").asText())
                .isEqualTo("The beginning");
        assertThat(response.get(0).at("/role").asText())
                .isEqualTo("OWNER");
        assertThat(response.get(0).at("/memoryCount").asInt())
                .isZero();
        assertThat(response.get(0).at("/participantCount").asInt())
                .isEqualTo(1);
        assertThat(response.get(0).at("/previewPhoto").isNull()).isTrue();
        assertThat(response.get(1).at("/id").asText())
                .isEqualTo(sharedStory.id().toString());
        assertThat(response.get(1).at("/title").asText())
                .isEqualTo("Shared Story");
        assertThat(response.get(1).at("/role").asText())
                .isEqualTo("EDITOR");
        assertThat(response.get(1).at("/memoryCount").asInt())
                .isZero();
        assertThat(response.get(1).at("/participantCount").asInt())
                .isEqualTo(2);
        assertThat(response.get(1).at("/previewPhoto").isNull()).isTrue();
        assertThat(response.toString())
                .doesNotContain(foreignStory.id().toString())
                .doesNotContain("Foreign Story")
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
    void shouldReturnStorySummaryProjectionThroughHttp() throws Exception {

        User owner = saveUser(USER_ID);
        User coOwner = saveUser(OTHER_USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Projection Story",
                BASE_TIME
        );
        Memory olderMemory = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                LocalDate.parse("2026-01-01"),
                BASE_TIME
        );
        Memory newerMemory = saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                LocalDate.parse("2026-01-02"),
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                coOwner.id(),
                StoryRole.CO_OWNER,
                BASE_TIME.plusSeconds(1)
        );
        saveMedia(
                MEDIA_ID,
                olderMemory.id(),
                memory_map.backend.media.domain.MediaType.PHOTO,
                BASE_TIME.plusSeconds(10)
        );
        saveMedia(
                SECOND_MEDIA_ID,
                newerMemory.id(),
                memory_map.backend.media.domain.MediaType.PHOTO,
                BASE_TIME.plusSeconds(2)
        );

        JsonNode listResponse = getStories(validAccessToken(owner.id()));
        JsonNode singleResponse = getStory(
                validAccessToken(owner.id()),
                story.id(),
                200
        );

        assertThat(listResponse.size()).isEqualTo(1);
        assertStorySummaryProjection(listResponse.get(0));
        assertStorySummaryProjection(singleResponse);
        assertThat(listResponse.get(0)).isEqualTo(singleResponse);
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldReturnStoryByIdForEveryParticipantRole(StoryRole role)
            throws Exception {

        User owner = saveUser(OTHER_USER_ID);
        User user = role == StoryRole.OWNER
                ? owner
                : saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Accessible Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                user.id(),
                role,
                BASE_TIME.plusSeconds(1)
        );

        JsonNode response = getStory(
                validAccessToken(user.id()),
                story.id(),
                200
        );

        assertThat(response.at("/id").asText())
                .isEqualTo(story.id().toString());
        assertThat(response.at("/title").asText())
                .isEqualTo("Accessible Story");
        assertThat(response.at("/description").asText())
                .isEqualTo("The beginning");
        assertThat(response.at("/role").asText())
                .isEqualTo(role.name());
        assertThat(response.at("/createdAt").asText())
                .isEqualTo("2026-01-01T10:00:00.123456Z");
        assertThat(response.at("/updatedAt").asText())
                .isEqualTo("2026-01-01T10:00:00.123456Z");
        assertThat(response.at("/memoryCount").asInt()).isZero();
        assertThat(response.at("/participantCount").asInt()).isEqualTo(1);
        assertThat(response.at("/previewPhoto").isNull()).isTrue();
        assertPublicStoryResponseIsConfidential(response);
    }

    @Test
    void shouldReturnNotFoundWhenStoryDoesNotExist() throws Exception {

        User user = saveUser(USER_ID);

        JsonNode response = getStory(
                validAccessToken(user.id()),
                OWNER_STORY_ID,
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
    }

    @Test
    void shouldReturnSameNotFoundWhenStoryIsInaccessible()
            throws Exception {

        User user = saveUser(USER_ID);
        User otherUser = saveUser(OTHER_USER_ID);
        Story inaccessibleStory = saveStory(
                OWNER_STORY_ID,
                otherUser.id(),
                "Private Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                inaccessibleStory.id(),
                otherUser.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        MvcResult missing = performGetStory(
                validAccessToken(user.id()),
                FOREIGN_STORY_ID,
                404
        );
        MvcResult inaccessible = performGetStory(
                validAccessToken(user.id()),
                inaccessibleStory.id(),
                404
        );

        assertThat(inaccessible.getResponse().getContentType())
                .isEqualTo(missing.getResponse().getContentType());
        assertThat(inaccessible.getResponse().getContentAsString())
                .isEqualTo(missing.getResponse().getContentAsString());

        assertStoryNotFoundBodyIsSafe(
                jsonMapper.readTree(
                        inaccessible.getResponse().getContentAsString()
                )
        );
    }

    @Test
    void shouldReturnNotFoundForOwnerWithoutMembership()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Without Membership Story",
                "The beginning",
                BASE_TIME
        );

        JsonNode response = getStory(
                validAccessToken(owner.id()),
                story.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
    }

    @Test
    void shouldReturnNotFoundForWrongMembershipUser()
            throws Exception {

        User user = saveUser(USER_ID);
        User otherUser = saveUser(OTHER_USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                otherUser.id(),
                "Wrong Membership Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                otherUser.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );

        JsonNode response = getStory(
                validAccessToken(user.id()),
                story.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
    }

    @Test
    void shouldReturnStoryWithNullableDescription() throws Exception {

        User user = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                user.id(),
                "Nullable Description Story",
                null,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                user.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );

        JsonNode response = getStory(
                validAccessToken(user.id()),
                story.id(),
                200
        );

        assertThat(response.at("/description").isNull()).isTrue();
        assertThat(response.at("/role").asText()).isEqualTo("VIEWER");
        assertPublicStoryResponseIsConfidential(response);
    }

    @Test
    void shouldRejectMalformedStoryId() throws Exception {

        User user = saveUser(USER_ID);

        String response = mockMvc.perform(get("/api/v1/stories/not-a-uuid")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(user.id())
                        ))
                .andExpect(status().isBadRequest())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(USER_ID.toString())
                .doesNotContain("google-subject")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken");
    }

    @Test
    void shouldRejectUpdateStoryWithoutBearerToken() throws Exception {

        mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        OWNER_STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story"
                                }
                                """))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectUpdateStoryWithInvalidBearerToken() throws Exception {

        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        OWNER_STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(invalidToken)
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    @Test
    void shouldUpdateStoryTitleThroughHttpForOwner()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        JsonNode response = patchStory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "Updated Story"
                }
                """,
                200
        );
        Story persisted = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(response.at("/id").asText())
                .isEqualTo(story.id().toString());
        assertThat(response.at("/title").asText())
                .isEqualTo("Updated Story");
        assertThat(response.at("/description").asText())
                .isEqualTo("The beginning");
        assertThat(response.at("/role").asText()).isEqualTo("OWNER");
        assertThat(response.at("/updatedAt").asText())
                .isEqualTo("2026-01-10T10:00:00.123456Z");
        assertPublicStoryResponseIsConfidential(response);

        assertThat(persisted.id()).isEqualTo(story.id());
        assertThat(persisted.ownerId()).isEqualTo(owner.id());
        assertThat(persisted.title()).isEqualTo("Updated Story");
        assertThat(persisted.description()).isEqualTo("The beginning");
        assertThat(persisted.createdAt()).isEqualTo(story.createdAt());
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldUpdateStoryDescriptionThroughHttpForCoOwner()
            throws Exception {

        User owner = saveUser(OTHER_USER_ID);
        User coOwner = saveUser(USER_ID);
        Story story = saveStory(
                SHARED_STORY_ID,
                owner.id(),
                "Shared Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                coOwner.id(),
                StoryRole.CO_OWNER,
                BASE_TIME.plusSeconds(1)
        );

        JsonNode response = patchStory(
                validAccessToken(coOwner.id()),
                story.id(),
                """
                {
                  "description": "Updated description"
                }
                """,
                200
        );
        Story persisted = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(response.at("/role").asText()).isEqualTo("CO_OWNER");
        assertThat(persisted.ownerId()).isEqualTo(owner.id());
        assertThat(persisted.title()).isEqualTo("Shared Story");
        assertThat(persisted.description())
                .isEqualTo("Updated description");
    }

    @Test
    void shouldClearStoryDescriptionThroughHttp() throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        JsonNode response = patchStory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "description": null
                }
                """,
                200
        );

        assertThat(response.at("/description").isNull()).isTrue();
        assertThat(storyRepository.findById(story.id())
                .orElseThrow()
                .description())
                .isNull();
    }

    @Test
    void shouldUpdateBothStoryFieldsThroughHttp() throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        patchStory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "Updated Story",
                  "description": "Updated description"
                }
                """,
                200
        );
        Story persisted = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(persisted.title()).isEqualTo("Updated Story");
        assertThat(persisted.description())
                .isEqualTo("Updated description");
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldReturnNotFoundForRolesThatCannotUpdateStoryMetadata(
            StoryRole role
    ) throws Exception {

        User owner = saveUser(OTHER_USER_ID);
        User user = saveUser(USER_ID);
        Story story = saveStory(
                SHARED_STORY_ID,
                owner.id(),
                "Shared Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                user.id(),
                role,
                BASE_TIME.plusSeconds(1)
        );

        JsonNode response = patchStory(
                validAccessToken(user.id()),
                story.id(),
                """
                {
                  "title": "Updated Story"
                }
                """,
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldReturnSameNotFoundForMissingInaccessibleAndDeniedUpdate()
            throws Exception {

        User user = saveUser(USER_ID);
        User otherUser = saveUser(OTHER_USER_ID);
        Story inaccessibleStory = saveStory(
                SHARED_STORY_ID,
                otherUser.id(),
                "Private Story",
                "The beginning",
                BASE_TIME
        );
        Story editorStory = saveStory(
                OWNER_STORY_ID,
                otherUser.id(),
                "Editor Story",
                "The beginning",
                BASE_TIME.plusSeconds(1)
        );
        Story viewerStory = saveStory(
                FOREIGN_STORY_ID,
                otherUser.id(),
                "Viewer Story",
                "The beginning",
                BASE_TIME.plusSeconds(2)
        );
        saveParticipant(
                inaccessibleStory.id(),
                otherUser.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                editorStory.id(),
                otherUser.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                editorStory.id(),
                user.id(),
                StoryRole.EDITOR,
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(
                viewerStory.id(),
                otherUser.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                viewerStory.id(),
                user.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        MvcResult missing = performPatchStory(
                validAccessToken(user.id()),
                UUID.fromString("00000000-0000-0000-0000-000000000099"),
                """
                {
                  "title": "Updated Story"
                }
                """,
                404
        );
        MvcResult inaccessible = performPatchStory(
                validAccessToken(user.id()),
                inaccessibleStory.id(),
                """
                {
                  "title": "Updated Story"
                }
                """,
                404
        );
        MvcResult editor = performPatchStory(
                validAccessToken(user.id()),
                editorStory.id(),
                """
                {
                  "title": "Updated Story"
                }
                """,
                404
        );
        MvcResult viewer = performPatchStory(
                validAccessToken(user.id()),
                viewerStory.id(),
                """
                {
                  "title": "Updated Story"
                }
                """,
                404
        );

        assertThat(inaccessible.getResponse().getContentType())
                .isEqualTo(missing.getResponse().getContentType());
        assertThat(editor.getResponse().getContentType())
                .isEqualTo(missing.getResponse().getContentType());
        assertThat(viewer.getResponse().getContentType())
                .isEqualTo(missing.getResponse().getContentType());
        assertThat(inaccessible.getResponse().getContentAsString())
                .isEqualTo(missing.getResponse().getContentAsString());
        assertThat(editor.getResponse().getContentAsString())
                .isEqualTo(missing.getResponse().getContentAsString());
        assertThat(viewer.getResponse().getContentAsString())
                .isEqualTo(missing.getResponse().getContentAsString());
    }

    @Test
    void shouldReturnNotFoundForOwnerWithoutUpdateMembership()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Without Membership Story",
                "The beginning",
                BASE_TIME
        );

        JsonNode response = patchStory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "Updated Story"
                }
                """,
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldReturnBadRequestForEmptyUpdatePatchAndKeepDbUnchanged()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        patchStory(
                validAccessToken(owner.id()),
                story.id(),
                "{}",
                400
        );

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldReturnBadRequestForNullUpdateTitleAndKeepDbUnchanged()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        patchStory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": null
                }
                """,
                400
        );

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldReturnBadRequestForEmptyUpdateTitleAndKeepDbUnchanged()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        patchStory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": ""
                }
                """,
                400
        );

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldReturnBadRequestForBlankUpdateTitleAndKeepDbUnchanged()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        patchStory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "   "
                }
                """,
                400
        );

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldReturnBadRequestForMalformedUpdateJsonAndKeepDbUnchanged()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                OWNER_STORY_ID,
                owner.id(),
                "Owner Story",
                "The beginning",
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        patchStory(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "title": "Updated Story",
                }
                """,
                400
        );

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldRejectMalformedUpdateStoryId() throws Exception {

        User user = saveUser(USER_ID);

        String response = mockMvc.perform(patch("/api/v1/stories/not-a-uuid")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(user.id())
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated Story"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(USER_ID.toString())
                .doesNotContain("google-subject")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken");
    }

    private JsonNode postStory(
            String accessToken,
            String request,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(post("/api/v1/stories")
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

    private JsonNode getStories(String accessToken) throws Exception {
        String response = mockMvc.perform(get("/api/v1/stories")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return jsonMapper.readTree(response);
    }

    private JsonNode getStory(
            String accessToken,
            UUID storyId,
            int expectedStatus
    ) throws Exception {
        String response = performGetStory(
                accessToken,
                storyId,
                expectedStatus
        ).getResponse().getContentAsString();

        if (response.isBlank()) {
            return jsonMapper.readTree("{}");
        }

        return jsonMapper.readTree(response);
    }

    private JsonNode patchStory(
            String accessToken,
            UUID storyId,
            String request,
            int expectedStatus
    ) throws Exception {
        String response = performPatchStory(
                accessToken,
                storyId,
                request,
                expectedStatus
        ).getResponse().getContentAsString();

        if (response.isBlank()) {
            return jsonMapper.readTree("{}");
        }

        return jsonMapper.readTree(response);
    }

    private MvcResult performGetStory(
            String accessToken,
            UUID storyId,
            int expectedStatus
    ) throws Exception {
        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}",
                        storyId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn();

        if (expectedStatus == 200) {
            assertThat(result.getResponse().getContentType())
                    .contains(MediaType.APPLICATION_JSON_VALUE);
        }

        if (expectedStatus == 404) {
            assertThat(result.getResponse().getContentType())
                    .contains(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        }

        return result;
    }

    private MvcResult performPatchStory(
            String accessToken,
            UUID storyId,
            String request,
            int expectedStatus
    ) throws Exception {
        MvcResult result = mockMvc.perform(patch(
                        "/api/v1/stories/{storyId}",
                        storyId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().is(expectedStatus))
                .andReturn();

        if (expectedStatus == 200) {
            assertThat(result.getResponse().getContentType())
                    .contains(MediaType.APPLICATION_JSON_VALUE);
        }

        if (expectedStatus == 404) {
            assertThat(result.getResponse().getContentType())
                    .contains(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        }

        return result;
    }

    private User saveUser(UUID userId) {
        return userRepository.save(
                new User(
                        userId,
                        "google-subject-" + userId,
                        "Memory Map User",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private Story saveStory(
            UUID storyId,
            UUID ownerId,
            String title,
            Instant currentTime
    ) {
        return saveStory(
                storyId,
                ownerId,
                title,
                "The beginning",
                currentTime
        );
    }

    private Story saveStory(
            UUID storyId,
            UUID ownerId,
            String title,
            String description,
            Instant currentTime
    ) {
        return storyRepository.save(
                new Story(
                        storyId,
                        ownerId,
                        title,
                        description,
                        null,
                        currentTime,
                        currentTime
                )
        );
    }

    private void saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role,
            Instant joinedAt
    ) {
        storyParticipantRepository.save(
                new StoryParticipant(
                        storyId,
                        userId,
                        role,
                        joinedAt
                )
        );
    }

    private Memory saveMemory(
            UUID memoryId,
            UUID storyId,
            UUID createdBy,
            LocalDate eventDate,
            Instant createdAt
    ) {
        Memory memory = new Memory(
                memoryId,
                storyId,
                createdBy,
                "Memory " + memoryId,
                null,
                null,
                55.7558,
                37.6173,
                eventDate,
                createdAt,
                createdAt
        );
        memoryRepository.save(memory);
        return memory;
    }

    private void saveMedia(
            UUID mediaId,
            UUID memoryId,
            memory_map.backend.media.domain.MediaType type,
            Instant createdAt
    ) {
        mediaFileRepository.save(
                new MediaFile(
                        mediaId,
                        memoryId,
                        type,
                        "display-key-" + mediaId,
                        1_024L,
                        "thumbnail-key-" + mediaId,
                        128L,
                        type == memory_map.backend.media.domain.MediaType.PHOTO
                                ? "image/jpeg"
                                : "audio/mpeg",
                        createdAt
                )
        );
    }

    private static void assertStorySummaryProjection(JsonNode response) {
        assertThat(response.at("/id").asText())
                .isEqualTo(OWNER_STORY_ID.toString());
        assertThat(response.at("/title").asText())
                .isEqualTo("Projection Story");
        assertThat(response.at("/memoryCount").asInt()).isEqualTo(2);
        assertThat(response.at("/participantCount").asInt()).isEqualTo(2);
        assertThat(response.at("/previewPhoto/thumbnailUrl").asText())
                .isEqualTo(
                        "/api/v1/media/%s/thumbnail".formatted(SECOND_MEDIA_ID)
                );
        assertThat(response.at("/previewPhoto/displayUrl").asText())
                .isEqualTo(
                        "/api/v1/media/%s/display".formatted(SECOND_MEDIA_ID)
                );
        assertPublicStoryResponseIsConfidential(response);
        assertThat(response.toString())
                .doesNotContain("storageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio");
    }

    private String validAccessToken(UUID userId) {
        return accessTokenService.issueAccessToken(
                userId,
                Instant.now()
        );
    }

    private int storyCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM stories
                """)
                .query(Integer.class)
                .single();
    }

    private int participantCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM story_participants
                """)
                .query(Integer.class)
                .single();
    }

    private static void assertPublicStoryResponseIsConfidential(
            JsonNode response
    ) {
        assertThat(response.toString())
                .doesNotContain("ownerId")
                .doesNotContain("userId")
                .doesNotContain("googleSubject")
                .doesNotContain("joinedAt")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken")
                .doesNotContain("archived")
                .doesNotContain("storageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio");
    }

    private static void assertStoryNotFoundBodyIsSafe(JsonNode response) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Story was not found");
        assertThat(response.at("/instance").asText())
                .isEqualTo("/api/v1/stories");
        assertThat(response.toString())
                .doesNotContain(OWNER_STORY_ID.toString())
                .doesNotContain(FOREIGN_STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OTHER_USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("userId")
                .doesNotContain("googleSubject")
                .doesNotContain("joinedAt")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("StoryNotFoundException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class StoryControllerIntegrationTestConfiguration {

        @Bean
        @Primary
        Clock fixedClock() {
            return Clock.fixed(
                    CURRENT_TIME,
                    ZoneOffset.UTC
            );
        }
    }
}
