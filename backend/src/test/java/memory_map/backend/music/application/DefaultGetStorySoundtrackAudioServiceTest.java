package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
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
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultGetStorySoundtrackAudioServiceTest {

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
    private static final byte[] FULL_AUDIO = new byte[] {1, 2, 3, 4};
    private static final byte[] RANGED_AUDIO = new byte[] {2, 3};

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldReadFullActiveSoundtrackForEveryParticipantRole(
            StoryRole role
    ) throws Exception {
        TestContext context = testContext(userStory(TRACK_ID, role));
        context.musicTrackRepository().track(Optional.of(
                musicTrack(MusicTrackStatus.ACTIVE, 4_096L)
        ));

        StorySoundtrackAudio result =
                context.service().getStorySoundtrackAudio(
                        authenticatedUser(),
                        STORY_ID,
                        null
                );

        assertThat(result.content().readAllBytes()).containsExactly(
                FULL_AUDIO
        );
        assertThat(result.contentType()).isEqualTo("audio/mpeg");
        assertThat(result.contentLength()).isEqualTo(4_096L);
        assertThat(result.totalLength()).isEqualTo(4_096L);
        assertThat(result.range()).isNull();
        assertThat(context.storageService().requestedFullReadKey())
                .isEqualTo(new StorageKey("music/calm-piano.mp3"));
        assertThat(context.storageService().readCount()).isEqualTo(1);
        assertThat(context.storageService().readRangeCount()).isZero();
        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "find MusicTrack",
                "storage.read"
        );
    }

    @Test
    void shouldReadNormalizedRangeUsingTrustedStorageKeyAndDatabaseMetadata()
            throws Exception {

        StorySoundtrackAudioRange range =
                StorySoundtrackAudioRange.startEnd(1L, 2L);
        StorageByteRange normalizedRange = new StorageByteRange(1L, 2L);
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.VIEWER)
        );
        context.musicTrackRepository().track(Optional.of(
                musicTrack(MusicTrackStatus.ACTIVE, 4_096L)
        ));
        context.storageService().rangedStoredObject(new StoredObject(
                new ByteArrayInputStream(RANGED_AUDIO),
                999L,
                "application/octet-stream"
        ));

        StorySoundtrackAudio result =
                context.service().getStorySoundtrackAudio(
                        authenticatedUser(),
                        STORY_ID,
                        range
                );

        assertThat(result.content().readAllBytes()).containsExactly(
                RANGED_AUDIO
        );
        assertThat(result.contentType()).isEqualTo("audio/mpeg");
        assertThat(result.contentLength()).isEqualTo(2L);
        assertThat(result.totalLength()).isEqualTo(4_096L);
        assertThat(result.range()).isEqualTo(normalizedRange);
        assertThat(context.storageService().requestedRangedReadKey())
                .isEqualTo(new StorageKey("music/calm-piano.mp3"));
        assertThat(context.storageService().requestedRange())
                .isEqualTo(normalizedRange);
        assertThat(context.storageService().readCount()).isZero();
        assertThat(context.storageService().readRangeCount()).isEqualTo(1);
        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "find MusicTrack",
                "storage.readRange"
        );
    }

    @Test
    void shouldRejectMissingOrInaccessibleStoryBeforeMusicOrStorageLookup() {
        TestContext context = testContext(Optional.empty());

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                null
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(context.calls()).containsExactly("find UserStory");
        assertThat(context.musicTrackRepository().findByIdCallCount())
                .isZero();
        assertThat(context.storageService().readCount()).isZero();
        assertThat(context.storageService().readRangeCount()).isZero();
    }

    @Test
    void shouldRejectStoryWithoutSelectedSoundtrackBeforeTrackLookup() {
        TestContext context = testContext(
                userStory(null, StoryRole.OWNER)
        );

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                null
        )).isInstanceOf(StorySoundtrackAudioUnavailableException.class)
                .hasMessage("Story soundtrack audio could not be found");

        assertThat(context.calls()).containsExactly("find UserStory");
        assertThat(context.musicTrackRepository().findByIdCallCount())
                .isZero();
        assertThat(context.storageService().readCount()).isZero();
    }

    @Test
    void shouldRejectDisabledSelectedTrackBeforeStorageLookup() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.EDITOR)
        );
        context.musicTrackRepository().track(Optional.of(
                musicTrack(MusicTrackStatus.DISABLED, 4_096L)
        ));

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                null
        )).isInstanceOf(StorySoundtrackAudioUnavailableException.class)
                .hasMessage("Story soundtrack audio could not be found");

        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "find MusicTrack"
        );
        assertThat(context.storageService().readCount()).isZero();
        assertThat(context.storageService().readRangeCount()).isZero();
    }

    @Test
    void shouldNotTreatMissingReferencedTrackAsNoMusic() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.empty());

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                null
        )).isInstanceOf(IllegalStateException.class)
                .hasMessage("Selected Story soundtrack could not be resolved");

        assertThat(context.storageService().readCount()).isZero();
        assertThat(context.storageService().readRangeCount()).isZero();
    }

    @Test
    void shouldRejectUnsatisfiableRangeBeforeStorageLookup() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(
                musicTrack(MusicTrackStatus.ACTIVE, 4_096L)
        ));

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                StorySoundtrackAudioRange.openEnded(4_096L)
        )).isInstanceOf(InvalidStorySoundtrackAudioRangeException.class)
                .hasMessage("Story soundtrack audio range is invalid");

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                StorySoundtrackAudioRange.startEnd(4_096L, 4_097L)
        )).isInstanceOf(InvalidStorySoundtrackAudioRangeException.class)
                .hasMessage("Story soundtrack audio range is invalid");

        assertThat(context.storageService().readCount()).isZero();
        assertThat(context.storageService().readRangeCount()).isZero();
    }

    @Test
    void shouldProtectRangeValidationFromOverflowBeforeStorageLookup() {
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(
                musicTrack(MusicTrackStatus.ACTIVE, 4_096L)
        ));

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                StorySoundtrackAudioRange.openEnded(Long.MAX_VALUE)
        )).isInstanceOf(InvalidStorySoundtrackAudioRangeException.class)
                .hasMessage("Story soundtrack audio range is invalid");

        assertThat(context.storageService().readCount()).isZero();
        assertThat(context.storageService().readRangeCount()).isZero();
    }

    @Test
    void shouldPropagateMissingStorageObjectAsIntegrityMismatch() {
        StorageObjectNotFoundException failure =
                new StorageObjectNotFoundException();
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(
                musicTrack(MusicTrackStatus.ACTIVE, 4_096L)
        ));
        context.storageService().failure(failure);

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                null
        )).isSameAs(failure);
    }

    @Test
    void shouldPropagateTechnicalStorageFailure() {
        StorageException failure = new StorageException();
        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );
        context.musicTrackRepository().track(Optional.of(
                musicTrack(MusicTrackStatus.ACTIVE, 4_096L)
        ));
        context.storageService().failure(failure);

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                STORY_ID,
                StorySoundtrackAudioRange.startEnd(0L, 0L)
        )).isSameAs(failure);
    }

    @Test
    void shouldRejectNullDependenciesAndInputs() {
        List<String> calls = new ArrayList<>();
        FakeUserStoryRepository userStoryRepository =
                new FakeUserStoryRepository(Optional.empty(), calls);
        FakeMusicTrackRepository musicTrackRepository =
                new FakeMusicTrackRepository(calls);
        StoryAccessPolicy storyAccessPolicy = new StoryAccessPolicy();
        FakeStorageService storageService = new FakeStorageService(calls);

        assertThatThrownBy(() -> new DefaultGetStorySoundtrackAudioService(
                null,
                musicTrackRepository,
                storyAccessPolicy,
                storageService
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");

        assertThatThrownBy(() -> new DefaultGetStorySoundtrackAudioService(
                userStoryRepository,
                null,
                storyAccessPolicy,
                storageService
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrackRepository must not be null");

        assertThatThrownBy(() -> new DefaultGetStorySoundtrackAudioService(
                userStoryRepository,
                musicTrackRepository,
                null,
                storageService
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyAccessPolicy must not be null");

        assertThatThrownBy(() -> new DefaultGetStorySoundtrackAudioService(
                userStoryRepository,
                musicTrackRepository,
                storyAccessPolicy,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");

        TestContext context = testContext(
                userStory(TRACK_ID, StoryRole.OWNER)
        );

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                null,
                STORY_ID,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");

        assertThatThrownBy(() -> context.service().getStorySoundtrackAudio(
                authenticatedUser(),
                null,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
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
        FakeStorageService storageService = new FakeStorageService(calls);

        return new TestContext(
                new DefaultGetStorySoundtrackAudioService(
                        userStoryRepository,
                        musicTrackRepository,
                        new StoryAccessPolicy(),
                        storageService
                ),
                musicTrackRepository,
                storageService,
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

    private static MusicTrack musicTrack(
            MusicTrackStatus status,
            long fileSize
    ) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                status,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                fileSize,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static AuthenticatedUser authenticatedUser() {
        return new AuthenticatedUser(USER_ID);
    }

    private record TestContext(

            DefaultGetStorySoundtrackAudioService service,

            FakeMusicTrackRepository musicTrackRepository,

            FakeStorageService storageService,

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
        private int findByIdCallCount;

        private FakeMusicTrackRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Optional<MusicTrack> findById(UUID id) {
            calls.add("find MusicTrack");
            findByIdCallCount++;
            assertThat(id).isEqualTo(TRACK_ID);

            return track;
        }

        @Override
        public List<MusicTrack> findActive() {
            throw new UnsupportedOperationException();
        }

        private void track(Optional<MusicTrack> track) {
            this.track = track;
        }

        private int findByIdCallCount() {
            return findByIdCallCount;
        }
    }

    private static final class FakeStorageService implements StorageService {

        private final List<String> calls;
        private StoredObject fullStoredObject = new StoredObject(
                new ByteArrayInputStream(FULL_AUDIO),
                FULL_AUDIO.length,
                "application/octet-stream"
        );
        private StoredObject rangedStoredObject = new StoredObject(
                new ByteArrayInputStream(RANGED_AUDIO),
                RANGED_AUDIO.length,
                "application/octet-stream"
        );
        private RuntimeException failure;
        private StorageKey requestedFullReadKey;
        private StorageKey requestedRangedReadKey;
        private StorageByteRange requestedRange;
        private int readCount;
        private int readRangeCount;

        private FakeStorageService(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public void store(StorageObjectWrite object) {
            throw new UnsupportedOperationException();
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            calls.add("storage.read");
            requestedFullReadKey = storageKey;
            readCount++;

            if (failure != null) {
                throw failure;
            }

            return fullStoredObject;
        }

        @Override
        public StoredObject readRange(
                StorageKey storageKey,
                StorageByteRange range
        ) {
            calls.add("storage.readRange");
            requestedRangedReadKey = storageKey;
            requestedRange = range;
            readRangeCount++;

            if (failure != null) {
                throw failure;
            }

            return rangedStoredObject;
        }

        @Override
        public void delete(StorageKey storageKey) {
            throw new UnsupportedOperationException();
        }

        private void failure(RuntimeException failure) {
            this.failure = failure;
        }

        private void rangedStoredObject(StoredObject rangedStoredObject) {
            this.rangedStoredObject = rangedStoredObject;
        }

        private StorageKey requestedFullReadKey() {
            return requestedFullReadKey;
        }

        private StorageKey requestedRangedReadKey() {
            return requestedRangedReadKey;
        }

        private StorageByteRange requestedRange() {
            return requestedRange;
        }

        private int readCount() {
            return readCount;
        }

        private int readRangeCount() {
            return readRangeCount;
        }
    }
}
