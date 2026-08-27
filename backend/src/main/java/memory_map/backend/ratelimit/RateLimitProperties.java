package memory_map.backend.ratelimit;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;
import java.util.List;
import java.util.Objects;

@ConfigurationProperties(prefix = "app.rate-limit")
@Validated
public record RateLimitProperties(

        boolean enabled,

        int maxBuckets,

        Duration staleAfter,

        List<String> trustedProxies,

        PolicyProperties authLogin,

        PolicyProperties authRefresh,

        PolicyProperties authLogout,

        PolicyProperties inviteAccept,

        PolicyProperties mediaUpload,

        PolicyProperties privateMediaRead,

        PolicyProperties soundtrackStream,

        PolicyProperties normalMutation

) {
    public RateLimitProperties {
        Objects.requireNonNull(staleAfter, "staleAfter must not be null");
        trustedProxies = List.copyOf(Objects.requireNonNull(
                trustedProxies,
                "trustedProxies must not be null"
        ));
        Objects.requireNonNull(authLogin, "authLogin must not be null");
        Objects.requireNonNull(authRefresh, "authRefresh must not be null");
        Objects.requireNonNull(authLogout, "authLogout must not be null");
        Objects.requireNonNull(inviteAccept, "inviteAccept must not be null");
        Objects.requireNonNull(mediaUpload, "mediaUpload must not be null");
        Objects.requireNonNull(
                privateMediaRead,
                "privateMediaRead must not be null"
        );
        Objects.requireNonNull(
                soundtrackStream,
                "soundtrackStream must not be null"
        );
        Objects.requireNonNull(
                normalMutation,
                "normalMutation must not be null"
        );

        if (maxBuckets <= 0) {
            throw new IllegalArgumentException("maxBuckets must be positive");
        }

        if (staleAfter.isZero() || staleAfter.isNegative()) {
            throw new IllegalArgumentException("staleAfter must be positive");
        }
    }

    public RateLimitRule rule(
            RateLimitCategory category,
            RateLimitIdentity identity
    ) {
        return policy(category).rule(category, identity);
    }

    private PolicyProperties policy(RateLimitCategory category) {
        return switch (category) {
            case AUTH_LOGIN -> authLogin;
            case AUTH_REFRESH -> authRefresh;
            case AUTH_LOGOUT -> authLogout;
            case INVITE_ACCEPT -> inviteAccept;
            case MEDIA_UPLOAD -> mediaUpload;
            case PRIVATE_MEDIA_READ -> privateMediaRead;
            case SOUNDTRACK_STREAM -> soundtrackStream;
            case NORMAL_MUTATION -> normalMutation;
        };
    }

    public record PolicyProperties(

            int capacity,

            int refillTokens,

            Duration refillPeriod

    ) {
        public PolicyProperties {
            Objects.requireNonNull(
                    refillPeriod,
                    "refillPeriod must not be null"
            );

            if (capacity <= 0) {
                throw new IllegalArgumentException(
                        "capacity must be positive"
                );
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

        private RateLimitRule rule(
                RateLimitCategory category,
                RateLimitIdentity identity
        ) {
            return new RateLimitRule(
                    category,
                    identity,
                    capacity,
                    refillTokens,
                    refillPeriod
            );
        }
    }
}
