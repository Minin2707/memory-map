package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.story.application.DownloadStoryParticipantAvatarUseCase;
import memory_map.backend.story.application.DownloadedStoryParticipantAvatar;
import memory_map.backend.story.application.GetStoryParticipantsUseCase;
import memory_map.backend.story.application.LastStoryOwnerCannotLeaveException;
import memory_map.backend.story.application.LeaveStoryCommand;
import memory_map.backend.story.application.LeaveStoryUseCase;
import memory_map.backend.story.application.ParticipantCannotRemoveSelfException;
import memory_map.backend.story.application.RemoveStoryParticipantCommand;
import memory_map.backend.story.application.RemoveStoryParticipantUseCase;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.StoryOwnerCannotBeRemovedException;
import memory_map.backend.story.application.StoryParticipantView;
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
import org.springframework.test.web.servlet.MvcResult;

import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(StoryParticipantController.class)
@AutoConfigureMockMvc
@Import({
        StoryApiExceptionHandler.class,
        SecurityConfiguration.class,
        StoryParticipantControllerTest.StoryParticipantControllerTestConfiguration.class
})
class StoryParticipantControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeGetStoryParticipantsUseCase getStoryParticipantsUseCase;

    @Autowired
    private FakeDownloadStoryParticipantAvatarUseCase
            downloadStoryParticipantAvatarUseCase;

    @Autowired
    private FakeLeaveStoryUseCase leaveStoryUseCase;

    @Autowired
    private FakeRemoveStoryParticipantUseCase removeStoryParticipantUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID SECOND_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID THIRD_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID FOURTH_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final String VALID_ACCESS_TOKEN =
            "valid-access-token";
    private static final String INVALID_ACCESS_TOKEN =
            "invalid-access-token";

    @BeforeEach
    void resetFakes() {
        getStoryParticipantsUseCase.reset();
        downloadStoryParticipantAvatarUseCase.reset();
        leaveStoryUseCase.reset();
        removeStoryParticipantUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldReturnParticipants() throws Exception {

        getStoryParticipantsUseCase.participants(List.of(
                participantView(
                        USER_ID,
                        "Owner User",
                        "https://example.com/owner.png",
                        StoryRole.OWNER,
                        JOINED_AT
                ),
                participantView(
                        SECOND_USER_ID,
                        "Co Owner User",
                        null,
                        StoryRole.CO_OWNER,
                        JOINED_AT.plusSeconds(1)
                ),
                participantView(
                        THIRD_USER_ID,
                        "Editor User",
                        null,
                        StoryRole.EDITOR,
                        JOINED_AT.plusSeconds(2)
                ),
                participantView(
                        FOURTH_USER_ID,
                        "Viewer User",
                        null,
                        StoryRole.VIEWER,
                        JOINED_AT.plusSeconds(3)
                )
        ));

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants",
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
                .andExpect(jsonPath("$.length()").value(4))
                .andExpect(jsonPath("$[0].userId")
                        .value(USER_ID.toString()))
                .andExpect(jsonPath("$[0].displayName")
                        .value("Owner User"))
                .andExpect(jsonPath("$[0].avatarUrl")
                        .value("https://example.com/owner.png"))
                .andExpect(jsonPath("$[0].role")
                        .value("OWNER"))
                .andExpect(jsonPath("$[0].joinedAt")
                        .value("2026-01-01T10:00:00Z"))
                .andExpect(jsonPath("$[1].userId")
                        .value(SECOND_USER_ID.toString()))
                .andExpect(jsonPath("$[1].avatarUrl")
                        .value((Object) null))
                .andExpect(jsonPath("$[1].role")
                        .value("CO_OWNER"))
                .andExpect(jsonPath("$[2].role")
                        .value("EDITOR"))
                .andExpect(jsonPath("$[3].role")
                        .value("VIEWER"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(getStoryParticipantsUseCase.callCount()).isEqualTo(1);
        assertThat(getStoryParticipantsUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(getStoryParticipantsUseCase.receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(response)
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

    @Test
    void shouldReturnEmptyArrayWhenUseCaseReturnsEmpty() throws Exception {

        getStoryParticipantsUseCase.participants(List.of());

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants",
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
        assertThat(getStoryParticipantsUseCase.callCount()).isEqualTo(1);
    }

    @Test
    void shouldDownloadParticipantAvatarWithPrivateHeaders() throws Exception {

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants/"
                                + "{participantUserId}/avatar/{version}",
                        STORY_ID,
                        SECOND_USER_ID,
                        "1768039200000"
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk())
                .andExpect(content().bytes(new byte[] {1, 2, 3}))
                .andExpect(content().contentTypeCompatibleWith("image/jpeg"))
                .andExpect(header().string(
                        HttpHeaders.CACHE_CONTROL,
                        "private, no-store"
                ));

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(downloadStoryParticipantAvatarUseCase.callCount())
                .isEqualTo(1);
        assertThat(downloadStoryParticipantAvatarUseCase
                .receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(downloadStoryParticipantAvatarUseCase.receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(downloadStoryParticipantAvatarUseCase
                .receivedParticipantUserId())
                .isEqualTo(SECOND_USER_ID);
    }

    @Test
    void shouldRejectParticipantAvatarRequestWithoutBearerToken()
            throws Exception {

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants/"
                                + "{participantUserId}/avatar/{version}",
                        STORY_ID,
                        SECOND_USER_ID,
                        "1768039200000"
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(downloadStoryParticipantAvatarUseCase.callCount())
                .isZero();
    }

    @Test
    void shouldReturnNotFoundWhenStoryIsUnavailable() throws Exception {

        getStoryParticipantsUseCase.failWith(new StoryNotFoundException());

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants",
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
        assertThat(getStoryParticipantsUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
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

    @Test
    void shouldReturnBadRequestForMalformedStoryId() throws Exception {

        mockMvc.perform(get("/api/v1/stories/not-a-uuid/participants")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(getStoryParticipantsUseCase.callCount()).isZero();
    }

    @Test
    void shouldLeaveStoryFromAuthenticatedUserAndStoryId()
            throws Exception {

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
                        STORY_ID
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

        LeaveStoryCommand command = leaveStoryUseCase.receivedCommand();

        assertThat(response).isEmpty();
        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(leaveStoryUseCase.callCount()).isEqualTo(1);
        assertThat(getStoryParticipantsUseCase.callCount()).isZero();
        assertThat(removeStoryParticipantUseCase.callCount()).isZero();
    }

    @Test
    void shouldRouteParticipantsMeToLeaveUseCaseOnly()
            throws Exception {

        removeStoryParticipantUseCase.failWith(
                new AssertionError("Remove use case must not be called")
        );

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        assertThat(leaveStoryUseCase.callCount()).isEqualTo(1);
        assertThat(removeStoryParticipantUseCase.callCount()).isZero();
    }

    @Test
    void shouldRemoveParticipantFromAuthenticatedUserStoryIdAndTargetId()
            throws Exception {

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        STORY_ID,
                        SECOND_USER_ID
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

        RemoveStoryParticipantCommand command =
                removeStoryParticipantUseCase.receivedCommand();

        assertThat(response).isEmpty();
        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.participantUserId()).isEqualTo(SECOND_USER_ID);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(removeStoryParticipantUseCase.callCount()).isEqualTo(1);
        assertThat(getStoryParticipantsUseCase.callCount()).isZero();
        assertThat(leaveStoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnNotFoundWhenRemoveParticipantIsUnavailable()
            throws Exception {

        removeStoryParticipantUseCase.failWith(new StoryNotFoundException());

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        STORY_ID,
                        SECOND_USER_ID
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
        assertThat(removeStoryParticipantUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(SECOND_USER_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("already removed")
                .doesNotContain("not a participant")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("StoryNotFoundException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnConflictWhenOwnerTargetsSelfThroughRemove()
            throws Exception {

        removeStoryParticipantUseCase.failWith(
                new ParticipantCannotRemoveSelfException()
        );

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        STORY_ID,
                        USER_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isConflict())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_PROBLEM_JSON
                        ))
                .andExpect(jsonPath("$.title").value("Conflict"))
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.detail")
                        .value("Use the leave story operation to remove yourself"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/stories/participants"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(removeStoryParticipantUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("role")
                .doesNotContain("ParticipantCannotRemoveSelfException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnConflictWhenRemovingOwnerTarget()
            throws Exception {

        removeStoryParticipantUseCase.failWith(
                new StoryOwnerCannotBeRemovedException()
        );

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        STORY_ID,
                        SECOND_USER_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isConflict())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_PROBLEM_JSON
                        ))
                .andExpect(jsonPath("$.title").value("Conflict"))
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.detail")
                        .value("A story owner cannot be removed"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/stories/participants"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(removeStoryParticipantUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(SECOND_USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("ownerCount")
                .doesNotContain("role")
                .doesNotContain("StoryOwnerCannotBeRemovedException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnNotFoundWhenLeaveStoryIsUnavailable()
            throws Exception {

        leaveStoryUseCase.failWith(new StoryNotFoundException());

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
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
        assertThat(leaveStoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("already left")
                .doesNotContain("not a participant")
                .doesNotContain("access denied")
                .doesNotContain("forbidden")
                .doesNotContain("StoryNotFoundException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnConflictWhenLastOwnerLeaves() throws Exception {

        leaveStoryUseCase.failWith(
                new LastStoryOwnerCannotLeaveException()
        );

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isConflict())
                .andExpect(content()
                        .contentTypeCompatibleWith(
                                MediaType.APPLICATION_PROBLEM_JSON
                        ))
                .andExpect(jsonPath("$.title").value("Conflict"))
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.detail")
                        .value("The last owner cannot leave the story"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/stories/participants/me"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(leaveStoryUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("ownerId")
                .doesNotContain("ownerCount")
                .doesNotContain("role")
                .doesNotContain("LastStoryOwnerCannotLeaveException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryIdWhenLeaving()
            throws Exception {

        mockMvc.perform(delete(
                        "/api/v1/stories/not-a-uuid/participants/me"
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(leaveStoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedStoryIdWhenRemoving()
            throws Exception {

        mockMvc.perform(delete(
                        "/api/v1/stories/not-a-uuid/participants/{participantUserId}",
                        SECOND_USER_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(removeStoryParticipantUseCase.callCount()).isZero();
        assertThat(leaveStoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedParticipantUserIdWhenRemoving()
            throws Exception {

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/not-a-uuid",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(removeStoryParticipantUseCase.callCount()).isZero();
        assertThat(leaveStoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectLeaveRequestWithoutBearerToken() throws Exception {

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(leaveStoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectRemoveRequestWithoutBearerToken() throws Exception {

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        STORY_ID,
                        SECOND_USER_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(removeStoryParticipantUseCase.callCount()).isZero();
        assertThat(leaveStoryUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectLeaveRequestWithInvalidBearerToken() throws Exception {

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/me",
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
        assertThat(leaveStoryUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain(INVALID_ACCESS_TOKEN)
                .doesNotContain(STORY_ID.toString());
    }

    @Test
    void shouldRejectRemoveRequestWithInvalidBearerToken() throws Exception {

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/participants/{participantUserId}",
                        STORY_ID,
                        SECOND_USER_ID
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
        assertThat(removeStoryParticipantUseCase.callCount()).isZero();
        assertThat(leaveStoryUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain(INVALID_ACCESS_TOKEN)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(SECOND_USER_ID.toString());
    }

    @Test
    void shouldRejectRequestWithoutBearerToken() throws Exception {

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(getStoryParticipantsUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectRequestWithInvalidBearerToken() throws Exception {

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/participants",
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
        assertThat(getStoryParticipantsUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain(INVALID_ACCESS_TOKEN)
                .doesNotContain(STORY_ID.toString());
    }

    @Test
    void shouldRejectNullGetStoryParticipantsUseCaseDependency() {

        assertThatThrownBy(() -> new StoryParticipantController(
                null,
                downloadStoryParticipantAvatarUseCase,
                leaveStoryUseCase,
                removeStoryParticipantUseCase,
                currentAuthenticatedUserProvider
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("getStoryParticipantsUseCase must not be null");
    }

    @Test
    void shouldRejectNullDownloadStoryParticipantAvatarUseCaseDependency() {

        assertThatThrownBy(() -> new StoryParticipantController(
                getStoryParticipantsUseCase,
                null,
                leaveStoryUseCase,
                removeStoryParticipantUseCase,
                currentAuthenticatedUserProvider
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "downloadStoryParticipantAvatarUseCase "
                                + "must not be null"
                );
    }

    @Test
    void shouldRejectNullLeaveStoryUseCaseDependency() {

        assertThatThrownBy(() -> new StoryParticipantController(
                getStoryParticipantsUseCase,
                downloadStoryParticipantAvatarUseCase,
                null,
                removeStoryParticipantUseCase,
                currentAuthenticatedUserProvider
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("leaveStoryUseCase must not be null");
    }

    @Test
    void shouldRejectNullRemoveStoryParticipantUseCaseDependency() {

        assertThatThrownBy(() -> new StoryParticipantController(
                getStoryParticipantsUseCase,
                downloadStoryParticipantAvatarUseCase,
                leaveStoryUseCase,
                null,
                currentAuthenticatedUserProvider
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("removeStoryParticipantUseCase must not be null");
    }

    @Test
    void shouldRejectNullCurrentAuthenticatedUserProviderDependency() {

        assertThatThrownBy(() -> new StoryParticipantController(
                getStoryParticipantsUseCase,
                downloadStoryParticipantAvatarUseCase,
                leaveStoryUseCase,
                removeStoryParticipantUseCase,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "currentAuthenticatedUserProvider must not be null"
                );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class StoryParticipantControllerTestConfiguration {

        @Bean
        FakeGetStoryParticipantsUseCase getStoryParticipantsUseCase() {
            return new FakeGetStoryParticipantsUseCase();
        }

        @Bean
        FakeDownloadStoryParticipantAvatarUseCase
        downloadStoryParticipantAvatarUseCase() {
            return new FakeDownloadStoryParticipantAvatarUseCase();
        }

        @Bean
        FakeLeaveStoryUseCase leaveStoryUseCase() {
            return new FakeLeaveStoryUseCase();
        }

        @Bean
        FakeRemoveStoryParticipantUseCase removeStoryParticipantUseCase() {
            return new FakeRemoveStoryParticipantUseCase();
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
                        .issuedAt(JOINED_AT)
                        .expiresAt(JOINED_AT.plusSeconds(900))
                        .build();
            };
        }
    }

    static final class FakeGetStoryParticipantsUseCase
            implements GetStoryParticipantsUseCase {

        private List<StoryParticipantView> participants = List.of();
        private RuntimeException exception;
        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedStoryId;
        private int callCount;

        @Override
        public List<StoryParticipantView> getParticipants(
                AuthenticatedUser authenticatedUser,
                UUID storyId
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedStoryId = storyId;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return participants;
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

        private void participants(
                List<StoryParticipantView> participants
        ) {
            this.participants = participants;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            participants = List.of();
            exception = null;
            receivedAuthenticatedUser = null;
            receivedStoryId = null;
            callCount = 0;
        }
    }

    static final class FakeDownloadStoryParticipantAvatarUseCase
            implements DownloadStoryParticipantAvatarUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedStoryId;
        private UUID receivedParticipantUserId;
        private int callCount;

        @Override
        public DownloadedStoryParticipantAvatar downloadAvatar(
                AuthenticatedUser authenticatedUser,
                UUID storyId,
                UUID participantUserId
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedStoryId = storyId;
            receivedParticipantUserId = participantUserId;
            callCount++;

            return new DownloadedStoryParticipantAvatar(
                    new ByteArrayInputStream(new byte[] {1, 2, 3}),
                    3L,
                    "image/jpeg"
            );
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedParticipantUserId() {
            return receivedParticipantUserId;
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedStoryId = null;
            receivedParticipantUserId = null;
            callCount = 0;
        }
    }

    static final class FakeLeaveStoryUseCase implements LeaveStoryUseCase {

        private LeaveStoryCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public void leaveStory(LeaveStoryCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }
        }

        private LeaveStoryCommand receivedCommand() {
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

    static final class FakeRemoveStoryParticipantUseCase
            implements RemoveStoryParticipantUseCase {

        private RemoveStoryParticipantCommand receivedCommand;
        private RuntimeException exception;
        private Error error;
        private int callCount;

        @Override
        public void removeParticipant(RemoveStoryParticipantCommand command) {
            receivedCommand = command;
            callCount++;

            if (error != null) {
                throw error;
            }

            if (exception != null) {
                throw exception;
            }
        }

        private RemoveStoryParticipantCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void failWith(Error error) {
            this.error = error;
        }

        private void reset() {
            receivedCommand = null;
            exception = null;
            error = null;
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

    private static StoryParticipantView participantView(
            UUID userId,
            String displayName,
            String avatarUrl,
            StoryRole role,
            Instant joinedAt
    ) {
        return new StoryParticipantView(
                userId,
                displayName,
                avatarUrl,
                role,
                joinedAt
        );
    }
}
