package memory_map.backend.ratelimit;

import java.util.Objects;

public record RateLimitKey(

        RateLimitCategory category,

        String identity

) {
    public RateLimitKey {
        Objects.requireNonNull(category, "category must not be null");
        Objects.requireNonNull(identity, "identity must not be null");

        if (identity.isBlank()) {
            throw new IllegalArgumentException("identity must not be blank");
        }
    }

    @Override
    public String toString() {
        return "RateLimitKey[category=%s, identity=<redacted>]"
                .formatted(category);
    }
}
