package memory_map.backend.ratelimit;

import java.time.Duration;
import java.util.Objects;

public record RateLimitRule(

        RateLimitCategory category,

        RateLimitIdentity identity,

        int capacity,

        int refillTokens,

        Duration refillPeriod

) {
    public RateLimitRule {
        Objects.requireNonNull(category, "category must not be null");
        Objects.requireNonNull(identity, "identity must not be null");
        Objects.requireNonNull(refillPeriod, "refillPeriod must not be null");

        if (capacity <= 0) {
            throw new IllegalArgumentException("capacity must be positive");
        }

        if (refillTokens <= 0) {
            throw new IllegalArgumentException(
                    "refillTokens must be positive"
            );
        }

        if (refillPeriod.isZero() || refillPeriod.isNegative()) {
            throw new IllegalArgumentException(
                    "refillPeriod must be positive"
            );
        }
    }
}
