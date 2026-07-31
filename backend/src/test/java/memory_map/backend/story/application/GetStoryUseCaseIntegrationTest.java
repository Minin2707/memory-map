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
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GetStoryUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private GetStoryUseCase getStoryUseCase;

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
    void shouldReturnOwnerStory() {

        assertAccessibleRole(StoryRole.OWNER);
    }

    @Test
    void shouldReturnCoOwnerStory() {

        assertAccessibleRole(StoryRole.CO_OWNER);
    }

    @Test
    void shouldReturnEditorStory() {

        assertAccessibleRole(StoryRole.EDITOR);
    }

    @Test
    void shouldReturnViewerStory() {

        assertAccessibleRole(StoryRole.VIEWER);
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryDoesNotExist() {

        User user = saveUser(USER_ID, "current-google-subject");

        assertStoryNotFound(
                () -> getStoryUseCase.getStory(
                        new AuthenticatedUser(user.id()),
                        STORY_ID
                )
        );
    }

    @Test
    void shouldThrowSameStoryNotFoundWhenStoryIsInaccessible() {

        User user = saveUser(USER_ID, "current-google-subject");
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        StoryNotFoundException inaccessible = catchStoryNotFound(
                () -> getStoryUseCase.getStory(
                        new AuthenticatedUser(user.id()),
                        story.id()
                )
        );
        StoryNotFoundException missing = catchStoryNotFound(
                () -> getStoryUseCase.getStory(
                        new AuthenticatedUser(user.id()),
                        OTHER_STORY_ID
                )
        );

        assertThat(inaccessible).hasMessage("Story was not found");
        assertThat(missing).hasMessage("Story was not found");
        assertThat(inaccessible.getClass()).isEqualTo(missing.getClass());
        assertThat(inaccessible.getMessage())
                .isEqualTo(missing.getMessage());
    }

    @Test
    void shouldDenyOwnerWithoutMembership() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Owner Without Membership Story",
                "The beginning"
        );

        assertStoryNotFound(
                () -> getStoryUseCase.getStory(
                        new AuthenticatedUser(owner.id()),
                        story.id()
                )
        );
    }

    @Test
    void shouldDenyWrongUser() {

        User user = saveUser(USER_ID, "current-google-subject");
        User otherUser = saveUser(OTHER_USER_ID, "other-google-subject");
        Story story = saveStory(
                STORY_ID,
                otherUser.id(),
                "Wrong User Story",
                "The beginning"
        );
        saveParticipant(story.id(), otherUser.id(), StoryRole.VIEWER);

        assertStoryNotFound(
                () -> getStoryUseCase.getStory(
                        new AuthenticatedUser(user.id()),
                        story.id()
                )
        );
    }

    @Test
    void shouldReturnNullableDescription() {

        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                user.id(),
                "Nullable Description Story",
                null
        );
        saveParticipant(story.id(), user.id(), StoryRole.VIEWER);

        UserStory result = getStoryUseCase.getStory(
                new AuthenticatedUser(user.id()),
                story.id()
        );

        assertThat(result).isEqualTo(
                new UserStory(story, StoryRole.VIEWER)
        );
        assertThat(result.story().description()).isNull();
    }

    private void assertAccessibleRole(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = role == StoryRole.OWNER
                ? owner
                : saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Accessible Story",
                "The beginning"
        );
        saveParticipant(story.id(), user.id(), role);

        UserStory result = getStoryUseCase.getStory(
                new AuthenticatedUser(user.id()),
                story.id()
        );

        assertThat(result).isEqualTo(new UserStory(story, role));
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
        return userRepository.save(
                new User(
                        userId,
                        googleSubject,
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
            String description
    ) {
        return storyRepository.save(
                new Story(
                        storyId,
                        ownerId,
                        title,
                        description,
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

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
