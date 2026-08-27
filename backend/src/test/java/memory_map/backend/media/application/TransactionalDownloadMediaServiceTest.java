package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.repository.AuthorizedMediaDownloadRepository;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalDownloadMediaServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final byte[] STORED_BYTES = new byte[] {1, 2, 3};

    private final List<String> events = new ArrayList<>();
    private final FakeAuthorizedMediaDownloadRepository
            authorizedMediaDownloadRepository =
            new FakeAuthorizedMediaDownloadRepository(events);
    private final FakeStorageService storageService =
            new FakeStorageService(events);
    private final TransactionalDownloadMediaService service =
            new TransactionalDownloadMediaService(
                    authorizedMediaDownloadRepository,
                    storageService
            );

    @Test
    void shouldDownloadDisplayUsingAuthorizedProjectionMetadata()
            throws Exception {

        storageService.storedObject = new StoredObject(
                new ByteArrayInputStream(STORED_BYTES),
                999L,
                "application/octet-stream"
        );

        DownloadedMedia result = service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        );

        assertThat(result.content().readAllBytes()).containsExactly(
                STORED_BYTES
        );
        assertThat(result.contentLength()).isEqualTo(1_024L);
        assertThat(result.contentType()).isEqualTo("image/jpeg");
        assertThat(storageService.requestedKey)
                .isEqualTo(new StorageKey("media/display"));
        assertThat(authorizedMediaDownloadRepository.requestedMediaId)
                .isEqualTo(MEDIA_ID);
        assertThat(authorizedMediaDownloadRepository.requestedRequesterUserId)
                .isEqualTo(USER_ID);
        assertThat(events).containsExactly(
                "authorizedMedia.findAuthorizedDownload",
                "storage.read"
        );
    }

    @Test
    void shouldDownloadThumbnailUsingAuthorizedProjectionMetadata() {
        DownloadedMedia result = service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.THUMBNAIL
        );

        assertThat(result.contentLength()).isEqualTo(128L);
        assertThat(result.contentType()).isEqualTo("image/jpeg");
        assertThat(storageService.requestedKey)
                .isEqualTo(new StorageKey("media/thumbnail"));
        assertThat(events).containsExactly(
                "authorizedMedia.findAuthorizedDownload",
                "storage.read"
        );
    }

    @Test
    void shouldDenyUnavailableMediaBeforeStorageLookup() {
        authorizedMediaDownloadRepository.media = Optional.empty();

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(MediaUnavailableException.class)
                .hasMessage("Media could not be found");

        assertThat(events).containsExactly(
                "authorizedMedia.findAuthorizedDownload"
        );
        assertThat(storageService.callCount).isZero();
    }

    @Test
    void shouldMapMissingStorageObjectToSafeUnavailable() {
        storageService.failure = new StorageObjectNotFoundException();

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(MediaUnavailableException.class)
                .hasMessage("Media could not be found");
    }

    @Test
    void shouldPropagateTechnicalStorageFailure() {
        StorageException failure = new StorageException();
        storageService.failure = failure;

        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isSameAs(failure);
    }

    @Test
    void shouldRejectNullDependenciesAndInputs() {
        assertThatThrownBy(() -> new TransactionalDownloadMediaService(
                null,
                storageService
        )).isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "authorizedMediaDownloadRepository must not be null"
                );
        assertThatThrownBy(() -> new TransactionalDownloadMediaService(
                authorizedMediaDownloadRepository,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");
        assertThatThrownBy(() -> service.downloadMedia(
                null,
                MEDIA_ID,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
        assertThatThrownBy(() -> service.downloadMedia(
                user(),
                null,
                MediaRepresentation.DISPLAY
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mediaId must not be null");
        assertThatThrownBy(() -> service.downloadMedia(user(), MEDIA_ID, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("representation must not be null");
    }

    private static AuthenticatedUser user() {
        return new AuthenticatedUser(USER_ID);
    }

    private static MediaDownloadReadModel media() {
        return new MediaDownloadReadModel(
                "media/display",
                1_024L,
                "media/thumbnail",
                128L,
                "image/jpeg"
        );
    }

    private static final class FakeAuthorizedMediaDownloadRepository
            implements AuthorizedMediaDownloadRepository {

        private final List<String> events;
        private Optional<MediaDownloadReadModel> media = Optional.of(media());
        private UUID requestedMediaId;
        private UUID requestedRequesterUserId;

        private FakeAuthorizedMediaDownloadRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<MediaDownloadReadModel> findAuthorizedDownload(
                UUID mediaId,
                UUID requesterUserId
        ) {
            events.add("authorizedMedia.findAuthorizedDownload");
            requestedMediaId = mediaId;
            requestedRequesterUserId = requesterUserId;

            return media;
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
