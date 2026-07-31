package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultGetStoriesServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);

    @Test
    void shouldReturnStories() {

        UserStory first = userStory(STORY_ID, StoryRole.OWNER);
        UserStory second = userStory(
                UUID.fromString("00000000-0000-0000-0000-000000000003"),
                StoryRole.EDITOR
        );
        TestContext context = testContext(List.of(first, second));

        List<UserStory> result =
                context.service().getStories(AUTHENTICATED_USER);

        assertThat(result).containsExactly(first, second);
    }

    @Test
    void shouldReturnEmptyList() {

        TestContext context = testContext(List.of());

        List<UserStory> result =
                context.service().getStories(AUTHENTICATED_USER);

        assertThat(result).isEmpty();
    }

    @Test
    void shouldPassAuthenticatedUser() {

        TestContext context = testContext(List.of());

        context.service().getStories(AUTHENTICATED_USER);

        assertThat(context.repository().receivedUserId())
                .isEqualTo(USER_ID);
    }

    @Test
    void shouldDelegateToRepository() {

        TestContext context = testContext(List.of());

        context.service().getStories(AUTHENTICATED_USER);

        assertThat(context.repository().callCount()).isEqualTo(1);
    }

    @Test
    void shouldPreserveReturnedOrder() {

        UserStory first = userStory(
                UUID.fromString("00000000-0000-0000-0000-000000000003"),
                StoryRole.VIEWER
        );
        UserStory second = userStory(STORY_ID, StoryRole.OWNER);
        TestContext context = testContext(List.of(first, second));

        List<UserStory> result =
                context.service().getStories(AUTHENTICATED_USER);

        assertThat(result).containsExactly(first, second);
    }

    @Test
    void shouldRejectNullRepositoryDependency() {

        assertThatThrownBy(() -> new DefaultGetStoriesService(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> testContext(List.of())
                .service()
                .getStories(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldPropagateRepositoryFailure() {

        RuntimeException failure =
                new RuntimeException("repository failed");
        TestContext context = testContext(List.of());
        context.repository().failWith(failure);

        assertThatThrownBy(() ->
                context.service().getStories(AUTHENTICATED_USER))
                .isSameAs(failure);
    }

    private static TestContext testContext(
            List<UserStory> userStories
    ) {
        FakeUserStoryRepository repository =
                new FakeUserStoryRepository(userStories);

        return new TestContext(
                new DefaultGetStoriesService(repository),
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
                        CURRENT_TIME,
                        CURRENT_TIME
                ),
                role
        );
    }

    private record TestContext(

            DefaultGetStoriesService service,

            FakeUserStoryRepository repository

    ) {
    }

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        private final List<UserStory> userStories;
        private UUID receivedUserId;
        private int callCount;
        private RuntimeException failure;

        private FakeUserStoryRepository(
                List<UserStory> userStories
        ) {
            this.userStories = userStories;
        }

        @Override
        public List<UserStory> findByUserId(UUID userId) {
            receivedUserId = userId;
            callCount++;

            if (failure != null) {
                throw failure;
            }

            return userStories;
        }

        @Override
        public Optional<UserStory> findByStoryIdAndUserId(
                UUID storyId,
                UUID userId
        ) {
            throw new UnsupportedOperationException();
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
