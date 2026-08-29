package memory_map.backend.account.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalCurrentUserProfileServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldTrimAndUpdateDisplayName() {
        FakeUserRepository userRepository = new FakeUserRepository();
        TransactionalCurrentUserProfileService service =
                new TransactionalCurrentUserProfileService(userRepository);

        User updated = service.updateDisplayName(command("  Анна-Мария  "));

        assertThat(updated.displayName()).isEqualTo("Анна-Мария");
        assertThat(updated.displayNameCustomized()).isTrue();
        assertThat(userRepository.receivedDisplayName).isEqualTo("Анна-Мария");
        assertThat(userRepository.receivedUpdatedAt).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldPreserveAllowedNameCharacters() {
        FakeUserRepository userRepository = new FakeUserRepository();
        TransactionalCurrentUserProfileService service =
                new TransactionalCurrentUserProfileService(userRepository);

        User updated = service.updateDisplayName(command("Jean-Luc O'Connor"));

        assertThat(updated.displayName()).isEqualTo("Jean-Luc O'Connor");
    }

    @Test
    void shouldRejectInvalidDisplayNames() {
        TransactionalCurrentUserProfileService service =
                new TransactionalCurrentUserProfileService(
                        new FakeUserRepository()
                );

        assertThatThrownBy(() -> service.updateDisplayName(command("   ")))
                .isInstanceOf(InvalidDisplayNameException.class);
        assertThatThrownBy(() -> service.updateDisplayName(command("A\nB")))
                .isInstanceOf(InvalidDisplayNameException.class);
        assertThatThrownBy(() -> service.updateDisplayName(command(
                "A".repeat(TransactionalCurrentUserProfileService
                        .DISPLAY_NAME_MAX_LENGTH + 1)
        )))
                .isInstanceOf(InvalidDisplayNameException.class);
    }

    @Test
    void shouldRejectMissingOrTombstonedCurrentUser() {
        FakeUserRepository userRepository = new FakeUserRepository()
                .withoutActiveUser();
        TransactionalCurrentUserProfileService service =
                new TransactionalCurrentUserProfileService(userRepository);

        assertThatThrownBy(() -> service.updateDisplayName(command("Anna")))
                .isInstanceOf(CurrentUserProfileUnavailableException.class);
        assertThat(userRepository.updateDisplayNameCalls).isZero();
    }

    private static UpdateCurrentUserDisplayNameCommand command(
            String displayName
    ) {
        return new UpdateCurrentUserDisplayNameCommand(
                new AuthenticatedUser(USER_ID),
                displayName,
                CURRENT_TIME
        );
    }

    private static final class FakeUserRepository implements UserRepository {

        private Optional<User> activeUser = Optional.of(user(
                "Ada Lovelace",
                false
        ));
        private String receivedDisplayName;
        private Instant receivedUpdatedAt;
        private int updateDisplayNameCalls;

        @Override
        public User save(User user) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<User> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<User> findActiveByIdForUpdate(UUID id) {
            return activeUser;
        }

        @Override
        public Optional<User> findByGoogleSubject(String googleSubject) {
            throw new UnsupportedOperationException();
        }

        @Override
        public User updateDisplayName(
                UUID id,
                String displayName,
                Instant updatedAt
        ) {
            updateDisplayNameCalls++;
            receivedDisplayName = displayName;
            receivedUpdatedAt = updatedAt;

            return user(displayName, true);
        }

        private FakeUserRepository withoutActiveUser() {
            activeUser = Optional.empty();
            return this;
        }

        private static User user(
                String displayName,
                boolean displayNameCustomized
        ) {
            return new User(
                    USER_ID,
                    "google-subject-123",
                    displayName,
                    displayNameCustomized,
                    "https://example.com/avatar.png",
                    "users/%s/avatar/avatar-object".formatted(USER_ID),
                    CURRENT_TIME.minusSeconds(10),
                    CURRENT_TIME.minusSeconds(100),
                    CURRENT_TIME,
                    null
            );
        }
    }
}
