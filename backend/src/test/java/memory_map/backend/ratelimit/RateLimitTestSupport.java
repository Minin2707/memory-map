package memory_map.backend.ratelimit;

import java.time.Duration;
import java.util.List;

final class RateLimitTestSupport {

    private RateLimitTestSupport() {
    }

    static RateLimitProperties properties() {
        return new RateLimitProperties(
                true,
                100,
                Duration.ofMinutes(10),
                List.of(),
                policy(8, 8, Duration.ofMinutes(1)),
                policy(20, 20, Duration.ofMinutes(1)),
                policy(30, 30, Duration.ofMinutes(1)),
                policy(10, 10, Duration.ofMinutes(1)),
                policy(12, 60, Duration.ofHours(1)),
                policy(600, 600, Duration.ofMinutes(1)),
                policy(240, 240, Duration.ofMinutes(1)),
                policy(60, 60, Duration.ofMinutes(1))
        );
    }

    static RateLimitProperties.PolicyProperties policy(
            int capacity,
            int refillTokens,
            Duration refillPeriod
    ) {
        return new RateLimitProperties.PolicyProperties(
                capacity,
                refillTokens,
                refillPeriod
        );
    }
}
