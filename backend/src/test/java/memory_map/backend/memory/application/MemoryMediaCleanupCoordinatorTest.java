package memory_map.backend.memory.application;

import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageKey;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MemoryMediaCleanupCoordinatorTest {

    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final UUID THIRD_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000033");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    private final FakeMediaFileRepository mediaFileRepository =
            new FakeMediaFileRepository();
    private final FakeStorageCleanupScheduler cleanupScheduler =
            new FakeStorageCleanupScheduler();

    @Test
    void shouldSkipCallbackWhenMemoryHasNoMedia() {
        StorageBackedMemoryMediaCleanupCoordinator coordinator =
                storageBackedCoordinator();

        coordinator.scheduleCleanup(MEMORY_ID);

        assertThat(mediaFileRepository.requestedMemoryId).isEqualTo(MEMORY_ID);
        assertThat(cleanupScheduler.scheduledKeys).isEmpty();
    }

    @Test
    void shouldCaptureOneMediaAndScheduleThumbnailThenDisplayCleanup() {
        mediaFileRepository.mediaFiles = List.of(mediaFile(MEDIA_ID));
        StorageBackedMemoryMediaCleanupCoordinator coordinator =
                storageBackedCoordinator();

        coordinator.scheduleCleanup(MEMORY_ID);

        assertThat(cleanupScheduler.scheduledKeys).containsExactly(
                thumbnailKey(MEDIA_ID),
                displayKey(MEDIA_ID)
        );
    }

    @Test
    void shouldCaptureMultipleMediaInRepositoryOrder() {
        mediaFileRepository.mediaFiles = List.of(
                mediaFile(MEDIA_ID),
                mediaFile(SECOND_MEDIA_ID),
                mediaFile(THIRD_MEDIA_ID)
        );
        StorageBackedMemoryMediaCleanupCoordinator coordinator =
                storageBackedCoordinator();

        coordinator.scheduleCleanup(MEMORY_ID);

        assertThat(cleanupScheduler.scheduledKeys).containsExactly(
                thumbnailKey(MEDIA_ID),
                displayKey(MEDIA_ID),
                thumbnailKey(SECOND_MEDIA_ID),
                displayKey(SECOND_MEDIA_ID),
                thumbnailKey(THIRD_MEDIA_ID),
                displayKey(THIRD_MEDIA_ID)
        );
    }

    @Test
    void shouldPropagateCleanupSchedulingFailure() {
        mediaFileRepository.mediaFiles = List.of(
                mediaFile(MEDIA_ID),
                mediaFile(SECOND_MEDIA_ID)
        );
        RuntimeException failure = new RuntimeException("enqueue failed");
        cleanupScheduler.failure = failure;
        StorageBackedMemoryMediaCleanupCoordinator coordinator =
                storageBackedCoordinator();

        assertThatThrownBy(() -> coordinator.scheduleCleanup(MEMORY_ID))
                .isSameAs(failure);
        assertThat(cleanupScheduler.scheduledKeys).containsExactly(
                thumbnailKey(MEDIA_ID),
                displayKey(MEDIA_ID),
                thumbnailKey(SECOND_MEDIA_ID),
                displayKey(SECOND_MEDIA_ID)
        );
    }

    @Test
    void shouldPropagateMediaLookupFailureBeforeRegisteringCleanup() {
        RuntimeException failure = new RuntimeException("media lookup failed");
        mediaFileRepository.failure = failure;
        StorageBackedMemoryMediaCleanupCoordinator coordinator =
                storageBackedCoordinator();

        assertThatThrownBy(() -> coordinator.scheduleCleanup(
                MEMORY_ID
        ))
                .isSameAs(failure);

        assertThat(cleanupScheduler.scheduledKeys).isEmpty();
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new StorageBackedMemoryMediaCleanupCoordinator(
                null,
                cleanupScheduler
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("mediaFileRepository must not be null");

        assertThatThrownBy(() -> new StorageBackedMemoryMediaCleanupCoordinator(
                mediaFileRepository,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("cleanupScheduler must not be null");
    }

    @Test
    void shouldRejectNullMemoryId() {
        StorageBackedMemoryMediaCleanupCoordinator coordinator =
                storageBackedCoordinator();

        assertThatThrownBy(() -> coordinator.scheduleCleanup(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");
    }

    @Test
    void shouldAllowStorageUnavailableCoordinatorWhenNoMediaExists() {
        StorageUnavailableMemoryMediaCleanupCoordinator coordinator =
                new StorageUnavailableMemoryMediaCleanupCoordinator(
                        mediaFileRepository
                );

        assertThatCode(() -> coordinator.scheduleCleanup(MEMORY_ID))
                .doesNotThrowAnyException();
    }

    @Test
    void shouldFailFastWhenStorageUnavailableAndMediaExists() {
        mediaFileRepository.mediaFiles = List.of(mediaFile(MEDIA_ID));
        StorageUnavailableMemoryMediaCleanupCoordinator coordinator =
                new StorageUnavailableMemoryMediaCleanupCoordinator(
                        mediaFileRepository
                );

        assertThatThrownBy(() -> coordinator.scheduleCleanup(
                MEMORY_ID
        ))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Media storage cleanup is unavailable");
    }

    @Test
    void shouldRejectNullUnavailableCoordinatorDependency() {
        assertThatThrownBy(() ->
                new StorageUnavailableMemoryMediaCleanupCoordinator(null)
        )
                .isInstanceOf(NullPointerException.class)
                .hasMessage("mediaFileRepository must not be null");
    }

    private StorageBackedMemoryMediaCleanupCoordinator storageBackedCoordinator() {
        return new StorageBackedMemoryMediaCleanupCoordinator(
                mediaFileRepository,
                cleanupScheduler
        );
    }

    private static MediaFile mediaFile(UUID id) {
        return new MediaFile(
                id,
                MEMORY_ID,
                MediaType.PHOTO,
                displayKey(id).value(),
                1_024L,
                thumbnailKey(id).value(),
                128L,
                "image/jpeg",
                BASE_TIME
        );
    }

    private static StorageKey thumbnailKey(UUID mediaId) {
        return new StorageKey("media/%s/thumbnail".formatted(mediaId));
    }

    private static StorageKey displayKey(UUID mediaId) {
        return new StorageKey("media/%s/display".formatted(mediaId));
    }

    private static final class FakeMediaFileRepository
            implements MediaFileRepository {

        private List<MediaFile> mediaFiles = List.of();
        private UUID requestedMemoryId;
        private RuntimeException failure;

        @Override
        public Optional<MediaFile> findById(UUID id) {
            return Optional.empty();
        }

        @Override
        public List<MediaFile> findByMemoryId(UUID memoryId) {
            requestedMemoryId = memoryId;

            if (failure != null) {
                throw failure;
            }

            return mediaFiles;
        }

        @Override
        public void save(MediaFile mediaFile) {
        }

        @Override
        public void delete(UUID id) {
        }
    }

    private static final class FakeStorageCleanupScheduler
            implements StorageCleanupScheduler {

        private final List<StorageKey> scheduledKeys = new ArrayList<>();
        private RuntimeException failure;

        @Override
        public void schedule(Collection<StorageKey> storageKeys) {
            scheduledKeys.addAll(storageKeys);
            if (failure != null) {
                throw failure;
            }
        }
    }
}
