package memory_map.backend.media.storage;

import java.util.Objects;

public record StorageKey(String value) {

    public StorageKey {
        Objects.requireNonNull(value, "value must not be null");

        if (value.isBlank()) {
            throw new IllegalArgumentException("value must not be blank");
        }
    }

    @Override
    public String toString() {
        return "StorageKey[redacted]";
    }
}
