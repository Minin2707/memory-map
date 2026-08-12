package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalListMemoryMediaServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    private final List<String> events = new ArrayList<>();
    private final FakeMemoryRepository memoryRepository =
            new FakeMemoryRepository(events);
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository(events);
    private final FakeMediaFileRepository mediaFileRepository =
            new FakeMediaFileRepository(events);
    private final TransactionalListMemoryMediaService service =
            new TransactionalListMemoryMediaService(
                    memoryRepository,
                    storyParticipantRepository,
                    mediaFileRepository
            );

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldAllowEveryCurrentParticipantRole(StoryRole role) {
        storyParticipantRepository.participant = Optional.of(participant(role));

        List<MediaFile> result = service.listMedia(user(), MEMORY_ID);

        assertThat(result).containsExactly(mediaFile(MEDIA_ID), mediaFile(
                SECOND_MEDIA_ID
        ));
        assertThat(memoryRepository.requestedId).isEqualTo(MEMORY_ID);
        assertThat(storyParticipantRepository.requestedStoryId)
                .isEqualTo(STORY_ID);
        assertThat(storyParticipantRepository.requestedUserId)
                .isEqualTo(USER_ID);
        assertThat(mediaFileRepository.requestedMemoryId)
                .isEqualTo(MEMORY_ID);
        assertThat(events).containsExactly(
                "memory.findById",
                "participant.find",
                "media.findByMemoryId"
        );
    }

    @Test
    void shouldReturnEmptyAuthorizedList() {
        mediaFileRepository.mediaFiles = List.of();

        List<MediaFile> result = service.listMedia(user(), MEMORY_ID);

        assertThat(result).isEmpty();
        assertThat(events).containsExactly(
                "memory.findById",
                "participant.find",
                "media.findByMemoryId"
        );
    }

    @Test
    void shouldDenyMissingMemoryBeforeParticipantOrMediaLookup() {
        memoryRepository.memory = Optional.empty();

        assertThatThrownBy(() -> service.listMedia(user(), MEMORY_ID))
                .isInstanceOf(MediaUnavailableException.class)
                .hasMessage("Media could not be found");

        assertThat(events).containsExactly("memory.findById");
        assertThat(storyParticipantRepository.callCount).isZero();
        assertThat(mediaFileRepository.callCount).isZero();
    }

    @Test
    void shouldDenyMissingParticipantBeforeMediaLookup() {
        storyParticipantRepository.participant = Optional.empty();

        assertThatThrownBy(() -> service.listMedia(user(), MEMORY_ID))
                .isInstanceOf(MediaUnavailableException.class);

        assertThat(events).containsExactly(
                "memory.findById",
                "participant.find"
        );
        assertThat(mediaFileRepository.callCount).isZero();
    }

    @Test
    void shouldDenyWrongParticipantProjectionBeforeMediaLookup() {
        storyParticipantRepository.participant = Optional.of(
                new StoryParticipant(OTHER_STORY_ID, USER_ID, StoryRole.OWNER,
                        BASE_TIME)
        );

        assertThatThrownBy(() -> service.listMedia(user(), MEMORY_ID))
                .isInstanceOf(MediaUnavailableException.class);

        assertThat(events).containsExactly(
                "memory.findById",
                "participant.find"
        );
        assertThat(mediaFileRepository.callCount).isZero();
    }

    @Test
    void shouldPropagateRepositoryFailures() {
        RuntimeException failure = new RuntimeException("database unavailable");
        mediaFileRepository.failure = failure;

        assertThatThrownBy(() -> service.listMedia(user(), MEMORY_ID))
                .isSameAs(failure);
    }

    @Test
    void shouldRejectNullDependenciesAndInputs() {
        assertThatThrownBy(() -> new TransactionalListMemoryMediaService(
                null,
                storyParticipantRepository,
                mediaFileRepository
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("memoryRepository must not be null");
        assertThatThrownBy(() -> new TransactionalListMemoryMediaService(
                memoryRepository,
                null,
                mediaFileRepository
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
        assertThatThrownBy(() -> new TransactionalListMemoryMediaService(
                memoryRepository,
                storyParticipantRepository,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mediaFileRepository must not be null");
        assertThatThrownBy(() -> service.listMedia(null, MEMORY_ID))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
        assertThatThrownBy(() -> service.listMedia(user(), null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");
    }

    private static AuthenticatedUser user() {
        return new AuthenticatedUser(USER_ID);
    }

    private static StoryParticipant participant(StoryRole role) {
        return new StoryParticipant(STORY_ID, USER_ID, role, BASE_TIME);
    }

    private static Memory memory() {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                USER_ID,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );
    }

    private static MediaFile mediaFile(UUID id) {
        return new MediaFile(
                id,
                MEMORY_ID,
                MediaType.PHOTO,
                "media/" + id + "/display",
                1_024L,
                "media/" + id + "/thumbnail",
                128L,
                "image/jpeg",
                BASE_TIME
        );
    }

    private static final class FakeMemoryRepository
            implements MemoryRepository {

        private final List<String> events;
        private Optional<Memory> memory = Optional.of(memory());
        private UUID requestedId;

        private FakeMemoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            events.add("memory.findById");
            requestedId = id;
            return memory;
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Memory> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(Memory memory) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean update(Memory memory) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean delete(UUID id) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> events;
        private Optional<StoryParticipant> participant =
                Optional.of(participant(StoryRole.OWNER));
        private UUID requestedStoryId;
        private UUID requestedUserId;
        private int callCount;

        private FakeStoryParticipantRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            events.add("participant.find");
            requestedStoryId = storyId;
            requestedUserId = userId;
            callCount++;
            return participant;
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public long countOwners(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void update(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeMediaFileRepository
            implements MediaFileRepository {

        private final List<String> events;
        private List<MediaFile> mediaFiles = List.of(
                mediaFile(MEDIA_ID),
                mediaFile(SECOND_MEDIA_ID)
        );
        private RuntimeException failure;
        private UUID requestedMemoryId;
        private int callCount;

        private FakeMediaFileRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<MediaFile> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<MediaFile> findByMemoryId(UUID memoryId) {
            events.add("media.findByMemoryId");
            requestedMemoryId = memoryId;
            callCount++;

            if (failure != null) {
                throw failure;
            }

            return mediaFiles;
        }

        @Override
        public void save(MediaFile mediaFile) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID id) {
            throw new UnsupportedOperationException();
        }
    }
}
