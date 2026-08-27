package memory_map.backend.ratelimit;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

public class InMemoryTokenBucketRateLimiter implements RateLimiter {

    private final int maxBuckets;
    private final Duration staleAfter;
    private final Map<RateLimitKey, Bucket> buckets =
            new ConcurrentHashMap<>();
    private final AtomicLong nextCleanupEpochSecond = new AtomicLong();

    public InMemoryTokenBucketRateLimiter(
            int maxBuckets,
            Duration staleAfter
    ) {
        if (maxBuckets <= 0) {
            throw new IllegalArgumentException("maxBuckets must be positive");
        }

        Objects.requireNonNull(staleAfter, "staleAfter must not be null");
        if (staleAfter.isZero() || staleAfter.isNegative()) {
            throw new IllegalArgumentException("staleAfter must be positive");
        }

        this.maxBuckets = maxBuckets;
        this.staleAfter = staleAfter;
    }

    @Override
    public RateLimitDecision tryConsume(
            RateLimitKey key,
            RateLimitRule rule,
            Instant currentTime
    ) {
        Objects.requireNonNull(key, "key must not be null");
        Objects.requireNonNull(rule, "rule must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        cleanupIfNeeded(currentTime);

        Bucket bucket = buckets.computeIfAbsent(
                key,
                ignored -> Bucket.full(rule, currentTime)
        );

        RateLimitDecision decision = bucket.tryConsume(rule, currentTime);
        enforceMaxBuckets();
        return decision;
    }

    int bucketCount() {
        return buckets.size();
    }

    private void cleanupIfNeeded(Instant currentTime) {
        long currentEpochSecond = currentTime.getEpochSecond();
        long scheduled = nextCleanupEpochSecond.get();
        if (currentEpochSecond < scheduled) {
            return;
        }

        long next = currentEpochSecond + staleAfter.toSeconds();
        if (!nextCleanupEpochSecond.compareAndSet(scheduled, next)) {
            return;
        }

        Instant staleBefore = currentTime.minus(staleAfter);
        buckets.entrySet().removeIf(entry ->
                entry.getValue().lastSeen().isBefore(staleBefore));
    }

    private void enforceMaxBuckets() {
        int overflow = buckets.size() - maxBuckets;
        if (overflow <= 0) {
            return;
        }

        buckets.entrySet()
                .stream()
                .sorted(Comparator.comparing(entry ->
                        entry.getValue().lastSeen()))
                .limit(overflow)
                .map(Map.Entry::getKey)
                .toList()
                .forEach(buckets::remove);
    }

    private static final class Bucket {

        private double tokens;
        private Instant lastRefill;
        private Instant lastSeen;

        private Bucket(double tokens, Instant currentTime) {
            this.tokens = tokens;
            this.lastRefill = currentTime;
            this.lastSeen = currentTime;
        }

        private static Bucket full(
                RateLimitRule rule,
                Instant currentTime
        ) {
            return new Bucket(rule.capacity(), currentTime);
        }

        private synchronized RateLimitDecision tryConsume(
                RateLimitRule rule,
                Instant currentTime
        ) {
            refill(rule, currentTime);
            lastSeen = currentTime;

            if (tokens >= 1D) {
                tokens -= 1D;
                return RateLimitDecision.accepted();
            }

            return RateLimitDecision.rejected(retryAfter(rule));
        }

        private synchronized Instant lastSeen() {
            return lastSeen;
        }

        private void refill(RateLimitRule rule, Instant currentTime) {
            if (!currentTime.isAfter(lastRefill)) {
                return;
            }

            Duration elapsed = Duration.between(lastRefill, currentTime);
            double refillPeriods = elapsed.toNanos() /
                    (double) rule.refillPeriod().toNanos();
            double refill = refillPeriods * rule.refillTokens();

            tokens = Math.min(rule.capacity(), tokens + refill);
            lastRefill = currentTime;
        }

        private Duration retryAfter(RateLimitRule rule) {
            double missingTokens = Math.max(0D, 1D - tokens);
            double seconds = missingTokens *
                    rule.refillPeriod().toNanos() /
                    rule.refillTokens() /
                    1_000_000_000D;

            return Duration.ofSeconds(Math.max(1L, (long) Math.ceil(seconds)));
        }
    }
}
