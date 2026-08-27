package memory_map.backend.ratelimit;

import java.time.Instant;

public interface RateLimiter {

    RateLimitDecision tryConsume(
            RateLimitKey key,
            RateLimitRule rule,
            Instant currentTime
    );
}
