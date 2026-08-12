package memory_map.backend.media.application;

import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.ProcessedPhoto;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.MediaStorageKeyFactory;
import memory_map.backend.media.storage.MediaStorageKeys;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class CoordinatedUploadPhotoService implements UploadPhotoUseCase {

    private final MemoryRepository memoryRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final MediaFileRepository mediaFileRepository;
    private final PhotoUploadAuthorizationPolicy authorizationPolicy;
    private final ImageProcessor imageProcessor;
    private final MediaStorageKeyFactory storageKeyFactory;
    private final StorageService storageService;
    private final TransactionRollbackCoordinator rollbackCoordinator;

    public CoordinatedUploadPhotoService(
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            MediaFileRepository mediaFileRepository,
            PhotoUploadAuthorizationPolicy authorizationPolicy,
            ImageProcessor imageProcessor,
            MediaStorageKeyFactory storageKeyFactory,
            StorageService storageService,
            TransactionRollbackCoordinator rollbackCoordinator
    ) {
        this.memoryRepository = Objects.requireNonNull(
                memoryRepository,
                "memoryRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.mediaFileRepository = Objects.requireNonNull(
                mediaFileRepository,
                "mediaFileRepository must not be null"
        );
        this.authorizationPolicy = Objects.requireNonNull(
                authorizationPolicy,
                "authorizationPolicy must not be null"
        );
        this.imageProcessor = Objects.requireNonNull(
                imageProcessor,
                "imageProcessor must not be null"
        );
        this.storageKeyFactory = Objects.requireNonNull(
                storageKeyFactory,
                "storageKeyFactory must not be null"
        );
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
        this.rollbackCoordinator = Objects.requireNonNull(
                rollbackCoordinator,
                "rollbackCoordinator must not be null"
        );
    }

    @Override
    @Transactional
    public MediaFile uploadPhoto(UploadPhotoCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        Memory memory = memoryRepository.findByIdForUpdate(
                command.memoryId()
        ).orElseThrow(PhotoUploadUnavailableException::new);

        UUID requesterUserId = command.authenticatedUser().userId();
        StoryParticipant participant = storyParticipantRepository.find(
                memory.storyId(),
                requesterUserId
        ).orElseThrow(PhotoUploadUnavailableException::new);

        if (!authorizationPolicy.canUploadPhoto(
                participant,
                memory,
                requesterUserId
        )) {
            throw new PhotoUploadUnavailableException();
        }

        ProcessedPhoto processedPhoto = imageProcessor.process(command.image());
        MediaStorageKeys keys = storageKeyFactory.keysFor(command.mediaId());

        storageService.store(new StorageObjectWrite(
                keys.display(),
                processedPhoto.display().content(),
                processedPhoto.mimeType()
        ));

        try {
            storageService.store(new StorageObjectWrite(
                    keys.thumbnail(),
                    processedPhoto.thumbnail().content(),
                    processedPhoto.mimeType()
            ));
        } catch (RuntimeException exception) {
            cleanupDisplayAfterThumbnailFailure(exception, keys.display());
            throw exception;
        }

        try {
            rollbackCoordinator.onRollback(() -> cleanupStoredPhoto(keys));
        } catch (RuntimeException exception) {
            cleanupBothAfterRegistrationFailure(exception, keys);
            throw exception;
        }

        MediaFile mediaFile = new MediaFile(
                command.mediaId(),
                memory.id(),
                MediaType.PHOTO,
                keys.display().value(),
                processedPhoto.displayFileSize(),
                keys.thumbnail().value(),
                processedPhoto.thumbnailFileSize(),
                processedPhoto.mimeType(),
                command.currentTime()
        );

        mediaFileRepository.save(mediaFile);

        return mediaFile;
    }

    private void cleanupDisplayAfterThumbnailFailure(
            RuntimeException primary,
            StorageKey displayKey
    ) {
        try {
            storageService.delete(displayKey);
        } catch (RuntimeException cleanupFailure) {
            primary.addSuppressed(cleanupFailure);
        }
    }

    private void cleanupBothAfterRegistrationFailure(
            RuntimeException primary,
            MediaStorageKeys keys
    ) {
        cleanupWithSuppression(primary, keys.thumbnail());
        cleanupWithSuppression(primary, keys.display());
    }

    private void cleanupWithSuppression(
            RuntimeException primary,
            StorageKey key
    ) {
        try {
            storageService.delete(key);
        } catch (RuntimeException cleanupFailure) {
            primary.addSuppressed(cleanupFailure);
        }
    }

    private void cleanupStoredPhoto(MediaStorageKeys keys) {
        cleanupQuietly(keys.thumbnail());
        cleanupQuietly(keys.display());
    }

    private void cleanupQuietly(StorageKey key) {
        try {
            storageService.delete(key);
        } catch (RuntimeException ignored) {
            // Transaction rollback cleanup is best-effort after DB outcome is known.
        }
    }
}
