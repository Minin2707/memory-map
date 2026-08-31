package memory_map.backend.story.application;

import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.application.TransactionRollbackCoordinator;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.ProcessedPhoto;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class DefaultUploadStoryCoverService
        implements UploadStoryCoverUseCase {

    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final UserStoryRepository userStoryRepository;
    private final ImageProcessor imageProcessor;
    private final StoryCoverStorageKeyFactory storageKeyFactory;
    private final StorageService storageService;
    private final TransactionRollbackCoordinator rollbackCoordinator;
    private final TransactionCommitCoordinator commitCoordinator;

    public DefaultUploadStoryCoverService(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            UserStoryRepository userStoryRepository,
            ImageProcessor imageProcessor,
            StoryCoverStorageKeyFactory storageKeyFactory,
            StorageService storageService,
            TransactionRollbackCoordinator rollbackCoordinator,
            TransactionCommitCoordinator commitCoordinator
    ) {
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
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
        this.commitCoordinator = Objects.requireNonNull(
                commitCoordinator,
                "commitCoordinator must not be null"
        );
    }

    @Override
    @Transactional
    public UserStory uploadStoryCover(UploadStoryCoverCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID storyId = command.storyId();
        UUID requesterUserId = command.authenticatedUser().userId();
        Story lockedStory = storyRepository.findByIdForUpdate(storyId)
                .orElseThrow(StoryNotFoundException::new);
        StoryCoverMetadata oldCover = lockedStory.cover();
        StoryParticipant participant = storyParticipantRepository.find(
                storyId,
                requesterUserId
        ).orElseThrow(StoryNotFoundException::new);

        if (!canUploadCover(participant.role())) {
            throw new StoryNotFoundException();
        }

        ProcessedPhoto processedPhoto = imageProcessor.process(
                command.image()
        );
        StoryCoverStorageKeys keys = storageKeyFactory.keysFor(
                storyId,
                command.coverObjectId()
        );

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
            rollbackCoordinator.onRollback(() -> cleanupStoredCover(keys));
        } catch (RuntimeException exception) {
            cleanupBothWithSuppression(exception, keys);
            throw exception;
        }

        try {
            Instant coverUpdatedAt = nextCoverUpdatedAt(
                    oldCover,
                    command.currentTime()
            );
            storyRepository.updateCover(storyId, new StoryCoverMetadata(
                    keys.display().value(),
                    processedPhoto.displayFileSize(),
                    keys.thumbnail().value(),
                    processedPhoto.thumbnailFileSize(),
                    processedPhoto.mimeType(),
                    coverUpdatedAt
            ));

            UserStory userStory = userStoryRepository.findByStoryIdAndUserId(
                    storyId,
                    requesterUserId
            ).orElseThrow(StoryNotFoundException::new);
            scheduleAfterCommitCleanup(oldCover);

            return userStory;
        } catch (RuntimeException exception) {
            cleanupBothWithSuppression(exception, keys);
            throw exception;
        }
    }

    private static boolean canUploadCover(StoryRole role) {
        return role == StoryRole.OWNER || role == StoryRole.CO_OWNER;
    }

    private static Instant nextCoverUpdatedAt(
            StoryCoverMetadata oldCover,
            Instant candidate
    ) {
        if (oldCover == null) {
            return candidate;
        }

        long oldVersion = oldCover.updatedAt().toEpochMilli();
        if (candidate.toEpochMilli() > oldVersion) {
            return candidate;
        }

        return Instant.ofEpochMilli(oldVersion + 1);
    }

    private void cleanupDisplayAfterThumbnailFailure(
            RuntimeException primary,
            StorageKey displayKey
    ) {
        cleanupWithSuppression(primary, displayKey);
    }

    private void cleanupBothWithSuppression(
            RuntimeException primary,
            StoryCoverStorageKeys keys
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

    private void cleanupStoredCover(StoryCoverStorageKeys keys) {
        cleanupQuietly(keys.thumbnail());
        cleanupQuietly(keys.display());
    }

    private void scheduleAfterCommitCleanup(StoryCoverMetadata oldCover) {
        if (oldCover == null) {
            return;
        }

        commitCoordinator.onCommit(() -> {
            cleanupQuietly(new StorageKey(oldCover.thumbnailStorageKey()));
            cleanupQuietly(new StorageKey(oldCover.displayStorageKey()));
        });
    }

    private void cleanupQuietly(StorageKey key) {
        try {
            storageService.delete(key);
        } catch (RuntimeException ignored) {
            // Storage cleanup is best-effort after DB outcome is known.
        }
    }
}
