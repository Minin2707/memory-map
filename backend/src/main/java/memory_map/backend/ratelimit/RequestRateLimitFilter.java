package memory_map.backend.ratelimit;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.net.URI;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import tools.jackson.databind.json.JsonMapper;

public class RequestRateLimitFilter extends OncePerRequestFilter {

    private static final URI RATE_LIMIT_PROBLEM_TYPE =
            URI.create("/api/v1/problems/rate-limit-exceeded");

    private final RateLimitPolicy policy;
    private final RateLimiter rateLimiter;
    private final ClientIpResolver clientIpResolver;
    private final Clock clock;
    private final JsonMapper jsonMapper;
    private final boolean enabled;

    public RequestRateLimitFilter(
            RateLimitPolicy policy,
            RateLimiter rateLimiter,
            ClientIpResolver clientIpResolver,
            Clock clock,
            JsonMapper jsonMapper,
            boolean enabled
    ) {
        this.policy = Objects.requireNonNull(policy, "policy must not be null");
        this.rateLimiter = Objects.requireNonNull(
                rateLimiter,
                "rateLimiter must not be null"
        );
        this.clientIpResolver = Objects.requireNonNull(
                clientIpResolver,
                "clientIpResolver must not be null"
        );
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
        this.jsonMapper = Objects.requireNonNull(
                jsonMapper,
                "jsonMapper must not be null"
        );
        this.enabled = enabled;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        if (!enabled) {
            filterChain.doFilter(request, response);
            return;
        }

        Optional<RateLimitRule> maybeRule = policy.ruleFor(request);
        if (maybeRule.isEmpty()) {
            filterChain.doFilter(request, response);
            return;
        }

        RateLimitRule rule = maybeRule.get();
        Optional<RateLimitKey> maybeKey = keyFor(request, rule);
        if (maybeKey.isEmpty()) {
            filterChain.doFilter(request, response);
            return;
        }

        RateLimitDecision decision = rateLimiter.tryConsume(
                maybeKey.get(),
                rule,
                Instant.now(clock)
        );
        if (decision.allowed()) {
            filterChain.doFilter(request, response);
            return;
        }

        writeRejectedResponse(response, decision.retryAfter());
    }

    private Optional<RateLimitKey> keyFor(
            HttpServletRequest request,
            RateLimitRule rule
    ) {
        return switch (rule.identity()) {
            case CLIENT_IP -> clientIpKey(request, rule);
            case AUTHENTICATED_USER -> authenticatedUserKey(rule);
        };
    }

    private Optional<RateLimitKey> clientIpKey(
            HttpServletRequest request,
            RateLimitRule rule
    ) {
        Optional<String> maybeClientIp =
                clientIpResolver.resolveClientIp(request);
        if (maybeClientIp.isEmpty()) {
            return Optional.empty();
        }

        return Optional.of(new RateLimitKey(
                rule.category(),
                "ip:" + maybeClientIp.get()
        ));
    }

    private static Optional<RateLimitKey> authenticatedUserKey(
            RateLimitRule rule
    ) {
        Authentication authentication =
                SecurityContextHolder.getContext().getAuthentication();
        if (!(authentication instanceof JwtAuthenticationToken jwt) ||
                !jwt.isAuthenticated()) {
            return Optional.empty();
        }

        String subject = jwt.getToken().getSubject();
        if (subject == null || subject.isBlank()) {
            return Optional.empty();
        }

        return Optional.of(new RateLimitKey(
                rule.category(),
                "user:" + subject
        ));
    }

    private void writeRejectedResponse(
            HttpServletResponse response,
            Duration retryAfter
    ) throws IOException {
        long retryAfterSeconds = Math.max(
                1L,
                retryAfter.toSeconds()
        );
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.TOO_MANY_REQUESTS,
                "Too many requests"
        );
        problemDetail.setTitle("Too Many Requests");
        problemDetail.setType(RATE_LIMIT_PROBLEM_TYPE);

        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.setHeader(
                HttpHeaders.RETRY_AFTER,
                Long.toString(retryAfterSeconds)
        );
        jsonMapper.writeValue(response.getOutputStream(), problemDetail);
    }
}
