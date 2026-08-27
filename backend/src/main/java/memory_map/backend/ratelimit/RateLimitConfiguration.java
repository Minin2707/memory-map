package memory_map.backend.ratelimit;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tools.jackson.databind.json.JsonMapper;

import java.time.Clock;

@Configuration
@EnableConfigurationProperties(RateLimitProperties.class)
public class RateLimitConfiguration {

    @Bean
    RateLimitPolicy rateLimitPolicy(RateLimitProperties properties) {
        return new RateLimitPolicy(properties);
    }

    @Bean
    RateLimiter rateLimiter(RateLimitProperties properties) {
        return new InMemoryTokenBucketRateLimiter(
                properties.maxBuckets(),
                properties.staleAfter()
        );
    }

    @Bean
    ClientIpResolver clientIpResolver(RateLimitProperties properties) {
        return new TrustedProxyClientIpResolver(properties.trustedProxies());
    }

    @Bean
    RequestRateLimitFilter requestRateLimitFilter(
            RateLimitPolicy policy,
            RateLimiter rateLimiter,
            ClientIpResolver clientIpResolver,
            Clock clock,
            JsonMapper jsonMapper,
            RateLimitProperties properties
    ) {
        return new RequestRateLimitFilter(
                policy,
                rateLimiter,
                clientIpResolver,
                clock,
                jsonMapper,
                properties.enabled()
        );
    }
}
