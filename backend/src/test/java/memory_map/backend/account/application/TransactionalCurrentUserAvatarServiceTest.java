package memory_map.backend.account.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.application.StorageCleanupRecoveryScheduler;
import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.application.TransactionRollbackCoordinator;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.image.ProcessedImage;
import memory_map.backend.media.image.ProcessedPhoto;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StorageStreamWrite;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalCurrentUserAvatarServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID AVATAR_OBJECT_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final String GOOGLE_AVATAR_URL =
            "https://example.com/google.png";
    private static final String OLD_STORAGE_KEY =
            "users/%s/avatar/old-avatar".formatted(USER_ID);
    private static final String NEW_STORAGE_KEY =
            "users/%s/avatar/%s".formatted(USER_ID, AVATAR_OBJECT_ID);

    @Test
    void shouldRejectNullConstructorDependencies() {
        FakeUserRepository userRepository =
                new FakeUserRepository(userWithCustomAvatar());
        UserAvatarImageProcessor imageProcessor = imageProcessor();
        UserAvatarStorageKeyFactory storageKeyFactory =
                new DeterministicUserAvatarStorageKeyFactory();
        FakeStorageService storageService = new FakeStorageService();
        FakeRollbackCoordinator rollbackCoordinator =
                new FakeRollbackCoordinator();
        FakeStorageCleanupScheduler cleanupScheduler =
                new FakeStorageCleanupScheduler();
        FakeStorageCleanupRecoveryScheduler recoveryScheduler =
                new FakeStorageCleanupRecoveryScheduler();

        assertThatThrownBy(() -> new TransactionalCurrentUserAvatarService(
                null,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                cleanupScheduler,
                recoveryScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("userRepository must not be null");
        assertThatThrownBy(() -> new TransactionalCurrentUserAvatarService(
                userRepository,
                null,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                cleanupScheduler,
                recoveryScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("imageProcessor must not be null");
        assertThatThrownBy(() -> new TransactionalCurrentUserAvatarService(
                userRepository,
                imageProcessor,
                null,
                storageService,
                rollbackCoordinator,
                cleanupScheduler,
                recoveryScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageKeyFactory must not be null");
        assertThatThrownBy(() -> new TransactionalCurrentUserAvatarService(
                userRepository,
                imageProcessor,
                storageKeyFactory,
                null,
                rollbackCoordinator,
                cleanupScheduler,
                recoveryScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");
        assertThatThrownBy(() -> new TransactionalCurrentUserAvatarService(
                userRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                null,
                cleanupScheduler,
                recoveryScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("rollbackCoordinator must not be null");
        assertThatThrownBy(() -> new TransactionalCurrentUserAvatarService(
                userRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                null,
                recoveryScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("cleanupScheduler must not be null");
        assertThatThrownBy(() -> new TransactionalCurrentUserAvatarService(
                userRepository,
                imageProcessor,
                storageKeyFactory,
                storageService,
                rollbackCoordinator,
                cleanupScheduler,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("recoveryScheduler must not be null");
    }

    @Test
    void shouldRejectNullCommands() {
        TestContext context = new TestContext(userWithCustomAvatar());

        assertThatThrownBy(() -> context.service().uploadAvatar(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
        assertThatThrownBy(() -> context.service().downloadAvatar(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
        assertThatThrownBy(() -> context.service().removeAvatar(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    @Test
    void shouldRejectUploadWhenUserIsUnavailableWithoutMutatingStorageOrDb() {
        TestContext context = new TestContext(null);

        assertThatThrownBy(() -> context.service().uploadAvatar(uploadCommand()))
                .isInstanceOf(UserAvatarUnavailableException.class);

        assertThat(context.storageService().storedObject()).isNull();
        assertThat(context.storageService().deletedKeys()).isEmpty();
        assertThat(context.userRepository().updateCustomAvatarCalls()).isZero();
        assertThat(context.rollbackCoordinator().actions()).isEmpty();
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
        assertThat(context.recoveryScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldStoreNewAvatarWithoutSchedulingOldCleanupWhenNoPreviousAvatar() {
        TestContext context = new TestContext(userWithoutCustomAvatar());

        User updated = context.service().uploadAvatar(uploadCommand());

        assertThat(updated).isEqualTo(context.userRepository().activeUser());
        assertThat(updated.customAvatarStorageKey()).isEqualTo(NEW_STORAGE_KEY);
        assertThat(context.storageService().storedObject().storageKey())
                .isEqualTo(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.storageService().storedObject().contentType())
                .isEqualTo("image/jpeg");
        assertThat(context.rollbackCoordinator().actions()).hasSize(1);
        assertThat(context.userRepository().updateCustomAvatarCalls())
                .isEqualTo(1);
        assertThat(context.userRepository().updatedCustomAvatarStorageKey())
                .isEqualTo(NEW_STORAGE_KEY);
        assertThat(context.userRepository().updatedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
        assertThat(context.recoveryScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldStoreNewAvatarAndScheduleOldAvatarCleanup() {
        TestContext context = new TestContext(userWithCustomAvatar());

        User updated = context.service().uploadAvatar(uploadCommand());

        assertThat(updated.avatarUrl()).isEqualTo(GOOGLE_AVATAR_URL);
        assertThat(updated.customAvatarStorageKey()).isEqualTo(NEW_STORAGE_KEY);
        assertThat(context.userRepository().updateCustomAvatarCalls())
                .isEqualTo(1);
        assertThat(context.userRepository().updatedCustomAvatarStorageKey())
                .isEqualTo(NEW_STORAGE_KEY);
        assertThat(context.userRepository().updatedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(context.storageService().storedObject().storageKey())
                .isEqualTo(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.storageService().storedObject().contentType())
                .isEqualTo("image/jpeg");
        assertThat(context.storageService().deletedKeys()).isEmpty();
        assertThat(context.cleanupScheduler().scheduledKeys())
                .containsExactly(new StorageKey(OLD_STORAGE_KEY));
        assertThat(context.recoveryScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldDeleteNewAvatarFromRollbackCallbackAndSuppressCleanupFailure() {
        TestContext context = new TestContext(userWithCustomAvatar());

        context.service().uploadAvatar(uploadCommand());

        Runnable rollbackCleanup =
                context.rollbackCoordinator().actions().getFirst();
        rollbackCleanup.run();
        assertThat(context.storageService().deletedKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.recoveryScheduler().scheduledKeys()).isEmpty();

        context.storageService().deleteFailure =
                new RuntimeException("cleanup failed");
        assertThatCode(rollbackCleanup::run).doesNotThrowAnyException();
        assertThat(context.storageService().deletedKeys())
                .containsExactly(
                        new StorageKey(NEW_STORAGE_KEY),
                        new StorageKey(NEW_STORAGE_KEY)
                );
        assertThat(context.recoveryScheduler().scheduledKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
    }

    @Test
    void shouldIgnoreRecoveryFailureWhenRollbackCleanupRuns() {
        TestContext context = new TestContext(userWithCustomAvatar());

        context.service().uploadAvatar(uploadCommand());
        Runnable rollbackCleanup =
                context.rollbackCoordinator().actions().getFirst();
        context.storageService().deleteFailure =
                new RuntimeException("cleanup failed");
        context.recoveryScheduler().failure =
                new RuntimeException("recovery enqueue failed");

        assertThatCode(rollbackCleanup::run).doesNotThrowAnyException();

        assertThat(context.storageService().deletedKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.recoveryScheduler().scheduledKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
    }

    @Test
    void shouldDeleteNewAvatarWhenRollbackRegistrationFailsAndRethrowPrimary() {
        TestContext context = new TestContext(userWithCustomAvatar());
        RuntimeException failure = new RuntimeException(
                "rollback registration failed"
        );
        context.rollbackCoordinator().failure = failure;

        assertThatThrownBy(() -> context.service().uploadAvatar(uploadCommand()))
                .isSameAs(failure);

        assertThat(context.storageService().deletedKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.userRepository().updateCustomAvatarCalls()).isZero();
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
        assertThat(context.recoveryScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldSuppressCleanupFailureWhenRollbackRegistrationFails() {
        TestContext context = new TestContext(userWithCustomAvatar());
        RuntimeException primary = new RuntimeException(
                "rollback registration failed"
        );
        RuntimeException cleanupFailure = new RuntimeException(
                "cleanup failed"
        );
        context.rollbackCoordinator().failure = primary;
        context.storageService().deleteFailure = cleanupFailure;

        assertThatThrownBy(() -> context.service().uploadAvatar(uploadCommand()))
                .isSameAs(primary)
                .satisfies(exception -> assertThat(exception.getSuppressed())
                        .containsExactly(cleanupFailure));

        assertThat(context.storageService().deletedKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.recoveryScheduler().scheduledKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
    }

    @Test
    void shouldSuppressRecoveryFailureWhenRollbackRegistrationCleanupFails() {
        TestContext context = new TestContext(userWithCustomAvatar());
        RuntimeException primary = new RuntimeException(
                "rollback registration failed"
        );
        RuntimeException cleanupFailure = new RuntimeException(
                "cleanup failed"
        );
        RuntimeException recoveryFailure = new RuntimeException(
                "recovery enqueue failed"
        );
        context.rollbackCoordinator().failure = primary;
        context.storageService().deleteFailure = cleanupFailure;
        context.recoveryScheduler().failure = recoveryFailure;

        assertThatThrownBy(() -> context.service().uploadAvatar(uploadCommand()))
                .isSameAs(primary)
                .satisfies(exception -> assertThat(exception.getSuppressed())
                        .containsExactly(cleanupFailure, recoveryFailure));

        assertThat(context.recoveryScheduler().scheduledKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
    }

    @Test
    void shouldDeleteNewAvatarWhenDbUpdateFailsAndKeepOldAvatarReference() {
        TestContext context = new TestContext(userWithCustomAvatar());
        context.userRepository().failUpdateCustomAvatar = true;

        assertThatThrownBy(() -> context.service().uploadAvatar(uploadCommand()))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("update failed");

        assertThat(context.userRepository().activeUser().customAvatarStorageKey())
                .isEqualTo(OLD_STORAGE_KEY);
        assertThat(context.storageService().deletedKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
        assertThat(context.recoveryScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldSuppressCleanupFailureWhenDbUpdateFails() {
        TestContext context = new TestContext(userWithCustomAvatar());
        RuntimeException primary = new RuntimeException("update failed");
        RuntimeException cleanupFailure = new RuntimeException(
                "cleanup failed"
        );
        context.userRepository().updateFailure = primary;
        context.storageService().deleteFailure = cleanupFailure;

        assertThatThrownBy(() -> context.service().uploadAvatar(uploadCommand()))
                .isSameAs(primary)
                .satisfies(exception -> assertThat(exception.getSuppressed())
                        .containsExactly(cleanupFailure));

        assertThat(context.storageService().deletedKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
        assertThat(context.recoveryScheduler().scheduledKeys())
                .containsExactly(new StorageKey(NEW_STORAGE_KEY));
    }

    @Test
    void shouldRejectDownloadWhenUserDoesNotExist() {
        TestContext context = new TestContext(null);

        assertThatThrownBy(() -> context.service()
                .downloadAvatar(downloadCommand()))
                .isInstanceOf(UserAvatarUnavailableException.class);

        assertThat(context.storageService().readKey()).isNull();
    }

    @Test
    void shouldRejectDownloadWhenUserIsDeleted() {
        TestContext context = new TestContext(deletedUserWithCustomAvatar());

        assertThatThrownBy(() -> context.service()
                .downloadAvatar(downloadCommand()))
                .isInstanceOf(UserAvatarUnavailableException.class);

        assertThat(context.storageService().readKey()).isNull();
    }

    @Test
    void shouldRejectDownloadWhenUserHasNoCustomAvatar() {
        TestContext context = new TestContext(userWithoutCustomAvatar());

        assertThatThrownBy(() -> context.service()
                .downloadAvatar(downloadCommand()))
                .isInstanceOf(UserAvatarUnavailableException.class);

        assertThat(context.storageService().readKey()).isNull();
    }

    @Test
    void shouldDownloadStoredCustomAvatar() throws Exception {
        TestContext context = new TestContext(userWithCustomAvatar());
        byte[] bytes = new byte[] {9, 8, 7};
        context.storageService().readObject = new StoredObject(
                new ByteArrayInputStream(bytes),
                bytes.length,
                "image/jpeg"
        );

        DownloadedUserAvatar avatar = context.service()
                .downloadAvatar(downloadCommand());

        assertThat(context.storageService().readKey())
                .isEqualTo(new StorageKey(OLD_STORAGE_KEY));
        assertThat(avatar.content().readAllBytes()).containsExactly(bytes);
        assertThat(avatar.contentLength()).isEqualTo(bytes.length);
        assertThat(avatar.contentType()).isEqualTo("image/jpeg");
    }

    @Test
    void shouldRejectRemoveWhenUserIsUnavailableWithoutMutatingAvatar() {
        TestContext context = new TestContext(null);

        assertThatThrownBy(() -> context.service().removeAvatar(removeCommand()))
                .isInstanceOf(UserAvatarUnavailableException.class);

        assertThat(context.userRepository().clearCustomAvatarCalls()).isZero();
        assertThat(context.storageService().deletedKeys()).isEmpty();
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldClearAvatarWithoutSchedulingOldCleanupWhenNoPreviousAvatar() {
        TestContext context = new TestContext(userWithoutCustomAvatar());

        User updated = context.service().removeAvatar(removeCommand());

        assertThat(updated).isEqualTo(context.userRepository().activeUser());
        assertThat(updated.hasCustomAvatar()).isFalse();
        assertThat(context.userRepository().clearCustomAvatarCalls())
                .isEqualTo(1);
        assertThat(context.userRepository().updatedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
        assertThat(context.storageService().deletedKeys()).isEmpty();
    }

    @Test
    void shouldRemoveCustomAvatarAndScheduleOldAvatarCleanup() {
        TestContext context = new TestContext(userWithCustomAvatar());

        User updated = context.service().removeAvatar(removeCommand());

        assertThat(updated.avatarUrl()).isEqualTo(GOOGLE_AVATAR_URL);
        assertThat(updated.customAvatarStorageKey()).isNull();
        assertThat(updated.hasCustomAvatar()).isFalse();
        assertThat(context.userRepository().clearCustomAvatarCalls())
                .isEqualTo(1);
        assertThat(context.userRepository().updatedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(context.storageService().deletedKeys()).isEmpty();

        assertThat(context.cleanupScheduler().scheduledKeys())
                .containsExactly(new StorageKey(OLD_STORAGE_KEY));
    }

    @Test
    void shouldPropagateOldAvatarCleanupSchedulingFailureAfterRemove() {
        TestContext context = new TestContext(userWithCustomAvatar());
        RuntimeException failure = new RuntimeException("enqueue failed");
        context.cleanupScheduler().failure = failure;

        assertThatThrownBy(() -> context.service().removeAvatar(
                removeCommand()
        ))
                .isSameAs(failure);

        assertThat(context.storageService().deletedKeys()).isEmpty();
        assertThat(context.cleanupScheduler().scheduledKeys())
                .containsExactly(new StorageKey(OLD_STORAGE_KEY));
    }

    private static UploadCurrentUserAvatarCommand uploadCommand() {
        return new UploadCurrentUserAvatarCommand(
                new AuthenticatedUser(USER_ID),
                AVATAR_OBJECT_ID,
                new ImageProcessingInput(new byte[] {1, 2, 3}, "image/jpeg"),
                CURRENT_TIME
        );
    }

    private static DownloadCurrentUserAvatarCommand downloadCommand() {
        return new DownloadCurrentUserAvatarCommand(
                new AuthenticatedUser(USER_ID)
        );
    }

    private static RemoveCurrentUserAvatarCommand removeCommand() {
        return new RemoveCurrentUserAvatarCommand(
                new AuthenticatedUser(USER_ID),
                CURRENT_TIME
        );
    }

    private static User userWithCustomAvatar() {
        return new User(
                USER_ID,
                "google-subject-123",
                "Ada Lovelace",
                GOOGLE_AVATAR_URL,
                OLD_STORAGE_KEY,
                CREATED_AT,
                CREATED_AT,
                CREATED_AT,
                null
        );
    }

    private static User userWithoutCustomAvatar() {
        return new User(
                USER_ID,
                "google-subject-123",
                "Ada Lovelace",
                GOOGLE_AVATAR_URL,
                CREATED_AT,
                CREATED_AT
        );
    }

    private static User deletedUserWithCustomAvatar() {
        return new User(
                USER_ID,
                "google-subject-123",
                "Ada Lovelace",
                GOOGLE_AVATAR_URL,
                OLD_STORAGE_KEY,
                CREATED_AT,
                CREATED_AT,
                CREATED_AT,
                CURRENT_TIME
        );
    }

    private static UserAvatarImageProcessor imageProcessor() {
        return new UserAvatarImageProcessor(new FakeImageProcessor());
    }

    private record TestContext(
            FakeUserRepository userRepository,
            FakeStorageService storageService,
            FakeRollbackCoordinator rollbackCoordinator,
            FakeStorageCleanupScheduler cleanupScheduler,
            FakeStorageCleanupRecoveryScheduler recoveryScheduler,
            TransactionalCurrentUserAvatarService service
    ) {
        private TestContext(User user) {
            this(
                    new FakeUserRepository(user),
                    new FakeStorageService(),
                    new FakeRollbackCoordinator(),
                    new FakeStorageCleanupScheduler(),
                    new FakeStorageCleanupRecoveryScheduler()
            );
        }

        private TestContext(
                FakeUserRepository userRepository,
                FakeStorageService storageService,
                FakeRollbackCoordinator rollbackCoordinator,
                FakeStorageCleanupScheduler cleanupScheduler,
                FakeStorageCleanupRecoveryScheduler recoveryScheduler
        ) {
            this(
                    userRepository,
                    storageService,
                    rollbackCoordinator,
                    cleanupScheduler,
                    recoveryScheduler,
                    new TransactionalCurrentUserAvatarService(
                            userRepository,
                            imageProcessor(),
                            new DeterministicUserAvatarStorageKeyFactory(),
                            storageService,
                            rollbackCoordinator,
                            cleanupScheduler,
                            recoveryScheduler
                    )
            );
        }
    }

    private static final class FakeUserRepository implements UserRepository {

        private User activeUser;
        private boolean failUpdateCustomAvatar;
        private RuntimeException updateFailure;
        private int updateCustomAvatarCalls;
        private int clearCustomAvatarCalls;
        private String updatedCustomAvatarStorageKey;
        private Instant updatedAt;

        private FakeUserRepository(User activeUser) {
            this.activeUser = activeUser;
        }

        @Override
        public Optional<User> findActiveByIdForUpdate(UUID id) {
            return activeUser != null &&
                    activeUser.id().equals(id) &&
                    !activeUser.isDeleted()
                    ? Optional.of(activeUser)
                    : Optional.empty();
        }

        @Override
        public User updateCustomAvatar(
                UUID id,
                String storageKey,
                Instant updatedAt
        ) {
            updateCustomAvatarCalls++;
            updatedCustomAvatarStorageKey = storageKey;
            this.updatedAt = updatedAt;
            if (updateFailure != null) {
                throw updateFailure;
            }
            if (failUpdateCustomAvatar) {
                throw new RuntimeException("update failed");
            }

            activeUser = new User(
                    activeUser.id(),
                    activeUser.googleSubject(),
                    activeUser.displayName(),
                    activeUser.displayNameCustomized(),
                    activeUser.avatarUrl(),
                    storageKey,
                    updatedAt,
                    activeUser.createdAt(),
                    updatedAt,
                    activeUser.deletedAt()
            );
            return activeUser;
        }

        @Override
        public User clearCustomAvatar(UUID id, Instant updatedAt) {
            clearCustomAvatarCalls++;
            this.updatedAt = updatedAt;
            activeUser = new User(
                    activeUser.id(),
                    activeUser.googleSubject(),
                    activeUser.displayName(),
                    activeUser.displayNameCustomized(),
                    activeUser.avatarUrl(),
                    null,
                    null,
                    activeUser.createdAt(),
                    updatedAt,
                    activeUser.deletedAt()
            );
            return activeUser;
        }

        @Override
        public User save(User user) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<User> findById(UUID id) {
            return activeUser != null && activeUser.id().equals(id)
                    ? Optional.of(activeUser)
                    : Optional.empty();
        }

        @Override
        public Optional<User> findByGoogleSubject(String googleSubject) {
            throw new UnsupportedOperationException();
        }

        private User activeUser() {
            return activeUser;
        }

        private int updateCustomAvatarCalls() {
            return updateCustomAvatarCalls;
        }

        private int clearCustomAvatarCalls() {
            return clearCustomAvatarCalls;
        }

        private String updatedCustomAvatarStorageKey() {
            return updatedCustomAvatarStorageKey;
        }

        private Instant updatedAt() {
            return updatedAt;
        }
    }

    private static final class FakeStorageService implements StorageService {

        private StorageObjectWrite storedObject;
        private StoredObject readObject;
        private StorageKey readKey;
        private RuntimeException deleteFailure;
        private final List<StorageKey> deletedKeys = new ArrayList<>();

        @Override
        public void store(StorageObjectWrite object) {
            storedObject = object;
        }

        @Override
        public void store(StorageStreamWrite object) {
            throw new UnsupportedOperationException();
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            readKey = storageKey;
            return readObject;
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
            deletedKeys.add(storageKey);
            if (deleteFailure != null) {
                throw deleteFailure;
            }
        }

        private StorageObjectWrite storedObject() {
            return storedObject;
        }

        private List<StorageKey> deletedKeys() {
            return deletedKeys;
        }

        private StorageKey readKey() {
            return readKey;
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

        private List<StorageKey> scheduledKeys() {
            return scheduledKeys;
        }
    }

    private static final class FakeStorageCleanupRecoveryScheduler
            implements StorageCleanupRecoveryScheduler {

        private final List<StorageKey> scheduledKeys = new ArrayList<>();
        private RuntimeException failure;

        @Override
        public void schedule(Collection<StorageKey> storageKeys) {
            scheduledKeys.addAll(storageKeys);
            if (failure != null) {
                throw failure;
            }
        }

        private List<StorageKey> scheduledKeys() {
            return scheduledKeys;
        }
    }

    private static final class FakeRollbackCoordinator
            implements TransactionRollbackCoordinator {

        private final List<Runnable> actions = new ArrayList<>();
        private RuntimeException failure;

        @Override
        public void onRollback(Runnable action) {
            if (failure != null) {
                throw failure;
            }
            actions.add(action);
        }

        private List<Runnable> actions() {
            return actions;
        }
    }

    private static final class FakeImageProcessor implements ImageProcessor {

        @Override
        public ProcessedPhoto process(ImageProcessingInput input) {
            byte[] image = jpegBytes();

            return new ProcessedPhoto(
                    new ProcessedImage(image),
                    new ProcessedImage(image),
                    "image/jpeg"
            );
        }
    }

    private static byte[] jpegBytes() {
        try {
            BufferedImage image = new BufferedImage(
                    2,
                    2,
                    BufferedImage.TYPE_INT_RGB
            );
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            ImageIO.write(image, "JPEG", output);

            return output.toByteArray();
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }
}
