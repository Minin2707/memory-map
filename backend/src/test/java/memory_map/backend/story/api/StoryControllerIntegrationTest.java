package memory_map.backend.story.api;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
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
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
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
