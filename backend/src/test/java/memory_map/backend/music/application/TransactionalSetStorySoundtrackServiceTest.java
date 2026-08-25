package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.music.repository.MusicTrackRepository;
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

class TransactionalSetStorySoundtrackServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID OTHER_TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-02T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldSetSoundtrackForOwner() {
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );
        MusicTrack track = activeTrack(TRACK_ID);
        context.musicTrackRepository().track(Optional.of(track));

        StorySoundtrack result = context.service().setStorySoundtrack(
                command(TRACK_ID)
        );

        assertThat(result.selectedSoundtrack()).isSameAs(track);
        assertThat(result.effectiveSoundtrack()).isSameAs(track);
        assertThat(context.userStoryRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.userStoryRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.musicTrackRepository().receivedId())
                .isEqualTo(TRACK_ID);
        assertThat(context.storyRepository().updatedStory())
                .isEqualTo(storyWithSoundtrack(TRACK_ID, CURRENT_TIME));
    }

    @Test
    void shouldSetSoundtrackForCoOwner() {
        TestContext context = testContext(
                userStory(null, StoryRole.CO_OWNER)
        );
        MusicTrack track = activeTrack(TRACK_ID);
        context.musicTrackRepository().track(Optional.of(track));

        StorySoundtrack result = context.service().setStorySoundtrack(
                command(TRACK_ID)
        );

        assertThat(result.selectedSoundtrack()).isSameAs(track);
        assertThat(context.storyRepository().updateCallCount()).isEqualTo(1);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyRolesThatCannotChangeSoundtrack(StoryRole role) {
        TestContext context = testContext(userStory(null, role));

        assertStoryNotFound(() -> context.service().setStorySoundtrack(
                command(TRACK_ID)
        ));

        assertThat(context.musicTrackRepository().findByIdCallCount())
                .isZero();
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldThrowStoryNotFoundForMissingOrInaccessibleStory() {
        TestContext context = testContext(Optional.empty());

        assertStoryNotFound(() -> context.service().setStorySoundtrack(
                command(TRACK_ID)
        ));

        assertThat(context.musicTrackRepository().findByIdCallCount())
                .isZero();
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldRejectMissingTrack() {
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.empty());

        assertThatThrownBy(() -> context.service().setStorySoundtrack(
                command(TRACK_ID)
        )).isInstanceOf(StorySoundtrackUnavailableException.class)
                .hasMessage("Story soundtrack could not be updated");
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldRejectDisabledTrack() {
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(disabledTrack()));

        assertThatThrownBy(() -> context.service().setStorySoundtrack(
                command(TRACK_ID)
        )).isInstanceOf(StorySoundtrackUnavailableException.class)
                .hasMessage("Story soundtrack could not be updated");
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldPreserveNonSoundtrackStoryFields() {
        TestContext context = testContext(
                userStory(OTHER_TRACK_ID, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(activeTrack(TRACK_ID)));

        context.service().setStorySoundtrack(command(TRACK_ID));

        Story updated = context.storyRepository().updatedStory();
        assertThat(updated.id()).isEqualTo(STORY_ID);
        assertThat(updated.ownerId()).isEqualTo(OWNER_ID);
        assertThat(updated.title()).isEqualTo("Our Story");
        assertThat(updated.description()).isEqualTo("The beginning");
        assertThat(updated.soundtrackId()).isEqualTo(TRACK_ID);
        assertThat(updated.createdAt()).isEqualTo(CREATED_AT);
        assertThat(updated.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldTreatSameSelectedActiveTrackAsNoOp() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        MusicTrack track = activeTrack(TRACK_ID);
        context.musicTrackRepository().track(Optional.of(track));

        StorySoundtrack result = context.service().setStorySoundtrack(
                command(TRACK_ID)
        );

        assertThat(result.selectedSoundtrack()).isSameAs(track);
        assertThat(result.effectiveSoundtrack()).isSameAs(track);
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldPropagateLookupRepositoryFailure() {
        RuntimeException failure = new RuntimeException("lookup failed");
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );
        context.userStoryRepository().failWith(failure);

        assertThatThrownBy(() -> context.service().setStorySoundtrack(
                command(TRACK_ID)
        )).isSameAs(failure);
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldPropagateTrackRepositoryFailure() {
        RuntimeException failure = new RuntimeException("track failed");
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );
        context.musicTrackRepository().failWith(failure);

        assertThatThrownBy(() -> context.service().setStorySoundtrack(
                command(TRACK_ID)
        )).isSameAs(failure);
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldPropagateStoryUpdateFailure() {
        RuntimeException failure = new RuntimeException("update failed");
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(activeTrack(TRACK_ID)));
        context.storyRepository().failOnUpdate(failure);

        assertThatThrownBy(() -> context.service().setStorySoundtrack(
                command(TRACK_ID)
        )).isSameAs(failure);
    }

    @Test
    void shouldLookupStoryThenTrackThenUpdate() {
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(activeTrack(TRACK_ID)));

        context.service().setStorySoundtrack(command(TRACK_ID));

        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "find MusicTrack",
                "update Story"
        );
    }

    @Test
    void shouldRejectNullDependencies() {
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );

        assertThatThrownBy(() -> new TransactionalSetStorySoundtrackService(
                null,
                context.storyRepository(),
                context.musicTrackRepository(),
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");

        assertThatThrownBy(() -> new TransactionalSetStorySoundtrackService(
                context.userStoryRepository(),
                null,
                context.musicTrackRepository(),
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");

        assertThatThrownBy(() -> new TransactionalSetStorySoundtrackService(
                context.userStoryRepository(),
                context.storyRepository(),
                null,
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrackRepository must not be null");

        assertThatThrownBy(() -> new TransactionalSetStorySoundtrackService(
                context.userStoryRepository(),
                context.storyRepository(),
                context.musicTrackRepository(),
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyAccessPolicy must not be null");
    }

    @Test
    void shouldRejectNullCommand() {
        assertThatThrownBy(() -> testContext(
                userStory(null, StoryRole.OWNER)
        ).service().setStorySoundtrack(null))
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
        FakeMusicTrackRepository musicTrackRepository =
                new FakeMusicTrackRepository(calls);

        return new TestContext(
                new TransactionalSetStorySoundtrackService(
                        userStoryRepository,
                        storyRepository,
                        musicTrackRepository,
                        new StoryAccessPolicy()
                ),
                userStoryRepository,
                storyRepository,
                musicTrackRepository,
                calls
        );
    }

    private static SetStorySoundtrackCommand command(UUID musicTrackId) {
        return new SetStorySoundtrackCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                musicTrackId,
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

    private static MusicTrack activeTrack(UUID id) {
        return musicTrack(id, MusicTrackStatus.ACTIVE);
    }

    private static MusicTrack disabledTrack() {
        return musicTrack(TRACK_ID, MusicTrackStatus.DISABLED);
    }

    private static MusicTrack musicTrack(UUID id, MusicTrackStatus status) {
        return new MusicTrack(
                id,
                "Calm Piano",
                "Memory Story",
                180,
                status,
                0,
                "music/" + id + ".mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private record TestContext(

            TransactionalSetStorySoundtrackService service,

            FakeUserStoryRepository userStoryRepository,

            FakeStoryRepository storyRepository,

            FakeMusicTrackRepository musicTrackRepository,

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

    private static final class FakeMusicTrackRepository
            implements MusicTrackRepository {

        private final List<String> calls;
        private Optional<MusicTrack> track = Optional.empty();
        private UUID receivedId;
        private int findByIdCallCount;
        private RuntimeException failure;

        private FakeMusicTrackRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Optional<MusicTrack> findById(UUID id) {
            calls.add("find MusicTrack");
            receivedId = id;
            findByIdCallCount++;

            if (failure != null) {
                throw failure;
            }

            return track;
        }

        @Override
        public List<MusicTrack> findActive() {
            throw new UnsupportedOperationException();
        }

        private void track(Optional<MusicTrack> track) {
            this.track = track;
        }

        private UUID receivedId() {
            return receivedId;
        }

        private int findByIdCallCount() {
            return findByIdCallCount;
        }

        private void failWith(RuntimeException failure) {
            this.failure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
