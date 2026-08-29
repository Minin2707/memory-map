package memory_map.backend.account.repository;

import java.util.Objects;

public record AccountDeletionMediaStorageKeys(

        String thumbnailStorageKey,

        String displayStorageKey

) {
    public AccountDeletionMediaStorageKeys {
        Objects.requireNonNull(
                thumbnailStorageKey,
                "thumbnailStorageKey must not be null"
        );
        Objects.requireNonNull(
                displayStorageKey,
                "displayStorageKey must not be null"
        );
    }
}
