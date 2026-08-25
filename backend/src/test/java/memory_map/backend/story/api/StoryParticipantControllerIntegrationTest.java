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
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class StoryParticipantControllerIntegrationTest extends IntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private AccessTokenService accessTokenService;

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
    private static final UUID SECOND_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID THIRD_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID FOURTH_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000005");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID OWNER_WITHOUT_MEMBERSHIP_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000013");
    private static final UUID REPEATED_LEAVE_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000014");
    private static final UUID MISSING_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000099");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldReturnParticipantsForEveryRequesterRole(StoryRole role)
            throws Exception {

        Scenario scenario = saveScenario(role);

        JsonNode response = getParticipants(
                validAccessToken(scenario.requester().id()),
                scenario.story().id(),
                200
        );

        assertThat(response.size())
                .isEqualTo(scenario.expectedParticipantCount());
        assertThat(response.at("/0/userId").asText())
                .isEqualTo(OWNER_ID.toString());
        assertThat(response.at("/0/displayName").asText())
                .isEqualTo("Owner User");
        assertThat(response.at("/0/avatarUrl").asText())
                .isEqualTo("https://example.com/owner.png");
        assertThat(response.at("/0/role").asText()).isEqualTo("OWNER");
        assertThat(response.at("/0/joinedAt").asText())
                .isEqualTo("2026-01-01T10:00:00.123456Z");

        if (role != StoryRole.OWNER) {
            assertThat(response.at("/1/userId").asText())
                    .isEqualTo(scenario.requester().id().toString());
            assertThat(response.at("/1/role").asText())
                    .isEqualTo(role.name());
        }

        assertPublicParticipantResponseIsConfidential(response);
    }

    @Test
    void shouldReturnProjectionWithNullableAvatarAndDeterministicOrdering()
            throws Exception {

        User owner = saveUser(
                OWNER_ID,
                "owner-google-subject",
                "Owner User",
                "https://example.com/owner.png"
        );
        User first = saveUser(
                USER_ID,
                "first-google-subject",
                "First User",
                null
        );
        User second = saveUser(
                SECOND_USER_ID,
                "second-google-subject",
                "Second User",
                null
        );
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(
                story.id(),
                second.id(),
                StoryRole.EDITOR,
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
                first.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        JsonNode response = getParticipants(
                validAccessToken(owner.id()),
                story.id(),
                200
        );

        assertThat(response.size()).isEqualTo(3);
        assertThat(response.at("/0/userId").asText())
                .isEqualTo(owner.id().toString());
        assertThat(response.at("/1/userId").asText())
                .isEqualTo(first.id().toString());
        assertThat(response.at("/2/userId").asText())
                .isEqualTo(second.id().toString());
        assertThat(response.at("/1/avatarUrl").isNull()).isTrue();
        assertThat(response.at("/1/displayName").asText())
                .isEqualTo("First User");
        assertThat(response.at("/1/role").asText()).isEqualTo("VIEWER");
    }

    @Test
    void shouldReturnSameNotFoundWhenStoryIsMissingOrInaccessible()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User outsider = saveUser(USER_ID, "outsider-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        JsonNode inaccessible = getParticipants(
                validAccessToken(outsider.id()),
                story.id(),
                404
        );
        JsonNode missing = getParticipants(
                validAccessToken(outsider.id()),
                MISSING_STORY_ID,
                404
        );

        assertStoryNotFoundBodyIsSafe(inaccessible);
        assertStoryNotFoundBodyIsSafe(missing);
        assertThat(inaccessible.toString()).isEqualTo(missing.toString());
    }

    @Test
    void shouldReturnNotFoundForParticipantOfAnotherStory()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User requester = saveUser(USER_ID, "requester-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, requester.id());
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                otherStory.id(),
                requester.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        JsonNode response = getParticipants(
                validAccessToken(requester.id()),
                story.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
    }

    @Test
    void shouldReturnNotFoundForOwnerWithoutMembership()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User participant = saveUser(USER_ID, "participant-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(
                story.id(),
                participant.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );

        JsonNode response = getParticipants(
                validAccessToken(owner.id()),
                story.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
    }

    @Test
    void shouldRejectRequestWithoutBearerToken() throws Exception {

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectRequestWithInvalidBearerToken() throws Exception {

        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants",
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

        assertThat(response)
                .doesNotContain(invalidToken)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryId() throws Exception {

        User user = saveUser(USER_ID, "current-google-subject");

        String response = mockMvc.perform(get(
                        "/api/v1/stories/not-a-uuid/participants"
                )
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
    void shouldNotMutateStoryParticipants() throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User viewer = saveUser(USER_ID, "viewer-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );
        int countBefore = participantCountByStoryId(story.id());
        List<StoryParticipant> participantsBefore =
                storyParticipantRepository.findByStoryId(story.id());

        getParticipants(validAccessToken(owner.id()), story.id(), 200);

        assertThat(participantCountByStoryId(story.id()))
                .isEqualTo(countBefore);
        assertThat(storyParticipantRepository.findByStoryId(story.id()))
                .containsExactlyElementsOf(participantsBefore);
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR", "VIEWER"})
    void shouldLeaveStoryForNonOwnerRoles(StoryRole role) throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User requester = saveUser(USER_ID, "requester-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant ownerParticipant = saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                requester.id(),
                role,
                BASE_TIME.plusSeconds(1)
        );

        MvcResult result = deleteParticipant(
                validAccessToken(requester.id()),
                story.id(),
                204
        );

        assertThat(result.getResponse().getContentAsString()).isEmpty();
        assertThat(result.getResponse().getContentType()).isNull();
        assertThat(storyParticipantRepository.find(
                story.id(),
                requester.id()
        )).isEmpty();
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .contains(ownerParticipant);
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @Test
    void shouldLeaveStoryForOriginalCreatorWhenAnotherOwnerExists()
            throws Exception {

        User creator = saveUser(OWNER_ID, "creator-google-subject");
        User otherOwner = saveUser(USER_ID, "other-owner-google-subject");
        Story story = saveStory(STORY_ID, creator.id());
        saveParticipant(
                story.id(),
                creator.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        StoryParticipant remainingOwner = saveParticipant(
                story.id(),
                otherOwner.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(1)
        );

        deleteParticipant(validAccessToken(creator.id()), story.id(), 204);

        Story persistedStory = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(storyParticipantRepository.find(
                story.id(),
                creator.id()
        )).isEmpty();
        assertThat(storyParticipantRepository.find(
                story.id(),
                otherOwner.id()
        )).contains(remainingOwner);
        assertThat(countOwners(story.id())).isEqualTo(1);
        assertThat(persistedStory).isEqualTo(story);
        assertThat(persistedStory.ownerId()).isEqualTo(creator.id());
    }

    @Test
    void shouldReturnConflictWhenLastOwnerLeaves() throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant ownerParticipant = saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        int participantCountBefore = participantCountByStoryId(story.id());

        JsonNode response = deleteParticipantBody(
                validAccessToken(owner.id()),
                story.id(),
                409
        );

        assertLastOwnerConflictBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .contains(ownerParticipant);
        assertThat(participantCountByStoryId(story.id()))
                .isEqualTo(participantCountBefore);
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @Test
    void shouldReturnConflictWhenOnlyCoOwnerWouldRemainAndNotPromote()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(USER_ID, "co-owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant ownerParticipant = saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        StoryParticipant coOwnerParticipant = saveParticipant(
                story.id(),
                coOwner.id(),
                StoryRole.CO_OWNER,
                BASE_TIME.plusSeconds(1)
        );

        JsonNode response = deleteParticipantBody(
                validAccessToken(owner.id()),
                story.id(),
                409
        );

        assertLastOwnerConflictBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .contains(ownerParticipant);
        assertThat(storyParticipantRepository.find(story.id(), coOwner.id()))
                .contains(coOwnerParticipant);
        assertThat(countOwners(story.id())).isEqualTo(1);
    }

    @Test
    void shouldReturnSameNotFoundForLeaveUnavailableCases()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User outsider = saveUser(USER_ID, "outsider-google-subject");
        User anotherStoryParticipant = saveUser(
                SECOND_USER_ID,
                "another-story-participant-google-subject"
        );
        User ownerWithoutMembership = saveUser(
                THIRD_USER_ID,
                "owner-without-membership-google-subject"
        );
        User repeatedLeaveUser = saveUser(
                FOURTH_USER_ID,
                "repeated-leave-google-subject"
        );
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                anotherStoryParticipant.id()
        );
        Story ownerWithoutMembershipStory = saveStory(
                OWNER_WITHOUT_MEMBERSHIP_STORY_ID,
                ownerWithoutMembership.id()
        );
        Story repeatedLeaveStory = saveStory(
                REPEATED_LEAVE_STORY_ID,
                owner.id()
        );
        StoryParticipant ownerParticipant = saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        StoryParticipant anotherStoryMembership = saveParticipant(
                otherStory.id(),
                anotherStoryParticipant.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        StoryParticipant repeatedStoryOwner = saveParticipant(
                repeatedLeaveStory.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                repeatedLeaveStory.id(),
                repeatedLeaveUser.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        deleteParticipant(
                validAccessToken(repeatedLeaveUser.id()),
                repeatedLeaveStory.id(),
                204
        );

        JsonNode missing = deleteParticipantBody(
                validAccessToken(outsider.id()),
                MISSING_STORY_ID,
                404
        );
        JsonNode outsiderResponse = deleteParticipantBody(
                validAccessToken(outsider.id()),
                story.id(),
                404
        );
        JsonNode anotherStoryResponse = deleteParticipantBody(
                validAccessToken(anotherStoryParticipant.id()),
                story.id(),
                404
        );
        JsonNode ownerWithoutMembershipResponse = deleteParticipantBody(
                validAccessToken(ownerWithoutMembership.id()),
                ownerWithoutMembershipStory.id(),
                404
        );
        JsonNode repeatedLeaveResponse = deleteParticipantBody(
                validAccessToken(repeatedLeaveUser.id()),
                repeatedLeaveStory.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(missing);
        assertThat(outsiderResponse.toString()).isEqualTo(missing.toString());
        assertThat(anotherStoryResponse.toString())
                .isEqualTo(missing.toString());
        assertThat(ownerWithoutMembershipResponse.toString())
                .isEqualTo(missing.toString());
        assertThat(repeatedLeaveResponse.toString())
                .isEqualTo(missing.toString());
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .contains(ownerParticipant);
        assertThat(storyParticipantRepository.find(
                otherStory.id(),
                anotherStoryParticipant.id()
        )).contains(anotherStoryMembership);
        assertThat(storyParticipantRepository.find(
                repeatedLeaveStory.id(),
                owner.id()
        )).contains(repeatedStoryOwner);
        assertThat(storyRepository.findById(story.id())).contains(story);
        assertThat(storyRepository.findById(ownerWithoutMembershipStory.id()))
                .contains(ownerWithoutMembershipStory);
    }

    @Test
    void shouldRejectLeaveRequestWithoutBearerToken() throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User viewer = saveUser(USER_ID, "viewer-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant viewerParticipant = saveParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
                        story.id()
                ))
                .andExpect(status().isUnauthorized());

        assertThat(storyParticipantRepository.find(story.id(), viewer.id()))
                .contains(viewerParticipant);
    }

    @Test
    void shouldRejectLeaveRequestWithInvalidBearerToken() throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User viewer = saveUser(USER_ID, "viewer-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant viewerParticipant = saveParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );
        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
                        story.id()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(storyParticipantRepository.find(story.id(), viewer.id()))
                .contains(viewerParticipant);
        assertThat(response)
                .doesNotContain(invalidToken)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryIdWhenLeaving()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User viewer = saveUser(USER_ID, "viewer-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        StoryParticipant viewerParticipant = saveParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/not-a-uuid/participants/me"
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(viewer.id())
                        ))
                .andExpect(status().isBadRequest())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(storyParticipantRepository.find(story.id(), viewer.id()))
                .contains(viewerParticipant);
        assertThat(response)
                .doesNotContain(USER_ID.toString())
                .doesNotContain("google-subject")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken");
    }

    @Test
    void shouldReturnUpdatedParticipantsAfterLeave() throws Exception {

        User owner = saveUser(
                OWNER_ID,
                "owner-google-subject",
                "Owner User",
                null
        );
        User viewer = saveUser(
                USER_ID,
                "viewer-google-subject",
                "Viewer User",
                null
        );
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        saveParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        deleteParticipant(validAccessToken(viewer.id()), story.id(), 204);

        JsonNode response = getParticipants(
                validAccessToken(owner.id()),
                story.id(),
                200
        );

        assertThat(response.size()).isEqualTo(1);
        assertThat(response.at("/0/userId").asText())
                .isEqualTo(owner.id().toString());
        assertThat(response.toString())
                .doesNotContain(viewer.id().toString())
                .doesNotContain("Viewer User");
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR", "VIEWER"})
    void shouldRemoveNonOwnerTargetWhenActorIsOwner(StoryRole targetRole)
            throws Exception {

        User actor = saveUser(OWNER_ID, "actor-google-subject");
        User target = saveUser(USER_ID, "target-google-subject");
        User other = saveUser(SECOND_USER_ID, "other-google-subject");
        Story story = saveStory(STORY_ID, actor.id());
        StoryParticipant actorParticipant = saveParticipant(
                story.id(),
                actor.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        StoryParticipant otherParticipant = saveParticipant(
                story.id(),
                other.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(2)
        );
        saveParticipant(
                story.id(),
                target.id(),
                targetRole,
                BASE_TIME.plusSeconds(1)
        );

        MvcResult result = removeParticipant(
                validAccessToken(actor.id()),
                story.id(),
                target.id(),
                204
        );

        assertThat(result.getResponse().getContentAsString()).isEmpty();
        assertThat(result.getResponse().getContentType()).isNull();
        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .isEmpty();
        assertThat(storyParticipantRepository.find(story.id(), actor.id()))
                .contains(actorParticipant);
        assertThat(storyParticipantRepository.find(story.id(), other.id()))
                .contains(otherParticipant);
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR", "VIEWER"})
    void shouldReturnSafeNotFoundWhenActorIsNotOwner(StoryRole actorRole)
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User actor = saveUser(USER_ID, "actor-google-subject");
        User target = saveUser(SECOND_USER_ID, "target-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER, BASE_TIME);
        StoryParticipant actorParticipant = saveParticipant(
                story.id(),
                actor.id(),
                actorRole,
                BASE_TIME.plusSeconds(1)
        );
        StoryParticipant targetParticipant = saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(2)
        );

        JsonNode response = removeParticipantBody(
                validAccessToken(actor.id()),
                story.id(),
                target.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(story.id(), actor.id()))
                .contains(actorParticipant);
        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .contains(targetParticipant);
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @Test
    void shouldReturnSameNotFoundForRemoveUnavailableCases()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User outsider = saveUser(USER_ID, "outsider-google-subject");
        User anotherStoryParticipant = saveUser(
                SECOND_USER_ID,
                "another-story-participant-google-subject"
        );
        User ownerWithoutMembership = saveUser(
                THIRD_USER_ID,
                "owner-without-membership-google-subject"
        );
        User target = saveUser(FOURTH_USER_ID, "target-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                anotherStoryParticipant.id()
        );
        Story ownerWithoutMembershipStory = saveStory(
                OWNER_WITHOUT_MEMBERSHIP_STORY_ID,
                ownerWithoutMembership.id()
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER, BASE_TIME);
        StoryParticipant targetParticipant = saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );
        StoryParticipant anotherStoryMembership = saveParticipant(
                otherStory.id(),
                anotherStoryParticipant.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        JsonNode missing = removeParticipantBody(
                validAccessToken(owner.id()),
                MISSING_STORY_ID,
                target.id(),
                404
        );
        JsonNode outsiderResponse = removeParticipantBody(
                validAccessToken(outsider.id()),
                story.id(),
                target.id(),
                404
        );
        JsonNode anotherStoryResponse = removeParticipantBody(
                validAccessToken(anotherStoryParticipant.id()),
                story.id(),
                target.id(),
                404
        );
        JsonNode ownerWithoutMembershipResponse = removeParticipantBody(
                validAccessToken(ownerWithoutMembership.id()),
                ownerWithoutMembershipStory.id(),
                target.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(missing);
        assertThat(outsiderResponse.toString()).isEqualTo(missing.toString());
        assertThat(anotherStoryResponse.toString())
                .isEqualTo(missing.toString());
        assertThat(ownerWithoutMembershipResponse.toString())
                .isEqualTo(missing.toString());
        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .contains(targetParticipant);
        assertThat(storyParticipantRepository.find(
                otherStory.id(),
                anotherStoryParticipant.id()
        )).contains(anotherStoryMembership);
        assertThat(storyRepository.findById(story.id())).contains(story);
        assertThat(storyRepository.findById(ownerWithoutMembershipStory.id()))
                .contains(ownerWithoutMembershipStory);
    }

    @Test
    void shouldReturnConflictWhenOwnerTargetsSelfThroughRemove()
            throws Exception {

        User actor = saveUser(OWNER_ID, "actor-google-subject");
        Story story = saveStory(STORY_ID, actor.id());
        StoryParticipant actorParticipant = saveParticipant(
                story.id(),
                actor.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        JsonNode response = removeParticipantBody(
                validAccessToken(actor.id()),
                story.id(),
                actor.id(),
                409
        );

        assertRemoveSelfConflictBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(story.id(), actor.id()))
                .contains(actorParticipant);
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @Test
    void shouldReturnSafeNotFoundWhenRemoveTargetIsMissingOrRepeated()
            throws Exception {

        User actor = saveUser(OWNER_ID, "actor-google-subject");
        User target = saveUser(USER_ID, "target-google-subject");
        User otherStoryTarget = saveUser(
                SECOND_USER_ID,
                "other-story-target-google-subject"
        );
        Story story = saveStory(STORY_ID, actor.id());
        Story otherStory = saveStory(OTHER_STORY_ID, actor.id());
        saveParticipant(story.id(), actor.id(), StoryRole.OWNER, BASE_TIME);
        saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );
        StoryParticipant otherStoryTargetParticipant = saveParticipant(
                otherStory.id(),
                otherStoryTarget.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(2)
        );

        removeParticipant(
                validAccessToken(actor.id()),
                story.id(),
                target.id(),
                204
        );

        JsonNode repeated = removeParticipantBody(
                validAccessToken(actor.id()),
                story.id(),
                target.id(),
                404
        );
        JsonNode randomTarget = removeParticipantBody(
                validAccessToken(actor.id()),
                story.id(),
                THIRD_USER_ID,
                404
        );
        JsonNode targetInAnotherStory = removeParticipantBody(
                validAccessToken(actor.id()),
                story.id(),
                otherStoryTarget.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(repeated);
        assertThat(randomTarget.toString()).isEqualTo(repeated.toString());
        assertThat(targetInAnotherStory.toString())
                .isEqualTo(repeated.toString());
        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .isEmpty();
        assertThat(storyParticipantRepository.find(story.id(), actor.id()))
                .isPresent();
        assertThat(storyParticipantRepository.find(
                otherStory.id(),
                otherStoryTarget.id()
        )).contains(otherStoryTargetParticipant);
    }

    @Test
    void shouldReturnConflictWhenRemoveTargetIsOwnerRole()
            throws Exception {

        User actor = saveUser(OWNER_ID, "actor-google-subject");
        User target = saveUser(USER_ID, "target-google-subject");
        User otherOwner = saveUser(SECOND_USER_ID, "other-owner-google-subject");
        Story story = saveStory(STORY_ID, actor.id());
        StoryParticipant actorParticipant = saveParticipant(
                story.id(),
                actor.id(),
                StoryRole.OWNER,
                BASE_TIME
        );
        StoryParticipant targetParticipant = saveParticipant(
                story.id(),
                target.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(1)
        );
        StoryParticipant otherOwnerParticipant = saveParticipant(
                story.id(),
                otherOwner.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(2)
        );

        JsonNode response = removeParticipantBody(
                validAccessToken(actor.id()),
                story.id(),
                target.id(),
                409
        );

        assertRemoveOwnerConflictBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(story.id(), actor.id()))
                .contains(actorParticipant);
        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .contains(targetParticipant);
        assertThat(storyParticipantRepository.find(
                story.id(),
                otherOwner.id()
        )).contains(otherOwnerParticipant);
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @Test
    void shouldApplyOwnerIdEdgeCasesThroughRemoveEndpoint()
            throws Exception {

        User creatorTarget = saveUser(USER_ID, "creator-target-google-subject");
        User actor = saveUser(OWNER_ID, "actor-google-subject");
        Story story = saveStory(STORY_ID, creatorTarget.id());
        saveParticipant(story.id(), actor.id(), StoryRole.OWNER, BASE_TIME);
        saveParticipant(
                story.id(),
                creatorTarget.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        removeParticipant(
                validAccessToken(actor.id()),
                story.id(),
                creatorTarget.id(),
                204
        );

        Story persistedStory = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(storyParticipantRepository.find(
                story.id(),
                creatorTarget.id()
        )).isEmpty();
        assertThat(storyParticipantRepository.find(story.id(), actor.id()))
                .isPresent();
        assertThat(persistedStory).isEqualTo(story);
        assertThat(persistedStory.ownerId()).isEqualTo(creatorTarget.id());
    }

    @Test
    void shouldReturnSafeNotFoundWhenActorIsOwnerIdButNotOwnerRole()
            throws Exception {

        User actor = saveUser(OWNER_ID, "actor-google-subject");
        User target = saveUser(USER_ID, "target-google-subject");
        Story story = saveStory(STORY_ID, actor.id());
        StoryParticipant actorParticipant = saveParticipant(
                story.id(),
                actor.id(),
                StoryRole.CO_OWNER,
                BASE_TIME
        );
        StoryParticipant targetParticipant = saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        JsonNode response = removeParticipantBody(
                validAccessToken(actor.id()),
                story.id(),
                target.id(),
                404
        );

        assertStoryNotFoundBodyIsSafe(response);
        assertThat(storyParticipantRepository.find(story.id(), actor.id()))
                .contains(actorParticipant);
        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .contains(targetParticipant);
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @Test
    void shouldReturnUpdatedParticipantsAfterRemove() throws Exception {

        User actor = saveUser(
                OWNER_ID,
                "actor-google-subject",
                "Actor User",
                null
        );
        User target = saveUser(
                USER_ID,
                "target-google-subject",
                "Target User",
                null
        );
        Story story = saveStory(STORY_ID, actor.id());
        saveParticipant(story.id(), actor.id(), StoryRole.OWNER, BASE_TIME);
        saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        removeParticipant(
                validAccessToken(actor.id()),
                story.id(),
                target.id(),
                204
        );

        JsonNode response = getParticipants(
                validAccessToken(actor.id()),
                story.id(),
                200
        );

        assertThat(response.size()).isEqualTo(1);
        assertThat(response.at("/0/userId").asText())
                .isEqualTo(actor.id().toString());
        assertThat(response.toString())
                .doesNotContain(target.id().toString())
                .doesNotContain("Target User");
    }

    @Test
    void shouldKeepParticipantsMeRouteOnLeaveEndpoint()
            throws Exception {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User viewer = saveUser(USER_ID, "viewer-google-subject");
        User target = saveUser(SECOND_USER_ID, "target-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER, BASE_TIME);
        saveParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );
        StoryParticipant targetParticipant = saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(2)
        );

        deleteParticipant(validAccessToken(viewer.id()), story.id(), 204);

        assertThat(storyParticipantRepository.find(story.id(), viewer.id()))
                .isEmpty();
        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .contains(targetParticipant);
    }

    @Test
    void shouldRejectRemoveRequestWithoutBearerToken() throws Exception {

        User actor = saveUser(OWNER_ID, "actor-google-subject");
        User target = saveUser(USER_ID, "target-google-subject");
        Story story = saveStory(STORY_ID, actor.id());
        saveParticipant(story.id(), actor.id(), StoryRole.OWNER, BASE_TIME);
        StoryParticipant targetParticipant = saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        story.id(),
                        target.id()
                ))
                .andExpect(status().isUnauthorized());

        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .contains(targetParticipant);
    }

    @Test
    void shouldRejectRemoveRequestWithInvalidBearerToken() throws Exception {

        User actor = saveUser(OWNER_ID, "actor-google-subject");
        User target = saveUser(USER_ID, "target-google-subject");
        Story story = saveStory(STORY_ID, actor.id());
        saveParticipant(story.id(), actor.id(), StoryRole.OWNER, BASE_TIME);
        StoryParticipant targetParticipant = saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );
        String invalidToken = "not-a-jwt";

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        story.id(),
                        target.id()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + invalidToken
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .contains(targetParticipant);
        assertThat(response)
                .doesNotContain(invalidToken)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    @Test
    void shouldReturnBadRequestForMalformedRemovePath()
            throws Exception {

        User actor = saveUser(OWNER_ID, "actor-google-subject");
        User target = saveUser(USER_ID, "target-google-subject");
        Story story = saveStory(STORY_ID, actor.id());
        saveParticipant(story.id(), actor.id(), StoryRole.OWNER, BASE_TIME);
        StoryParticipant targetParticipant = saveParticipant(
                story.id(),
                target.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );

        String malformedStoryResponse = mockMvc.perform(delete(
                        "/api/v1/stories/not-a-uuid/participants/{participantUserId}",
                        target.id()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(actor.id())
                        ))
                .andExpect(status().isBadRequest())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String malformedTargetResponse = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/not-a-uuid",
                        story.id()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(actor.id())
                        ))
                .andExpect(status().isBadRequest())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(storyParticipantRepository.find(story.id(), target.id()))
                .contains(targetParticipant);
        assertThat(malformedStoryResponse)
                .doesNotContain(USER_ID.toString())
                .doesNotContain("google-subject")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken");
        assertThat(malformedTargetResponse)
                .doesNotContain(USER_ID.toString())
                .doesNotContain("google-subject")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken");
    }

    private Scenario saveScenario(StoryRole requesterRole) {
        User owner = saveUser(
                OWNER_ID,
                "owner-google-subject",
                "Owner User",
                "https://example.com/owner.png"
        );
        User requester = requesterRole == StoryRole.OWNER
                ? owner
                : saveUser(
                        USER_ID,
                        "requester-google-subject",
                        "Requester User",
                        null
                );
        User viewer = saveUser(
                SECOND_USER_ID,
                "viewer-google-subject",
                "Viewer User",
                null
        );
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        int expectedParticipantCount = 2;

        if (requesterRole != StoryRole.OWNER) {
            saveParticipant(
                    story.id(),
                    requester.id(),
                    requesterRole,
                    BASE_TIME.plusSeconds(1)
            );
            expectedParticipantCount++;
        }

        saveParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(2)
        );

        return new Scenario(story, requester, expectedParticipantCount);
    }

    private JsonNode getParticipants(
            String accessToken,
            UUID storyId,
            int expectedStatus
    ) throws Exception {
        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants",
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

        String response = result.getResponse().getContentAsString();

        if (response.isBlank()) {
            return jsonMapper.readTree("{}");
        }

        return jsonMapper.readTree(response);
    }

    private User saveUser(
            UUID userId,
            String googleSubject
    ) {
        return saveUser(
                userId,
                googleSubject,
                "Memory Map User",
                null
        );
    }

    private User saveUser(
            UUID userId,
            String googleSubject,
            String displayName,
            String avatarUrl
    ) {
        return userRepository.save(
                new User(
                        userId,
                        googleSubject,
                        displayName,
                        avatarUrl,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private Story saveStory(
            UUID storyId,
            UUID ownerId
    ) {
        return storyRepository.save(
                new Story(
                        storyId,
                        ownerId,
                        "Our Story",
                        "The beginning",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private StoryParticipant saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role,
            Instant joinedAt
    ) {
        StoryParticipant participant = new StoryParticipant(
                storyId,
                userId,
                role,
                joinedAt
        );
        storyParticipantRepository.save(participant);

        return participant;
    }

    private String validAccessToken(UUID userId) {
        return accessTokenService.issueAccessToken(
                userId,
                Instant.now()
        );
    }

    private int participantCountByStoryId(UUID storyId) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM story_participants
                WHERE story_id = :storyId
                """)
                .param("storyId", storyId)
                .query(Integer.class)
                .single();
    }

    private long countOwners(UUID storyId) {
        return storyParticipantRepository.countOwners(storyId);
    }

    private MvcResult deleteParticipant(
            String accessToken,
            UUID storyId,
            int expectedStatus
    ) throws Exception {
        MvcResult result = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
                        storyId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn();

        if (expectedStatus == 204) {
            assertThat(result.getResponse().getContentAsString()).isEmpty();
            assertThat(result.getResponse().getContentType()).isNull();
        }

        if (expectedStatus == 404 || expectedStatus == 409) {
            assertThat(result.getResponse().getContentType())
                    .contains(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        }

        return result;
    }

    private JsonNode deleteParticipantBody(
            String accessToken,
            UUID storyId,
            int expectedStatus
    ) throws Exception {
        return jsonMapper.readTree(
                deleteParticipant(accessToken, storyId, expectedStatus)
                        .getResponse()
                        .getContentAsString()
        );
    }

    private MvcResult removeParticipant(
            String accessToken,
            UUID storyId,
            UUID participantUserId,
            int expectedStatus
    ) throws Exception {
        MvcResult result = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        storyId,
                        participantUserId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn();

        if (expectedStatus == 204) {
            assertThat(result.getResponse().getContentAsString()).isEmpty();
            assertThat(result.getResponse().getContentType()).isNull();
        }

        if (expectedStatus == 404 || expectedStatus == 409) {
            assertThat(result.getResponse().getContentType())
                    .contains(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        }

        return result;
    }

    private JsonNode removeParticipantBody(
            String accessToken,
            UUID storyId,
            UUID participantUserId,
            int expectedStatus
    ) throws Exception {
        return jsonMapper.readTree(
                removeParticipant(
                        accessToken,
                        storyId,
                        participantUserId,
                        expectedStatus
                )
                        .getResponse()
                        .getContentAsString()
        );
    }

    private static void assertPublicParticipantResponseIsConfidential(
            JsonNode response
    ) {
        assertThat(response.toString())
                .doesNotContain("ownerId")
                .doesNotContain("storyId")
                .doesNotContain("googleSubject")
                .doesNotContain("email")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken")
                .doesNotContain("permission")
                .doesNotContain("availableAction")
                .doesNotContain("isCurrentUser");
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
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(OTHER_STORY_ID.toString())
                .doesNotContain(MISSING_STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(SECOND_USER_ID.toString())
                .doesNotContain(THIRD_USER_ID.toString())
                .doesNotContain(FOURTH_USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("userId")
                .doesNotContain("googleSubject")
                .doesNotContain("joinedAt")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken")
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("StoryNotFoundException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    private static void assertLastOwnerConflictBodyIsSafe(JsonNode response) {
        assertThat(response.at("/title").asText()).isEqualTo("Conflict");
        assertThat(response.at("/status").asInt()).isEqualTo(409);
        assertThat(response.at("/detail").asText())
                .isEqualTo("The last owner cannot leave the story");
        assertThat(response.at("/instance").asText())
                .isEqualTo("/api/v1/stories/participants/me");
        assertThat(response.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(OTHER_STORY_ID.toString())
                .doesNotContain(MISSING_STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(SECOND_USER_ID.toString())
                .doesNotContain(THIRD_USER_ID.toString())
                .doesNotContain(FOURTH_USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("userId")
                .doesNotContain("ownerCount")
                .doesNotContain("role")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository")
                .doesNotContain("LastStoryOwnerCannotLeaveException")
                .doesNotContain("stackTrace");
    }

    private static void assertRemoveSelfConflictBodyIsSafe(JsonNode response) {
        assertRemoveConflictBodyIsSafe(
                response,
                "Use the leave story operation to remove yourself"
        );
        assertThat(response.toString())
                .doesNotContain("ParticipantCannotRemoveSelfException");
    }

    private static void assertRemoveOwnerConflictBodyIsSafe(JsonNode response) {
        assertRemoveConflictBodyIsSafe(
                response,
                "A story owner cannot be removed"
        );
        assertThat(response.toString())
                .doesNotContain("StoryOwnerCannotBeRemovedException")
                .doesNotContain("ownerCount");
    }

    private static void assertRemoveConflictBodyIsSafe(
            JsonNode response,
            String detail
    ) {
        assertThat(response.at("/title").asText()).isEqualTo("Conflict");
        assertThat(response.at("/status").asInt()).isEqualTo(409);
        assertThat(response.at("/detail").asText()).isEqualTo(detail);
        assertThat(response.at("/instance").asText())
                .isEqualTo("/api/v1/stories/participants");
        assertThat(response.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(OTHER_STORY_ID.toString())
                .doesNotContain(MISSING_STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(SECOND_USER_ID.toString())
                .doesNotContain(THIRD_USER_ID.toString())
                .doesNotContain(FOURTH_USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("userId")
                .doesNotContain("googleSubject")
                .doesNotContain("joinedAt")
                .doesNotContain("accessToken")
                .doesNotContain("refreshToken")
                .doesNotContain("role")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository")
                .doesNotContain("stackTrace");
    }

    private record Scenario(

            Story story,

            User requester,

            int expectedParticipantCount

    ) {
    }
}
