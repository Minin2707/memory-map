package memory_map.backend.ratelimit;

import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;

class InMemoryTokenBucketRateLimiterTest {

    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldAllowRequestsUnderLimit() {
        InMemoryTokenBucketRateLimiter limiter =
                new InMemoryTokenBucketRateLimiter(100, Duration.ofMinutes(10));
        RateLimitRule rule = rule(2, 2, Duration.ofMinutes(1));
        RateLimitKey key = key("user-a");

        assertThat(limiter.tryConsume(key, rule, CURRENT_TIME).allowed())
                .isTrue();
        assertThat(limiter.tryConsume(key, rule, CURRENT_TIME).allowed())
                .isTrue();
    }

    @Test
    void shouldRejectRequestsOverLimitWithRetryAfter() {
        InMemoryTokenBucketRateLimiter limiter =
                new InMemoryTokenBucketRateLimiter(100, Duration.ofMinutes(10));
        RateLimitRule rule = rule(1, 1, Duration.ofMinutes(1));
        RateLimitKey key = key("user-a");

        assertThat(limiter.tryConsume(key, rule, CURRENT_TIME).allowed())
                .isTrue();

        RateLimitDecision decision =
                limiter.tryConsume(key, rule, CURRENT_TIME);

        assertThat(decision.allowed()).isFalse();
        assertThat(decision.retryAfter()).isEqualTo(Duration.ofSeconds(60));
    }

    @Test
    void shouldKeepDifferentKeysIndependent() {
        InMemoryTokenBucketRateLimiter limiter =
                new InMemoryTokenBucketRateLimiter(100, Duration.ofMinutes(10));
        RateLimitRule rule = rule(1, 1, Duration.ofMinutes(1));

        assertThat(limiter.tryConsume(key("user-a"), rule, CURRENT_TIME)
                .allowed()).isTrue();
        assertThat(limiter.tryConsume(key("user-b"), rule, CURRENT_TIME)
                .allowed()).isTrue();
    }

    @Test
    void shouldRefillExpiredBucketWithoutSleeping() {
        InMemoryTokenBucketRateLimiter limiter =
                new InMemoryTokenBucketRateLimiter(100, Duration.ofMinutes(10));
        RateLimitRule rule = rule(1, 1, Duration.ofMinutes(1));
        RateLimitKey key = key("user-a");

        assertThat(limiter.tryConsume(key, rule, CURRENT_TIME).allowed())
                .isTrue();
        assertThat(limiter.tryConsume(key, rule, CURRENT_TIME).allowed())
                .isFalse();
        assertThat(limiter.tryConsume(
                key,
                rule,
                CURRENT_TIME.plus(Duration.ofMinutes(1))
        ).allowed()).isTrue();
    }

    @Test
    void shouldBeThreadSafeForConcurrentRequests() throws Exception {
        InMemoryTokenBucketRateLimiter limiter =
                new InMemoryTokenBucketRateLimiter(100, Duration.ofMinutes(10));
        RateLimitRule rule = rule(20, 20, Duration.ofMinutes(1));
        RateLimitKey key = key("user-a");
        ExecutorService executor = Executors.newFixedThreadPool(8);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<Boolean>> futures = new ArrayList<>();

        for (int index = 0; index < 50; index++) {
            futures.add(executor.submit(() -> {
                start.await();
                return limiter.tryConsume(key, rule, CURRENT_TIME).allowed();
            }));
        }

        start.countDown();

        int allowed = 0;
        for (Future<Boolean> future : futures) {
            if (future.get()) {
                allowed++;
            }
        }

        executor.shutdownNow();
        assertThat(allowed).isEqualTo(20);
    }

    @Test
    void shouldEvictStaleBucketsLazily() {
        InMemoryTokenBucketRateLimiter limiter =
                new InMemoryTokenBucketRateLimiter(100, Duration.ofMinutes(10));
        RateLimitRule rule = rule(1, 1, Duration.ofMinutes(1));

        limiter.tryConsume(key("user-a"), rule, CURRENT_TIME);
        limiter.tryConsume(
                key("user-b"),
                rule,
                CURRENT_TIME.plus(Duration.ofMinutes(11))
        );

        assertThat(limiter.bucketCount()).isEqualTo(1);
    }

    @Test
    void shouldKeepBucketMapBounded() {
        InMemoryTokenBucketRateLimiter limiter =
                new InMemoryTokenBucketRateLimiter(3, Duration.ofHours(1));
        RateLimitRule rule = rule(1, 1, Duration.ofMinutes(1));

        limiter.tryConsume(key("user-a"), rule, CURRENT_TIME);
        limiter.tryConsume(key("user-b"), rule, CURRENT_TIME);
        limiter.tryConsume(key("user-c"), rule, CURRENT_TIME);
        limiter.tryConsume(key("user-d"), rule, CURRENT_TIME);

        assertThat(limiter.bucketCount()).isLessThanOrEqualTo(3);
    }

    private static RateLimitRule rule(
            int capacity,
            int refillTokens,
            Duration refillPeriod
    ) {
        return new RateLimitRule(
                RateLimitCategory.MEDIA_UPLOAD,
                RateLimitIdentity.AUTHENTICATED_USER,
                capacity,
                refillTokens,
                refillPeriod
        );
    }

    private static RateLimitKey key(String identity) {
        return new RateLimitKey(
                RateLimitCategory.MEDIA_UPLOAD,
                identity
        );
    }
}
