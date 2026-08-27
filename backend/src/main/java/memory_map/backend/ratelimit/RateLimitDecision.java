package memory_map.backend.ratelimit;

import java.time.Duration;
import java.util.Objects;

public record RateLimitDecision(

        boolean allowed,

        Duration retryAfter

) {
    public RateLimitDecision {
        Objects.requireNonNull(retryAfter, "retryAfter must not be null");

        if (retryAfter.isNegative()) {
            throw new IllegalArgumentException(
                    "retryAfter must not be negative"
            );
        }
    }

    public static RateLimitDecision accepted() {
        return new RateLimitDecision(true, Duration.ZERO);
    }

    public static RateLimitDecision rejected(Duration retryAfter) {
        return new RateLimitDecision(false, retryAfter);
    }
}
