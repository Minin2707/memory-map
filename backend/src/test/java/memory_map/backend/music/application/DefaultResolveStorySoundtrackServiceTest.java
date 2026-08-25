package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.music.repository.MusicTrackRepository;
import memory_map.backend.story.application.StoryAccessPolicy;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultResolveStorySoundtrackServiceTest {

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

    @Test
    void shouldReturnNoMusicWhenStoryHasNoSelectedSoundtrack() {
        TestContext context = testContext(userStory(null, StoryRole.VIEWER));

        StorySoundtrack result = context.service().resolveStorySoundtrack(
                authenticatedUser(),
                STORY_ID
        );

        assertThat(result).isEqualTo(StorySoundtrack.noMusic());
        assertThat(context.musicTrackRepository().findByIdCallCount())
                .isZero();
    }

    @Test
    void shouldReturnSelectedAndEffectiveWhenSelectedTrackIsActive() {
        MusicTrack active = musicTrack(MusicTrackStatus.ACTIVE);
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.EDITOR)
        );
        context.musicTrackRepository().track(Optional.of(active));

        StorySoundtrack result = context.service().resolveStorySoundtrack(
                authenticatedUser(),
                STORY_ID
        );

        assertThat(result.selectedSoundtrack()).isSameAs(active);
        assertThat(result.effectiveSoundtrack()).isSameAs(active);
        assertThat(context.musicTrackRepository().receivedId())
                .isEqualTo(TRACK_ID);
    }

    @Test
    void shouldReturnSelectedOnlyWhenSelectedTrackIsDisabled() {
        MusicTrack disabled = musicTrack(MusicTrackStatus.DISABLED);
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.VIEWER)
        );
        context.musicTrackRepository().track(Optional.of(disabled));

        StorySoundtrack result = context.service().resolveStorySoundtrack(
                authenticatedUser(),
                STORY_ID
        );

        assertThat(result.selectedSoundtrack()).isSameAs(disabled);
        assertThat(result.effectiveSoundtrack()).isNull();
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryIsMissingOrInaccessible() {
        TestContext context = testContext(Optional.empty());

        assertThatThrownBy(() -> context.service().resolveStorySoundtrack(
                authenticatedUser(),
                STORY_ID
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
        assertThat(context.musicTrackRepository().findByIdCallCount())
                .isZero();
    }

    @Test
    void shouldNotTreatMissingReferencedTrackAsNoMusic() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.empty());

        assertThatThrownBy(() -> context.service().resolveStorySoundtrack(
                authenticatedUser(),
                STORY_ID
        )).isInstanceOf(IllegalStateException.class)
                .hasMessage("Selected Story soundtrack could not be resolved");
    }

    @Test
    void shouldRejectNullDependencies() {
        FakeUserStoryRepository userStoryRepository =
                new FakeUserStoryRepository(Optional.empty(), new ArrayList<>());
        FakeMusicTrackRepository musicTrackRepository =
                new FakeMusicTrackRepository(new ArrayList<>());
        StoryAccessPolicy storyAccessPolicy = new StoryAccessPolicy();

        assertThatThrownBy(() -> new DefaultResolveStorySoundtrackService(
                null,
                musicTrackRepository,
                storyAccessPolicy
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");

        assertThatThrownBy(() -> new DefaultResolveStorySoundtrackService(
                userStoryRepository,
                null,
                storyAccessPolicy
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrackRepository must not be null");

        assertThatThrownBy(() -> new DefaultResolveStorySoundtrackService(
                userStoryRepository,
                musicTrackRepository,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyAccessPolicy must not be null");
    }

    @Test
    void shouldRejectNullInputs() {
        TestContext context = testContext(userStory(null, StoryRole.OWNER));

        assertThatThrownBy(() -> context.service().resolveStorySoundtrack(
                null,
                STORY_ID
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");

        assertThatThrownBy(() -> context.service().resolveStorySoundtrack(
                authenticatedUser(),
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldLookupStoryBeforeMusicTrack() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(
                musicTrack(MusicTrackStatus.ACTIVE)
        ));

        context.service().resolveStorySoundtrack(authenticatedUser(), STORY_ID);

        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "find MusicTrack"
        );
    }

    private static TestContext testContext(UserStory userStory) {
        return testContext(Optional.of(userStory));
    }

    private static TestContext testContext(Optional<UserStory> userStory) {
        List<String> calls = new ArrayList<>();
        FakeUserStoryRepository userStoryRepository =
                new FakeUserStoryRepository(userStory, calls);
        FakeMusicTrackRepository musicTrackRepository =
                new FakeMusicTrackRepository(calls);

        return new TestContext(
                new DefaultResolveStorySoundtrackService(
                        userStoryRepository,
                        musicTrackRepository,
                        new StoryAccessPolicy()
                ),
                musicTrackRepository,
                calls
        );
    }

    private static UserStory userStory(UUID soundtrackId, StoryRole role) {
        return new UserStory(
                new Story(
                        STORY_ID,
                        OWNER_ID,
                        "Our Story",
                        "The beginning",
                        soundtrackId,
                        CREATED_AT,
                        UPDATED_AT
                ),
                role
        );
    }

    private static MusicTrack musicTrack(MusicTrackStatus status) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                status,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static AuthenticatedUser authenticatedUser() {
        return new AuthenticatedUser(USER_ID);
    }

    private record TestContext(

            DefaultResolveStorySoundtrackService service,

            FakeMusicTrackRepository musicTrackRepository,

            List<String> calls

    ) {
    }

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        private final Optional<UserStory> userStory;
        private final List<String> calls;

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
            assertThat(storyId).isEqualTo(STORY_ID);
            assertThat(userId).isEqualTo(USER_ID);

            return userStory;
        }
    }

    private static final class FakeMusicTrackRepository
            implements MusicTrackRepository {

        private final List<String> calls;
        private Optional<MusicTrack> track = Optional.empty();
        private UUID receivedId;
        private int findByIdCallCount;

        private FakeMusicTrackRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Optional<MusicTrack> findById(UUID id) {
            calls.add("find MusicTrack");
            receivedId = id;
            findByIdCallCount++;
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
    }
}
