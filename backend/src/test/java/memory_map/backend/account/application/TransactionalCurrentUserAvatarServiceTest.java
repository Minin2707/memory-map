package memory_map.backend.account.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.application.TransactionCommitCoordinator;
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
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
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
    void shouldStoreNewAvatarAndCleanupOldAvatarAfterCommit() {
        TestContext context = new TestContext(userWithCustomAvatar());

        User updated = context.service().uploadAvatar(uploadCommand());

        assertThat(updated.avatarUrl()).isEqualTo(GOOGLE_AVATAR_URL);
        assertThat(updated.customAvatarStorageKey()).isEqualTo(NEW_STORAGE_KEY);
        assertThat(context.storageService().storedObject().storageKey())
                .isEqualTo(new StorageKey(NEW_STORAGE_KEY));
        assertThat(context.storageService().storedObject().contentType())
                .isEqualTo("image/jpeg");
        assertThat(context.storageService().deletedKeys()).isEmpty();
        assertThat(context.commitCoordinator().actions()).hasSize(1);

        context.commitCoordinator().actions().getFirst().run();

        assertThat(context.storageService().deletedKeys())
                .containsExactly(new StorageKey(OLD_STORAGE_KEY));
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
        assertThat(context.commitCoordinator().actions()).isEmpty();
    }

    @Test
    void shouldRemoveCustomAvatarAndCleanupOldAvatarAfterCommit() {
        TestContext context = new TestContext(userWithCustomAvatar());

        User updated = context.service().removeAvatar(new RemoveCurrentUserAvatarCommand(
                new AuthenticatedUser(USER_ID),
                CURRENT_TIME
        ));

        assertThat(updated.avatarUrl()).isEqualTo(GOOGLE_AVATAR_URL);
        assertThat(updated.customAvatarStorageKey()).isNull();
        assertThat(updated.hasCustomAvatar()).isFalse();
        assertThat(context.storageService().deletedKeys()).isEmpty();

        context.commitCoordinator().actions().getFirst().run();

        assertThat(context.storageService().deletedKeys())
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

    private record TestContext(
            FakeUserRepository userRepository,
            FakeStorageService storageService,
            FakeCommitCoordinator commitCoordinator,
            TransactionalCurrentUserAvatarService service
    ) {
        private TestContext(User user) {
            this(
                    new FakeUserRepository(user),
                    new FakeStorageService(),
                    new FakeCommitCoordinator()
            );
        }

        private TestContext(
                FakeUserRepository userRepository,
                FakeStorageService storageService,
                FakeCommitCoordinator commitCoordinator
        ) {
            this(
                    userRepository,
                    storageService,
                    commitCoordinator,
                    new TransactionalCurrentUserAvatarService(
                            userRepository,
                            new UserAvatarImageProcessor(new FakeImageProcessor()),
                            new DeterministicUserAvatarStorageKeyFactory(),
                            storageService,
                            new FakeRollbackCoordinator(),
                            commitCoordinator
                    )
            );
        }
    }

    private static final class FakeUserRepository implements UserRepository {

        private final User activeUser;
        private boolean failUpdateCustomAvatar;

        private FakeUserRepository(User activeUser) {
            this.activeUser = activeUser;
        }

        @Override
        public Optional<User> findActiveByIdForUpdate(UUID id) {
            return activeUser.id().equals(id)
                    ? Optional.of(activeUser)
                    : Optional.empty();
        }

        @Override
        public User updateCustomAvatar(
                UUID id,
                String storageKey,
                Instant updatedAt
        ) {
            if (failUpdateCustomAvatar) {
                throw new RuntimeException("update failed");
            }

            return new User(
                    activeUser.id(),
                    activeUser.googleSubject(),
                    activeUser.displayName(),
                    activeUser.avatarUrl(),
                    storageKey,
                    updatedAt,
                    activeUser.createdAt(),
                    updatedAt,
                    activeUser.deletedAt()
            );
        }

        @Override
        public User clearCustomAvatar(UUID id, Instant updatedAt) {
            return new User(
                    activeUser.id(),
                    activeUser.googleSubject(),
                    activeUser.displayName(),
                    activeUser.avatarUrl(),
                    activeUser.createdAt(),
                    updatedAt
            );
        }

        @Override
        public User save(User user) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<User> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<User> findByGoogleSubject(String googleSubject) {
            throw new UnsupportedOperationException();
        }

        private User activeUser() {
            return activeUser;
        }
    }

    private static final class FakeStorageService implements StorageService {

        private StorageObjectWrite storedObject;
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
            throw new UnsupportedOperationException();
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
        }

        private StorageObjectWrite storedObject() {
            return storedObject;
        }

        private List<StorageKey> deletedKeys() {
            return deletedKeys;
        }
    }

    private static final class FakeCommitCoordinator
            implements TransactionCommitCoordinator {

        private final List<Runnable> actions = new ArrayList<>();

        @Override
        public void onCommit(Runnable action) {
            actions.add(action);
        }

        private List<Runnable> actions() {
            return actions;
        }
    }

    private static final class FakeRollbackCoordinator
            implements TransactionRollbackCoordinator {

        @Override
        public void onRollback(Runnable action) {
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
