package memory_map.backend.account.application;

import memory_map.backend.media.application.StorageCleanupRecoveryScheduler;
import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.application.TransactionRollbackCoordinator;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class TransactionalCurrentUserAvatarService
        implements CurrentUserAvatarUseCase {

    private static final Logger LOGGER = LoggerFactory.getLogger(
            TransactionalCurrentUserAvatarService.class
    );

    private final UserRepository userRepository;
    private final UserAvatarImageProcessor imageProcessor;
    private final UserAvatarStorageKeyFactory storageKeyFactory;
    private final StorageService storageService;
    private final TransactionRollbackCoordinator rollbackCoordinator;
    private final StorageCleanupScheduler cleanupScheduler;
    private final StorageCleanupRecoveryScheduler recoveryScheduler;

    public TransactionalCurrentUserAvatarService(
            UserRepository userRepository,
            UserAvatarImageProcessor imageProcessor,
            UserAvatarStorageKeyFactory storageKeyFactory,
            StorageService storageService,
            TransactionRollbackCoordinator rollbackCoordinator,
            StorageCleanupScheduler cleanupScheduler,
            StorageCleanupRecoveryScheduler recoveryScheduler
    ) {
        this.userRepository = Objects.requireNonNull(
                userRepository,
                "userRepository must not be null"
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
        this.cleanupScheduler = Objects.requireNonNull(
                cleanupScheduler,
                "cleanupScheduler must not be null"
        );
        this.recoveryScheduler = Objects.requireNonNull(
                recoveryScheduler,
                "recoveryScheduler must not be null"
        );
    }

    @Override
    @Transactional
    public User uploadAvatar(UploadCurrentUserAvatarCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID userId = command.authenticatedUser().userId();
        User lockedUser = userRepository.findActiveByIdForUpdate(userId)
                .orElseThrow(UserAvatarUnavailableException::new);
        StorageKey newStorageKey = storageKeyFactory.keyFor(
                userId,
                command.avatarObjectId()
        );
        ProcessedUserAvatar avatar = imageProcessor.process(command.image());

        storageService.store(new StorageObjectWrite(
                newStorageKey,
                avatar.content(),
                avatar.contentType()
        ));

        try {
            rollbackCoordinator.onRollback(() -> cleanupQuietly(newStorageKey));
        } catch (RuntimeException exception) {
            cleanupWithSuppression(exception, newStorageKey);
            throw exception;
        }

        try {
            User updated = userRepository.updateCustomAvatar(
                    userId,
                    newStorageKey.value(),
                    command.currentTime()
            );
            scheduleCleanup(previousCustomAvatarKey(lockedUser));
            return updated;
        } catch (RuntimeException exception) {
            cleanupWithSuppression(exception, newStorageKey);
            throw exception;
        }
    }

    @Override
    public DownloadedUserAvatar downloadAvatar(
            DownloadCurrentUserAvatarCommand command
    ) {
        Objects.requireNonNull(command, "command must not be null");

        User user = userRepository
                .findById(command.authenticatedUser().userId())
                .filter(activeUser -> !activeUser.isDeleted())
                .filter(User::hasCustomAvatar)
                .orElseThrow(UserAvatarUnavailableException::new);
        StoredObject storedObject = storageService.read(
                new StorageKey(user.customAvatarStorageKey())
        );

        return new DownloadedUserAvatar(
                storedObject.content(),
                storedObject.contentLength(),
                storedObject.contentType()
        );
    }

    @Override
    @Transactional
    public User removeAvatar(RemoveCurrentUserAvatarCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID userId = command.authenticatedUser().userId();
        User lockedUser = userRepository.findActiveByIdForUpdate(userId)
                .orElseThrow(UserAvatarUnavailableException::new);
        User updated = userRepository.clearCustomAvatar(
                userId,
                command.currentTime()
        );
        scheduleCleanup(previousCustomAvatarKey(lockedUser));

        return updated;
    }

    private StorageKey previousCustomAvatarKey(User user) {
        if (!user.hasCustomAvatar()) {
            return null;
        }

        return new StorageKey(user.customAvatarStorageKey());
    }

    private void scheduleCleanup(StorageKey storageKey) {
        if (storageKey != null) {
            cleanupScheduler.schedule(List.of(storageKey));
        }
    }

    private void cleanupWithSuppression(
            RuntimeException primary,
            StorageKey storageKey
    ) {
        try {
            storageService.delete(storageKey);
        } catch (RuntimeException cleanupFailure) {
            primary.addSuppressed(cleanupFailure);
            scheduleRecoveryWithSuppression(primary, storageKey);
        }
    }

    private void cleanupQuietly(StorageKey storageKey) {
        try {
            storageService.delete(storageKey);
        } catch (RuntimeException cleanupFailure) {
            try {
                recoveryScheduler.schedule(List.of(storageKey));
            } catch (RuntimeException recoveryFailure) {
                LOGGER.warn(
                        "object cleanup recovery scheduling failed: {}",
                        recoveryFailure.getClass().getName()
                );
            }
        }
    }

    private void scheduleRecoveryWithSuppression(
            RuntimeException primary,
            StorageKey storageKey
    ) {
        try {
            recoveryScheduler.schedule(List.of(storageKey));
        } catch (RuntimeException recoveryFailure) {
            primary.addSuppressed(recoveryFailure);
        }
    }
}
