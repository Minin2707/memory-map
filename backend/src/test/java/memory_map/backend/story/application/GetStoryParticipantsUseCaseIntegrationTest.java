package memory_map.backend.story.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
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
import org.springframework.jdbc.core.simple.JdbcClient;

import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GetStoryParticipantsUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private GetStoryParticipantsUseCase getStoryParticipantsUseCase;

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

    @Test
    void shouldRegisterProductionUseCaseBean() {

        assertThat(getStoryParticipantsUseCase)
                .isInstanceOf(DefaultGetStoryParticipantsService.class);
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldReturnParticipantsForEveryRequesterRole(StoryRole role) {

        Scenario scenario = saveScenario(role);

        List<StoryParticipantView> participants =
                getStoryParticipantsUseCase.getParticipants(
                        new AuthenticatedUser(scenario.requester().id()),
                        scenario.story().id()
                );

        assertThat(participants)
                .containsExactlyElementsOf(scenario.expectedViews());
    }

    @Test
    void shouldReturnProjectionWithNullableAvatarAndOrdering() {

        User owner = saveUser(
                OWNER_ID,
                "owner-google-subject",
                "Owner User",
                "https://example.com/owner.png"
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
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        List<StoryParticipantView> participants =
                getStoryParticipantsUseCase.getParticipants(
                        new AuthenticatedUser(owner.id()),
                        story.id()
                );

        assertThat(participants).containsExactly(
                new StoryParticipantView(
                        owner.id(),
                        "Owner User",
                        "https://example.com/owner.png",
                        StoryRole.OWNER,
                        BASE_TIME
                ),
                new StoryParticipantView(
                        viewer.id(),
                        "Viewer User",
                        null,
                        StoryRole.VIEWER,
                        BASE_TIME.plusSeconds(1)
                )
        );
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryDoesNotExist() {

        User user = saveUser(USER_ID, "current-google-subject");

        assertStoryNotFound(() ->
                getStoryParticipantsUseCase.getParticipants(
                        new AuthenticatedUser(user.id()),
                        STORY_ID
                ));
    }

    @Test
    void shouldThrowSameStoryNotFoundWhenStoryIsInaccessible() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User outsider = saveUser(USER_ID, "outsider-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(
                story.id(),
                owner.id(),
                StoryRole.OWNER,
                BASE_TIME
        );

        StoryNotFoundException inaccessible = catchStoryNotFound(() ->
                getStoryParticipantsUseCase.getParticipants(
                        new AuthenticatedUser(outsider.id()),
                        story.id()
                ));
        StoryNotFoundException missing = catchStoryNotFound(() ->
                getStoryParticipantsUseCase.getParticipants(
                        new AuthenticatedUser(outsider.id()),
                        OTHER_STORY_ID
                ));

        assertThat(inaccessible).hasMessage("Story was not found");
        assertThat(missing).hasMessage("Story was not found");
        assertThat(inaccessible.getClass()).isEqualTo(missing.getClass());
        assertThat(inaccessible.getMessage())
                .isEqualTo(missing.getMessage());
    }

    @Test
    void shouldThrowStoryNotFoundForParticipantOfAnotherStory() {

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

        assertStoryNotFound(() ->
                getStoryParticipantsUseCase.getParticipants(
                        new AuthenticatedUser(requester.id()),
                        story.id()
                ));
    }

    @Test
    void shouldThrowStoryNotFoundForOwnerWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User participant = saveUser(USER_ID, "participant-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(
                story.id(),
                participant.id(),
                StoryRole.VIEWER,
                BASE_TIME
        );

        assertStoryNotFound(() ->
                getStoryParticipantsUseCase.getParticipants(
                        new AuthenticatedUser(owner.id()),
                        story.id()
                ));
    }

    @Test
    void shouldExposeOnlyParticipantReadModelFields() {

        assertThat(Arrays.stream(StoryParticipantView.class
                .getRecordComponents())
                .map(RecordComponent::getName))
                .containsExactly(
                        "userId",
                        "displayName",
                        "avatarUrl",
                        "role",
                        "joinedAt"
                );
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
                OTHER_USER_ID,
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

        if (requesterRole != StoryRole.OWNER) {
            saveParticipant(
                    story.id(),
                    requester.id(),
                    requesterRole,
                    BASE_TIME.plusSeconds(1)
            );
        }

        saveParticipant(
                story.id(),
                viewer.id(),
                StoryRole.VIEWER,
                BASE_TIME.plusSeconds(2)
        );

        List<StoryParticipantView> expectedViews = requesterRole == StoryRole.OWNER
                ? List.of(
                        participantView(owner, StoryRole.OWNER, BASE_TIME),
                        participantView(
                                viewer,
                                StoryRole.VIEWER,
                                BASE_TIME.plusSeconds(2)
                        )
                )
                : List.of(
                        participantView(owner, StoryRole.OWNER, BASE_TIME),
                        participantView(
                                requester,
                                requesterRole,
                                BASE_TIME.plusSeconds(1)
                        ),
                        participantView(
                                viewer,
                                StoryRole.VIEWER,
                                BASE_TIME.plusSeconds(2)
                        )
                );

        return new Scenario(story, requester, expectedViews);
    }

    private static void assertStoryNotFound(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    private static StoryNotFoundException catchStoryNotFound(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (StoryNotFoundException exception) {
            return exception;
        }

        throw new AssertionError("Expected StoryNotFoundException");
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

    private static StoryParticipantView participantView(
            User user,
            StoryRole role,
            Instant joinedAt
    ) {
        return new StoryParticipantView(
                user.id(),
                user.displayName(),
                user.avatarUrl(),
                role,
                joinedAt
        );
    }

    private record Scenario(

            Story story,

            User requester,

            List<StoryParticipantView> expectedViews

    ) {
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
