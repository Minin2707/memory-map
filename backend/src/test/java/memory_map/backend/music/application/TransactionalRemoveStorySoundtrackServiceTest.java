package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.application.StoryAccessPolicy;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalRemoveStorySoundtrackServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-02T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldRemoveSoundtrackForOwner() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );

        StorySoundtrack result = context.service().removeStorySoundtrack(
                command()
        );

        assertThat(result).isEqualTo(StorySoundtrack.noMusic());
        assertThat(context.userStoryRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.userStoryRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.storyRepository().updatedStory())
                .isEqualTo(storyWithSoundtrack(null, CURRENT_TIME));
    }

    @Test
    void shouldRemoveSoundtrackForCoOwner() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.CO_OWNER)
        );

        StorySoundtrack result = context.service().removeStorySoundtrack(
                command()
        );

        assertThat(result).isEqualTo(StorySoundtrack.noMusic());
        assertThat(context.storyRepository().updateCallCount()).isEqualTo(1);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyRolesThatCannotChangeSoundtrack(StoryRole role) {
        TestContext context = testContext(userStory(TRACK_ID, role));

        assertStoryNotFound(() -> context.service().removeStorySoundtrack(
                command()
        ));

        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldThrowStoryNotFoundForMissingOrInaccessibleStory() {
        TestContext context = testContext(Optional.empty());

        assertStoryNotFound(() -> context.service().removeStorySoundtrack(
                command()
        ));

        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldPreserveNonSoundtrackStoryFields() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );

        context.service().removeStorySoundtrack(command());

        Story updated = context.storyRepository().updatedStory();
        assertThat(updated.id()).isEqualTo(STORY_ID);
        assertThat(updated.ownerId()).isEqualTo(OWNER_ID);
        assertThat(updated.title()).isEqualTo("Our Story");
        assertThat(updated.description()).isEqualTo("The beginning");
        assertThat(updated.soundtrackId()).isNull();
        assertThat(updated.createdAt()).isEqualTo(CREATED_AT);
        assertThat(updated.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldTreatAlreadyNullSoundtrackAsNoOp() {
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );

        StorySoundtrack result = context.service().removeStorySoundtrack(
                command()
        );

        assertThat(result).isEqualTo(StorySoundtrack.noMusic());
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldRemoveDisabledSelectedTrackWithoutLoadingMusicTrack() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );

        StorySoundtrack result = context.service().removeStorySoundtrack(
                command()
        );

        assertThat(result).isEqualTo(StorySoundtrack.noMusic());
        assertThat(context.storyRepository().updatedStory().soundtrackId())
                .isNull();
    }

    @Test
    void shouldPropagateLookupRepositoryFailure() {
        RuntimeException failure = new RuntimeException("lookup failed");
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.userStoryRepository().failWith(failure);

        assertThatThrownBy(() -> context.service().removeStorySoundtrack(
                command()
        )).isSameAs(failure);
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldPropagateStoryUpdateFailure() {
        RuntimeException failure = new RuntimeException("update failed");
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.storyRepository().failOnUpdate(failure);

        assertThatThrownBy(() -> context.service().removeStorySoundtrack(
                command()
        )).isSameAs(failure);
    }

    @Test
    void shouldLookupStoryBeforeUpdate() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );

        context.service().removeStorySoundtrack(command());

        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "update Story"
        );
    }

    @Test
    void shouldRejectNullDependencies() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );

        assertThatThrownBy(() -> new TransactionalRemoveStorySoundtrackService(
                null,
                context.storyRepository(),
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");

        assertThatThrownBy(() -> new TransactionalRemoveStorySoundtrackService(
                context.userStoryRepository(),
                null,
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");

        assertThatThrownBy(() -> new TransactionalRemoveStorySoundtrackService(
                context.userStoryRepository(),
                context.storyRepository(),
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyAccessPolicy must not be null");
    }

    @Test
    void shouldRejectNullCommand() {
        assertThatThrownBy(() -> testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        ).service().removeStorySoundtrack(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    private static void assertStoryNotFound(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    private static TestContext testContext(UserStory userStory) {
        return testContext(Optional.of(userStory));
    }

    private static TestContext testContext(Optional<UserStory> userStory) {
        List<String> calls = new ArrayList<>();
        FakeUserStoryRepository userStoryRepository =
                new FakeUserStoryRepository(userStory, calls);
        FakeStoryRepository storyRepository = new FakeStoryRepository(calls);

        return new TestContext(
                new TransactionalRemoveStorySoundtrackService(
                        userStoryRepository,
                        storyRepository,
                        new StoryAccessPolicy()
                ),
                userStoryRepository,
                storyRepository,
                calls
        );
    }

    private static RemoveStorySoundtrackCommand command() {
        return new RemoveStorySoundtrackCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                CURRENT_TIME
        );
    }

    private static UserStory userStory(UUID soundtrackId, StoryRole role) {
        return new UserStory(storyWithSoundtrack(soundtrackId, UPDATED_AT), role);
    }

    private static Story storyWithSoundtrack(
            UUID soundtrackId,
            Instant updatedAt
    ) {
        return new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                "The beginning",
                soundtrackId,
                CREATED_AT,
                updatedAt
        );
    }

    private record TestContext(

            TransactionalRemoveStorySoundtrackService service,

            FakeUserStoryRepository userStoryRepository,

            FakeStoryRepository storyRepository,

            List<String> calls

    ) {
    }

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        private final Optional<UserStory> userStory;
        private final List<String> calls;
        private UUID receivedStoryId;
        private UUID receivedUserId;
        private RuntimeException failure;

        private FakeUserStoryRepository(
                Optional<UserStory> userStory,
                List<String> calls
        ) {
            this.userStory = userStory;
            this.calls = calls;
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
            calls.add("find UserStory");
            receivedStoryId = storyId;
            receivedUserId = userId;

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

        private void failWith(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        private final List<String> calls;
        private Story updatedStory;
        private int updateCallCount;
        private RuntimeException failure;

        private FakeStoryRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Story save(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Story update(Story story) {
            calls.add("update Story");
            updateCallCount++;
            updatedStory = story;

            if (failure != null) {
                throw failure;
            }

            return story;
        }

        @Override
        public Optional<Story> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean lockById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            throw new UnsupportedOperationException();
        }

        private Story updatedStory() {
            return updatedStory;
        }

        private int updateCallCount() {
            return updateCallCount;
        }

        private void failOnUpdate(RuntimeException failure) {
            this.failure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
