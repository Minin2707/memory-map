package memory_map.backend.invite.api;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.invite.application.InviteProperties;
import memory_map.backend.invite.application.InviteTokenHasher;
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
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.net.URI;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Import(InviteControllerIntegrationTest.InviteControllerIntegrationTestConfiguration.class)
@TestPropertySource(properties = {
        "app.invite.ttl=PT48H",
        "app.invite.base-url=https://test.memorymap.app",
        "app.rate-limit.invite-accept.capacity=1000",
        "app.rate-limit.invite-accept.refill-tokens=1000",
        "app.rate-limit.invite-accept.refill-period=PT1M"
})
class InviteControllerIntegrationTest extends IntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private AccessTokenService accessTokenService;

    @Autowired
    private InviteRepository inviteRepository;

    @Autowired
    private InviteTokenHasher inviteTokenHasher;

    @Autowired
    private InviteProperties inviteProperties;

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
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID CLIENT_SUPPLIED_INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000099");
    private static final UUID CLIENT_SUPPLIED_CREATOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000088");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-02-09T10:00:00.123456Z");
    private static final String RAW_INVITE_TOKEN =
            "share_ACCEPT-token_123";
    private static final String SECOND_RAW_INVITE_TOKEN =
            "share_ACCEPT-token_456";
    private static final String MISSING_RAW_INVITE_TOKEN =
            "missing_ACCEPT-token_123";
    private static final String MALFORMED_RAW_INVITE_TOKEN =
            "not-a-real-invite-token";
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldCreateInviteForOwnerAndPersistHashOnly()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Owner Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        JsonNode response = postInvite(
                validAccessToken(owner.id()),
                story.id(),
                201
        );

        Invite persisted = singleInvite(story.id());
        String rawToken = rawTokenFrom(response.at("/inviteLink").asText());
        String expectedHash = inviteTokenHasher.hash(rawToken);

        assertThat(response.at("/inviteLink").asText())
                .startsWith("https://test.memorymap.app/invite/");
        assertThat(URI.create(response.at("/inviteLink").asText())
                .isAbsolute()).isTrue();
        assertThat(response.at("/expiresAt").asText())
                .isEqualTo("2026-01-12T10:00:00.123456Z");
        assertPublicInviteResponseIsConfidential(response);

        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.createdBy()).isEqualTo(owner.id());
        assertThat(persisted.role()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(persisted.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(persisted.expiresAt())
                .isEqualTo(CURRENT_TIME.plus(inviteProperties.ttl()));
        assertThat(persisted.usedAt()).isNull();
        assertThat(persisted.tokenHash()).isEqualTo(expectedHash);
        assertThat(persisted.tokenHash()).isNotEqualTo(rawToken);
        assertThat(inviteCountByTokenHash(rawToken)).isZero();
    }

    @Test
    void shouldCreateInviteForCoOwner() throws Exception {

        User owner = saveUser(OWNER_ID);
        User coOwner = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Shared Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);

        JsonNode response = postInvite(
                validAccessToken(coOwner.id()),
                story.id(),
                StoryRole.EDITOR,
                201
        );

        Invite persisted = singleInvite(story.id());

        assertThat(response.at("/expiresAt").asText())
                .isEqualTo("2026-01-12T10:00:00.123456Z");
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.createdBy()).isEqualTo(coOwner.id());
        assertThat(persisted.role()).isEqualTo(StoryRole.EDITOR);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {
            "CO_OWNER",
            "EDITOR",
            "VIEWER"
    })
    void shouldAcceptInviteAndCreateParticipantWithInviteRole(
            StoryRole inviteRole
    )
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Accepted Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Invite invite = saveInvite(
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                inviteRole,
                EXPIRES_AT,
                null
        );

        JsonNode response = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                RAW_INVITE_TOKEN,
                200
        );

        StoryParticipant participant = storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        ).orElseThrow();
        Invite consumed = inviteRepository.findById(invite.id())
                .orElseThrow();

        assertThat(response.at("/id").asText())
                .isEqualTo(story.id().toString());
        assertThat(response.at("/title").asText())
                .isEqualTo("Accepted Story");
        assertThat(response.at("/description").asText())
                .isEqualTo("The beginning");
        assertThat(response.at("/role").asText()).isEqualTo(inviteRole.name());
        assertThat(response.at("/createdAt").asText())
                .isEqualTo("2026-01-01T10:00:00.123456Z");
        assertThat(response.at("/updatedAt").asText())
                .isEqualTo("2026-01-01T10:00:00.123456Z");
        assertAcceptInviteResponseIsConfidential(response);
        assertThat(participant).isEqualTo(new StoryParticipant(
                story.id(),
                invitedUser.id(),
                inviteRole,
                CURRENT_TIME
        ));
        assertThat(consumed.role()).isEqualTo(inviteRole);
        assertThat(consumed.usedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnNotFoundForSecondAcceptance() throws Exception {

        User owner = saveUser(OWNER_ID);
        User firstUser = saveUser(USER_ID);
        User secondUser = saveUser(OTHER_USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Accepted Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Invite invite = saveInvite(
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                null
        );

        postAcceptInvite(
                validAccessToken(firstUser.id()),
                RAW_INVITE_TOKEN,
                200
        );
        JsonNode response = postAcceptInvite(
                validAccessToken(secondUser.id()),
                RAW_INVITE_TOKEN,
                404
        );

        assertInviteAcceptanceUnavailableBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(
                story.id(),
                firstUser.id()
        )).isPresent();
        assertThat(storyParticipantRepository.find(
                story.id(),
                secondUser.id()
        )).isEmpty();
        assertThat(inviteRepository.findById(invite.id())
                .orElseThrow()
                .usedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnNotFoundForExpiredInviteAcceptance()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Expired Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Invite invite = saveInvite(
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                CURRENT_TIME.minusMillis(1),
                null
        );

        JsonNode response = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                RAW_INVITE_TOKEN,
                404
        );

        assertInviteAcceptanceUnavailableBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        )).isEmpty();
        assertThat(inviteRepository.findById(invite.id())
                .orElseThrow()
                .usedAt()).isNull();
    }

    @Test
    void shouldReturnNotFoundForUsedInviteAcceptance()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Used Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Invite invite = saveInvite(
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                EXPIRES_AT,
                BASE_TIME.plusSeconds(60)
        );

        JsonNode response = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                RAW_INVITE_TOKEN,
                404
        );

        assertInviteAcceptanceUnavailableBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        )).isEmpty();
        assertThat(inviteRepository.findById(invite.id())
                .orElseThrow()
                .usedAt()).isEqualTo(BASE_TIME.plusSeconds(60));
    }

    @Test
    void shouldReturnNotFoundForNonexistentInviteAcceptance()
            throws Exception {

        User invitedUser = saveUser(USER_ID);

        JsonNode response = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                MISSING_RAW_INVITE_TOKEN,
                404
        );

        assertInviteAcceptanceUnavailableBodyIsSafe(response);
        assertThat(participantCount()).isZero();
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundForMalformedInviteTokenAcceptance()
            throws Exception {

        User invitedUser = saveUser(USER_ID);

        JsonNode response = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                MALFORMED_RAW_INVITE_TOKEN,
                404
        );

        assertInviteAcceptanceUnavailableBodyIsSafe(response);
        assertThat(participantCount()).isZero();
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldRejectAcceptInviteWithoutBearerToken() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/invites/{token}/accept",
                        RAW_INVITE_TOKEN
                ))
                .andExpect(status().isUnauthorized());

        assertThat(participantCount()).isZero();
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldRejectAcceptInviteWithInvalidBearerToken()
            throws Exception {

        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(post(
                        "/api/v1/invites/{token}/accept",
                        RAW_INVITE_TOKEN
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response).doesNotContain(invalidToken);
        assertThat(response).doesNotContain(RAW_INVITE_TOKEN);
        assertThat(participantCount()).isZero();
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldReturnIdenticalPublicNotFoundForAcceptInviteFailures()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User invitedUser = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveInvite(
                story.id(),
                owner.id(),
                RAW_INVITE_TOKEN,
                CURRENT_TIME.minusMillis(1),
                null
        );
        saveInvite(
                story.id(),
                owner.id(),
                SECOND_RAW_INVITE_TOKEN,
                EXPIRES_AT,
                BASE_TIME.plusSeconds(60)
        );

        JsonNode expired = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                RAW_INVITE_TOKEN,
                404
        );
        JsonNode used = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                SECOND_RAW_INVITE_TOKEN,
                404
        );
        JsonNode missing = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                MISSING_RAW_INVITE_TOKEN,
                404
        );
        JsonNode malformed = postAcceptInvite(
                validAccessToken(invitedUser.id()),
                MALFORMED_RAW_INVITE_TOKEN,
                404
        );

        assertThat(used.toString()).isEqualTo(expired.toString());
        assertThat(missing.toString()).isEqualTo(expired.toString());
        assertThat(malformed.toString()).isEqualTo(expired.toString());
        assertInviteAcceptanceUnavailableBodyIsSafe(expired);
        assertThat(storyParticipantRepository.find(
                story.id(),
                invitedUser.id()
        )).isEmpty();
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldReturnNotFoundForRolesThatCannotCreateInvite(StoryRole role)
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User user = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), user.id(), role);

        JsonNode response = postInvite(
                validAccessToken(user.id()),
                story.id(),
                404
        );

        assertInviteUnavailableBodyIsSafe(response);
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForOwnerInviteTargetRole() throws Exception {
        User owner = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Owner Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        JsonNode response = postInvite(
                validAccessToken(owner.id()),
                story.id(),
                StoryRole.OWNER,
                400
        );

        assertInvalidInviteRequestBodyIsSafe(response);
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundWhenStoryDoesNotExist() throws Exception {

        User user = saveUser(USER_ID);

        JsonNode response = postInvite(
                validAccessToken(user.id()),
                STORY_ID,
                404
        );

        assertInviteUnavailableBodyIsSafe(response);
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundWhenUserHasNoMembership()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User user = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        JsonNode response = postInvite(
                validAccessToken(user.id()),
                story.id(),
                404
        );

        assertInviteUnavailableBodyIsSafe(response);
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundForOwnerWithoutMembership()
            throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Owner Without Membership Story"
        );

        JsonNode response = postInvite(
                validAccessToken(owner.id()),
                story.id(),
                404
        );

        assertInviteUnavailableBodyIsSafe(response);
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldReturnSameNotFoundForMissingInaccessibleAndDenied()
            throws Exception {

        User user = saveUser(USER_ID);
        User owner = saveUser(OWNER_ID);
        Story inaccessibleStory = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story"
        );
        Story editorStory = saveStory(
                OTHER_STORY_ID,
                owner.id(),
                "Editor Story"
        );
        saveParticipant(inaccessibleStory.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(editorStory.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(editorStory.id(), user.id(), StoryRole.EDITOR);

        JsonNode missing = postInvite(
                validAccessToken(user.id()),
                UUID.fromString("00000000-0000-0000-0000-000000000077"),
                404
        );
        JsonNode inaccessible = postInvite(
                validAccessToken(user.id()),
                inaccessibleStory.id(),
                404
        );
        JsonNode editor = postInvite(
                validAccessToken(user.id()),
                editorStory.id(),
                404
        );

        assertThat(inaccessible.toString()).isEqualTo(missing.toString());
        assertThat(editor.toString()).isEqualTo(missing.toString());
        assertInviteUnavailableBodyIsSafe(missing);
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryId() throws Exception {

        User user = saveUser(USER_ID);

        String response = mockMvc.perform(post(
                        "/api/v1/stories/not-a-uuid/invites"
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(user.id())
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"role":"CO_OWNER"}
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
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldRejectCreateInviteWithoutBearerToken() throws Exception {

        mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/invites",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldRejectCreateInviteWithInvalidBearerToken()
            throws Exception {

        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/invites",
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

        assertThat(response).doesNotContain(invalidToken);
        assertThat(inviteCount()).isZero();
    }

    @Test
    void shouldIgnoreClientSuppliedInviteFields() throws Exception {

        User owner = saveUser(USER_ID);
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Owner Story"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        postInvite(
                validAccessToken(owner.id()),
                story.id(),
                """
                {
                  "role": "VIEWER",
                  "inviteId": "%s",
                  "storyId": "%s",
                  "createdBy": "%s",
                  "expiresAt": "2099-01-01T00:00:00Z"
                }
                """.formatted(
                        CLIENT_SUPPLIED_INVITE_ID,
                        OTHER_STORY_ID,
                        CLIENT_SUPPLIED_CREATOR_ID
                ),
                201
        );

        Invite persisted = singleInvite(story.id());

        assertThat(persisted.id())
                .isNotEqualTo(CLIENT_SUPPLIED_INVITE_ID);
        assertThat(persisted.storyId()).isEqualTo(story.id());
        assertThat(persisted.createdBy()).isEqualTo(owner.id());
        assertThat(persisted.createdBy())
                .isNotEqualTo(CLIENT_SUPPLIED_CREATOR_ID);
        assertThat(persisted.role()).isEqualTo(StoryRole.VIEWER);
        assertThat(persisted.expiresAt())
                .isEqualTo(CURRENT_TIME.plus(inviteProperties.ttl()));
    }

    private JsonNode postInvite(
            String accessToken,
            UUID storyId,
            int expectedStatus
    ) throws Exception {
        return postInvite(
                accessToken,
                storyId,
                StoryRole.CO_OWNER,
                expectedStatus
        );
    }

    private JsonNode postInvite(
            String accessToken,
            UUID storyId,
            StoryRole role,
            int expectedStatus
    ) throws Exception {
        return postInvite(
                accessToken,
                storyId,
                """
                {"role":"%s"}
                """.formatted(role.name()),
                expectedStatus
        );
    }

    private JsonNode postInvite(
            String accessToken,
            UUID storyId,
            String request,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(post(
                        "/api/v1/stories/{storyId}/invites",
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

    private JsonNode postAcceptInvite(
            String accessToken,
            String rawInviteToken,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(post(
                        "/api/v1/invites/{token}/accept",
                        rawInviteToken
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
            String title
    ) {
        return storyRepository.save(
                new Story(
                        storyId,
                        ownerId,
                        title,
                        "The beginning",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private void saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role
    ) {
        storyParticipantRepository.save(
                new StoryParticipant(
                        storyId,
                        userId,
                        role,
                        BASE_TIME
                )
        );
    }

    private Invite saveInvite(
            UUID storyId,
            UUID createdBy,
            String rawInviteToken,
            Instant expiresAt,
            Instant usedAt
    ) {
        return saveInvite(
                storyId,
                createdBy,
                rawInviteToken,
                StoryRole.CO_OWNER,
                expiresAt,
                usedAt
        );
    }

    private Invite saveInvite(
            UUID storyId,
            UUID createdBy,
            String rawInviteToken,
            StoryRole role,
            Instant expiresAt,
            Instant usedAt
    ) {
        Invite invite = new Invite(
                UUID.randomUUID(),
                storyId,
                role,
                inviteTokenHasher.hash(rawInviteToken),
                createdBy,
                BASE_TIME,
                expiresAt,
                usedAt
        );

        inviteRepository.save(invite);

        return invite;
    }

    private String validAccessToken(UUID userId) {
        return accessTokenService.issueAccessToken(
                userId,
                Instant.now()
        );
    }

    private Invite singleInvite(UUID storyId) {
        List<Invite> invites = inviteRepository.findByStoryId(storyId);

        assertThat(invites).hasSize(1);

        return invites.getFirst();
    }

    private static String rawTokenFrom(String inviteLink) {
        return URI.create(inviteLink)
                .getPath()
                .substring("/invite/".length());
    }

    private int inviteCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM invites
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

    private int inviteCountByTokenHash(String tokenHash) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM invites
                WHERE token_hash = :tokenHash
                """)
                .param("tokenHash", tokenHash)
                .query(Integer.class)
                .single();
    }

    private static void assertPublicInviteResponseIsConfidential(
            JsonNode response
    ) {
        assertThat(response.toString())
                .doesNotContain("inviteId")
                .doesNotContain("storyId")
                .doesNotContain("createdBy")
                .doesNotContain("createdAt")
                .doesNotContain("usedAt")
                .doesNotContain("tokenHash")
                .doesNotContain("rawToken");
    }

    private static void assertAcceptInviteResponseIsConfidential(
            JsonNode response
    ) {
        assertThat(response.toString())
                .doesNotContain(RAW_INVITE_TOKEN)
                .doesNotContain("inviteLink")
                .doesNotContain("expiresAt")
                .doesNotContain("usedAt")
                .doesNotContain("tokenHash")
                .doesNotContain("rawToken")
                .doesNotContain("inviteId")
                .doesNotContain("createdBy");
    }

    private static void assertInviteUnavailableBodyIsSafe(JsonNode response) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Invite could not be created");
        assertThat(response.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(OTHER_STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(OTHER_USER_ID.toString())
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

    private static void assertInviteAcceptanceUnavailableBodyIsSafe(
            JsonNode response
    ) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Invite could not be accepted");
        assertThat(response.toString())
                .doesNotContain(RAW_INVITE_TOKEN)
                .doesNotContain(SECOND_RAW_INVITE_TOKEN)
                .doesNotContain(MISSING_RAW_INVITE_TOKEN)
                .doesNotContain(MALFORMED_RAW_INVITE_TOKEN)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(OTHER_STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(OTHER_USER_ID.toString())
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

    private static void assertInvalidInviteRequestBodyIsSafe(
            JsonNode response
    ) {
        assertThat(response.at("/title").asText())
                .isEqualTo("Bad Request");
        assertThat(response.at("/status").asInt()).isEqualTo(400);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Invalid invite request");
        assertThat(response.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("stackTrace")
                .doesNotContain("tokenHash")
                .doesNotContain("rawToken")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class InviteControllerIntegrationTestConfiguration {

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
