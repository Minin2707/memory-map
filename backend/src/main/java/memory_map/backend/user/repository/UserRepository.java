package memory_map.backend.user.repository;

import memory_map.backend.user.domain.User;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository {

    User save(User user);

    Optional<User> findById(UUID id);

    default Optional<User> findActiveByIdForUpdate(UUID id) {
        throw new UnsupportedOperationException();
    }

    default boolean existsActiveById(UUID id) {
        throw new UnsupportedOperationException();
    }

    Optional<User> findByGoogleSubject(String googleSubject);

    default User updateGoogleAvatarUrl(
            UUID id,
            String avatarUrl,
            Instant updatedAt
    ) {
        throw new UnsupportedOperationException();
    }

    default User updateGoogleProfileFallback(
            UUID id,
            String displayName,
            String avatarUrl,
            Instant updatedAt
    ) {
        throw new UnsupportedOperationException();
    }

    default User updateDisplayName(
            UUID id,
            String displayName,
            Instant updatedAt
    ) {
        throw new UnsupportedOperationException();
    }

    default User updateCustomAvatar(
            UUID id,
            String storageKey,
            Instant updatedAt
    ) {
        throw new UnsupportedOperationException();
    }

    default User clearCustomAvatar(UUID id, Instant updatedAt) {
        throw new UnsupportedOperationException();
    }

    default boolean tombstoneById(UUID id, Instant deletedAt) {
        throw new UnsupportedOperationException();
    }

}
