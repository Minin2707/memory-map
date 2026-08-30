package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
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

class DefaultDownloadStoryCoverServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final byte[] STORED_BYTES = new byte[] {1, 2, 3};

    private final List<String> events = new ArrayList<>();
    private final FakeStoryRepository storyRepository =
            new FakeStoryRepository(events);
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository(events);
    private final FakeStorageService storageService =
            new FakeStorageService(events);
    private final DefaultDownloadStoryCoverService service =
            new DefaultDownloadStoryCoverService(
                    storyRepository,
                    storyParticipantRepository,
                    storageService,
                    new StoryAccessPolicy()
            );

    @Test
    void shouldDownloadDisplayUsingExplicitStoryCoverMetadata()
            throws Exception {
        storageService.storedObject = new StoredObject(
                new ByteArrayInputStream(STORED_BYTES),
                999L,
                "application/octet-stream"
        );

        DownloadedStoryCover result = service.downloadStoryCover(
                user(),
                STORY_ID,
                StoryCoverRepresentation.DISPLAY
        );

        assertThat(result.content().readAllBytes())
                .containsExactly(STORED_BYTES);
        assertThat(result.contentLength()).isEqualTo(2_048L);
        assertThat(result.contentType()).isEqualTo("image/jpeg");
        assertThat(storageService.requestedKey)
                .isEqualTo(new StorageKey("stories/story/display.jpg"));
        assertThat(storyRepository.requestedId).isEqualTo(STORY_ID);
        assertThat(storyParticipantRepository.requestedStoryId)
                .isEqualTo(STORY_ID);
        assertThat(storyParticipantRepository.requestedUserId)
                .isEqualTo(USER_ID);
        assertThat(events).containsExactly(
                "story.findById",
                "participant.find",
                "storage.read"
        );
    }

    @Test
    void shouldDownloadThumbnailUsingExplicitStoryCoverMetadata()
            throws Exception {
        DownloadedStoryCover result = service.downloadStoryCover(
                user(),
                STORY_ID,
                StoryCoverRepresentation.THUMBNAIL
        );

        assertThat(result.content().readAllBytes())
                .containsExactly(STORED_BYTES);
        assertThat(result.contentLength()).isEqualTo(360L);
        assertThat(result.contentType()).isEqualTo("image/jpeg");
        assertThat(storageService.requestedKey)
                .isEqualTo(new StorageKey("stories/story/thumbnail.jpg"));
        assertThat(events).containsExactly(
                "story.findById",
                "participant.find",
                "storage.read"
        );
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldAllowAnyStoryParticipantRoleToReadCover(StoryRole role) {
        storyParticipantRepository.participant = Optional.of(participant(role));

        DownloadedStoryCover result = service.downloadStoryCover(
                user(),
                STORY_ID,
                StoryCoverRepresentation.DISPLAY
        );

        assertThat(result.contentLength()).isEqualTo(2_048L);
        assertThat(storageService.callCount).isEqualTo(1);
    }

    @Test
    void shouldConcealMissingStoryBeforeParticipantAndStorageLookup() {
        storyRepository.story = Optional.empty();

        assertThatThrownBy(() -> service.downloadStoryCover(
                user(),
                STORY_ID,
                StoryCoverRepresentation.DISPLAY
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(events).containsExactly("story.findById");
        assertThat(storyParticipantRepository.callCount).isZero();
        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldConcealNonParticipantBeforeStorageLookup() {
        storyParticipantRepository.participant = Optional.empty();

        assertThatThrownBy(() -> service.downloadStoryCover(
                user(),
                STORY_ID,
                StoryCoverRepresentation.DISPLAY
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(events).containsExactly("story.findById", "participant.find");
        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldReturnNotFoundWhenStoryHasNoExplicitCover() {
        storyRepository.story = Optional.of(story(null));

        assertThatThrownBy(() -> service.downloadStoryCover(
                user(),
                STORY_ID,
                StoryCoverRepresentation.DISPLAY
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(events).containsExactly("story.findById", "participant.find");
        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldPropagateMissingStorageObjectAsTechnicalFailure() {
        StorageObjectNotFoundException failure =
                new StorageObjectNotFoundException();
        storageService.failure = failure;

        assertThatThrownBy(() -> service.downloadStoryCover(
                user(),
                STORY_ID,
                StoryCoverRepresentation.DISPLAY
        )).isSameAs(failure);
    }

    @Test
    void shouldPropagateStorageFailure() {
        StorageException failure = new StorageException();
        storageService.failure = failure;

        assertThatThrownBy(() -> service.downloadStoryCover(
                user(),
                STORY_ID,
                StoryCoverRepresentation.DISPLAY
        )).isSameAs(failure);
    }

    @Test
    void shouldRejectNullDependenciesAndInputs() {
        assertThatThrownBy(() -> new DefaultDownloadStoryCoverService(
                null,
                storyParticipantRepository,
                storageService,
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");
        assertThatThrownBy(() -> new DefaultDownloadStoryCoverService(
                storyRepository,
                null,
                storageService,
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
        assertThatThrownBy(() -> new DefaultDownloadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                null,
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");
        assertThatThrownBy(() -> new DefaultDownloadStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                storageService,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("accessPolicy must not be null");
        assertThatThrownBy(() -> service.downloadStoryCover(
                null,
                STORY_ID,
                StoryCoverRepresentation.DISPLAY
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
        assertThatThrownBy(() -> service.downloadStoryCover(
                user(),
                null,
                StoryCoverRepresentation.DISPLAY
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
        assertThatThrownBy(() -> service.downloadStoryCover(
                user(),
                STORY_ID,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("representation must not be null");
    }

    private static AuthenticatedUser user() {
        return new AuthenticatedUser(USER_ID);
    }

    private static Story story(StoryCoverMetadata cover) {
        return new Story(
                STORY_ID,
                OWNER_ID,
                "Our story",
                "Private archive",
                null,
                cover,
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    private static StoryCoverMetadata cover() {
        return new StoryCoverMetadata(
                "stories/story/display.jpg",
                2_048L,
                "stories/story/thumbnail.jpg",
                360L,
                "image/jpeg",
                CURRENT_TIME
        );
    }

    private static StoryParticipant participant(StoryRole role) {
        return new StoryParticipant(
                STORY_ID,
                USER_ID,
                role,
                CURRENT_TIME
        );
    }

    private static final class FakeStoryRepository implements StoryRepository {

        private final List<String> events;
        private Optional<Story> story = Optional.of(story(cover()));
        private UUID requestedId;

        private FakeStoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Story save(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Story update(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Story> findById(UUID id) {
            events.add("story.findById");
            requestedId = id;
            return story;
        }

        @Override
        public boolean lockById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> events;
        private Optional<StoryParticipant> participant =
                Optional.of(participant(StoryRole.VIEWER));
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

    private static final class FakeStorageService implements StorageService {

        private final List<String> events;
        private StoredObject storedObject = new StoredObject(
                new ByteArrayInputStream(STORED_BYTES),
                STORED_BYTES.length,
                "image/jpeg"
        );
        private RuntimeException failure;
        private StorageKey requestedKey;
        private int callCount;

        private FakeStorageService(List<String> events) {
            this.events = events;
        }

        @Override
        public void store(StorageObjectWrite object) {
            throw new UnsupportedOperationException();
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            events.add("storage.read");
            requestedKey = storageKey;
            callCount++;

            if (failure != null) {
                throw failure;
            }

            return storedObject;
        }

        @Override
        public StoredObject readRange(
                StorageKey storageKey,
                StorageByteRange range
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(StorageKey storageKey) {
            throw new UnsupportedOperationException();
        }
    }
}
