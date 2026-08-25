package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultGetStoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);

    @Test
    void shouldReturnAccessibleStory() {

        UserStory userStory = userStory(STORY_ID, StoryRole.OWNER);
        TestContext context = testContext(Optional.of(userStory));

        UserStory result = context.service().getStory(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThat(result).isEqualTo(userStory);
    }

    @Test
    void shouldPassStoryIdAndAuthenticatedUserId() {

        TestContext context = testContext(
                Optional.of(userStory(STORY_ID, StoryRole.OWNER))
        );

        context.service().getStory(AUTHENTICATED_USER, STORY_ID);

        assertThat(context.repository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.repository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.repository().callCount()).isEqualTo(1);
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldReturnAllSupportedRoles(StoryRole role) {

        UserStory userStory = userStory(STORY_ID, role);
        TestContext context = testContext(Optional.of(userStory));

        UserStory result = context.service().getStory(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThat(result.role()).isEqualTo(role);
        assertThat(result).isEqualTo(userStory);
    }

    @Test
    void shouldRejectNullRepositoryDependency() {

        assertThatThrownBy(() -> new DefaultGetStoryService(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> testContext(
                Optional.of(userStory(STORY_ID, StoryRole.OWNER))
        ).service().getStory(null, STORY_ID))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> testContext(
                Optional.of(userStory(STORY_ID, StoryRole.OWNER))
        ).service().getStory(AUTHENTICATED_USER, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldThrowStoryNotFoundWhenRepositoryReturnsEmpty() {

        TestContext context = testContext(Optional.empty());

        assertThatThrownBy(() -> context.service().getStory(
                AUTHENTICATED_USER,
                STORY_ID
        ))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    @Test
    void shouldUseSameFailureForMissingOrInaccessibleOutcome() {

        StoryNotFoundException missing = catchStoryNotFound(
                testContext(Optional.empty()),
                STORY_ID
        );
        StoryNotFoundException inaccessible = catchStoryNotFound(
                testContext(Optional.empty()),
                OTHER_STORY_ID
        );

        assertThat(missing).hasMessage("Story was not found");
        assertThat(inaccessible).hasMessage("Story was not found");
        assertThat(missing.getClass()).isEqualTo(inaccessible.getClass());
        assertThat(missing.getMessage())
                .isEqualTo(inaccessible.getMessage());
    }

    @Test
    void shouldPropagateRepositoryFailure() {

        RuntimeException failure = new RuntimeException("repository failed");
        TestContext context = testContext(Optional.empty());
        context.repository().failWith(failure);

        assertThatThrownBy(() -> context.service().getStory(
                AUTHENTICATED_USER,
                STORY_ID
        ))
                .isSameAs(failure);
    }

    @Test
    void shouldReturnExactRepositoryResult() {

        UserStory userStory = userStory(STORY_ID, StoryRole.EDITOR);
        TestContext context = testContext(Optional.of(userStory));

        UserStory result = context.service().getStory(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThat(result).isSameAs(userStory);
    }

    private static StoryNotFoundException catchStoryNotFound(
            TestContext context,
            UUID storyId
    ) {
        try {
            context.service().getStory(AUTHENTICATED_USER, storyId);
        } catch (StoryNotFoundException exception) {
            return exception;
        }

        throw new AssertionError("Expected StoryNotFoundException");
    }

    private static TestContext testContext(
            Optional<UserStory> userStory
    ) {
        FakeUserStoryRepository repository =
                new FakeUserStoryRepository(userStory);

        return new TestContext(
                new DefaultGetStoryService(repository),
                repository
        );
    }

    private static UserStory userStory(
            UUID storyId,
            StoryRole role
    ) {
        return new UserStory(
                new Story(
                        storyId,
                        USER_ID,
                        "Our Story",
                        "The beginning",
                        null,
                        CURRENT_TIME,
                        CURRENT_TIME
                ),
                role
        );
    }

    private record TestContext(

            DefaultGetStoryService service,

            FakeUserStoryRepository repository

    ) {
    }

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        private final Optional<UserStory> userStory;
        private UUID receivedStoryId;
        private UUID receivedUserId;
        private int callCount;
        private RuntimeException failure;

        private FakeUserStoryRepository(
                Optional<UserStory> userStory
        ) {
            this.userStory = userStory;
        }

        @Override
        public List<UserStory> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<UserStory> findByStoryIdAndUserId(
                UUID storyId,
                UUID userId
        ) {
            receivedStoryId = storyId;
            receivedUserId = userId;
            callCount++;

            if (failure != null) {
                throw failure;
            }

            return userStory;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException failure) {
            this.failure = failure;
        }
    }
}
