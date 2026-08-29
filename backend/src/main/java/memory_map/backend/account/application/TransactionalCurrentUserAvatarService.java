package memory_map.backend.account.application;

import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.application.TransactionRollbackCoordinator;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class TransactionalCurrentUserAvatarService
        implements CurrentUserAvatarUseCase {

    private final UserRepository userRepository;
    private final UserAvatarImageProcessor imageProcessor;
    private final UserAvatarStorageKeyFactory storageKeyFactory;
    private final StorageService storageService;
    private final TransactionRollbackCoordinator rollbackCoordinator;
    private final TransactionCommitCoordinator commitCoordinator;

    public TransactionalCurrentUserAvatarService(
            UserRepository userRepository,
            UserAvatarImageProcessor imageProcessor,
            UserAvatarStorageKeyFactory storageKeyFactory,
            StorageService storageService,
            TransactionRollbackCoordinator rollbackCoordinator,
            TransactionCommitCoordinator commitCoordinator
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
        this.commitCoordinator = Objects.requireNonNull(
                commitCoordinator,
                "commitCoordinator must not be null"
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
            scheduleAfterCommitCleanup(previousCustomAvatarKey(lockedUser));
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
        scheduleAfterCommitCleanup(previousCustomAvatarKey(lockedUser));

        return updated;
    }

    private StorageKey previousCustomAvatarKey(User user) {
        if (!user.hasCustomAvatar()) {
            return null;
        }

        return new StorageKey(user.customAvatarStorageKey());
    }

    private void scheduleAfterCommitCleanup(StorageKey storageKey) {
        if (storageKey != null) {
            commitCoordinator.onCommit(() -> cleanupQuietly(storageKey));
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
        }
    }

    private void cleanupQuietly(StorageKey storageKey) {
        try {
            storageService.delete(storageKey);
        } catch (RuntimeException ignored) {
            // Storage cleanup is best-effort after DB outcome is known.
        }
    }
}
