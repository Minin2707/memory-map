package memory_map.backend.user.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record User(

        UUID id,

        String googleSubject,

        String displayName,

        boolean displayNameCustomized,

        String avatarUrl,

        String customAvatarStorageKey,

        Instant customAvatarUpdatedAt,

        Instant createdAt,

        Instant updatedAt,

        Instant deletedAt

) {
    public User(
            UUID id,
            String googleSubject,
            String displayName,
            String avatarUrl,
            Instant createdAt,
            Instant updatedAt
    ) {
        this(
                id,
                googleSubject,
                displayName,
                false,
                avatarUrl,
                null,
                null,
                createdAt,
                updatedAt,
                null
        );
    }

    public User(
            UUID id,
            String googleSubject,
            String displayName,
            String avatarUrl,
            Instant createdAt,
            Instant updatedAt,
            Instant deletedAt
    ) {
        this(
                id,
                googleSubject,
                displayName,
                false,
                avatarUrl,
                null,
                null,
                createdAt,
                updatedAt,
                deletedAt
        );
    }

    public User(
            UUID id,
            String googleSubject,
            String displayName,
            String avatarUrl,
            String customAvatarStorageKey,
            Instant customAvatarUpdatedAt,
            Instant createdAt,
            Instant updatedAt,
            Instant deletedAt
    ) {
        this(
                id,
                googleSubject,
                displayName,
                false,
                avatarUrl,
                customAvatarStorageKey,
                customAvatarUpdatedAt,
                createdAt,
                updatedAt,
                deletedAt
        );
    }

    public User {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(displayName, "displayName must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
        Objects.requireNonNull(updatedAt, "updatedAt must not be null");

        if (deletedAt == null && googleSubject == null) {
            throw new NullPointerException("googleSubject must not be null");
        }

        if (googleSubject != null && googleSubject.isBlank()) {
            throw new IllegalArgumentException("googleSubject must not be blank");
        }

        if (displayName.isBlank()) {
            throw new IllegalArgumentException("displayName must not be blank");
        }

        if (customAvatarStorageKey != null &&
                customAvatarStorageKey.isBlank()) {
            throw new IllegalArgumentException(
                    "customAvatarStorageKey must not be blank"
            );
        }

        if ((customAvatarStorageKey == null) !=
                (customAvatarUpdatedAt == null)) {
            throw new IllegalArgumentException(
                    "custom avatar key and timestamp must be set together"
            );
        }
    }

    public boolean isDeleted() {
        return deletedAt != null;
    }

    public boolean hasCustomAvatar() {
        return customAvatarStorageKey != null;
    }
}
