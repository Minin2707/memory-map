package memory_map.backend.ratelimit;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import java.io.IOException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import tools.jackson.databind.json.JsonMapper;

import static org.assertj.core.api.Assertions.assertThat;

class RequestRateLimitFilterTest {

    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final String USER_ID =
            "00000000-0000-0000-0000-000000000001";

    private final RateLimitPolicy policy =
            new RateLimitPolicy(RateLimitTestSupport.properties());
    private final FakeRateLimiter rateLimiter = new FakeRateLimiter();
    private final RequestRateLimitFilter filter = new RequestRateLimitFilter(
            policy,
            rateLimiter,
            new TrustedProxyClientIpResolver(List.of()),
            Clock.fixed(CURRENT_TIME, ZoneOffset.UTC),
            JsonMapper.builder().build(),
            true
    );

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void shouldAllowRequestsUnderLimit() throws Exception {
        MockHttpServletRequest request =
                request("POST", "/api/v1/auth/google");
        request.setRemoteAddr("203.0.113.10");
        CountingFilterChain chain = new CountingFilterChain();

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        assertThat(chain.callCount()).isEqualTo(1);
        assertThat(rateLimiter.receivedKey()).isEqualTo(new RateLimitKey(
                RateLimitCategory.AUTH_LOGIN,
                "ip:203.0.113.10"
        ));
    }

    @Test
    void shouldIgnoreSpoofedForwardedForWhenRemoteAddressIsNotTrusted()
            throws Exception {

        MockHttpServletRequest request =
                request("POST", "/api/v1/auth/google");
        request.setRemoteAddr("203.0.113.10");
        request.addHeader("X-Forwarded-For", "198.51.100.99");
        CountingFilterChain chain = new CountingFilterChain();

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        assertThat(chain.callCount()).isEqualTo(1);
        assertThat(rateLimiter.receivedKey()).isEqualTo(new RateLimitKey(
                RateLimitCategory.AUTH_LOGIN,
                "ip:203.0.113.10"
        ));
    }

    @Test
    void shouldUseTrustedProxyResolvedClientForIpScopedPolicies()
            throws Exception {

        RequestRateLimitFilter trustedProxyFilter =
                filterWithTrustedProxies("10.0.0.0/24");
        MockHttpServletRequest request =
                request("POST", "/api/v1/auth/google");
        request.setRemoteAddr("10.0.0.10");
        request.addHeader("X-Forwarded-For", "198.51.100.20");
        CountingFilterChain chain = new CountingFilterChain();

        trustedProxyFilter.doFilter(
                request,
                new MockHttpServletResponse(),
                chain
        );

        assertThat(chain.callCount()).isEqualTo(1);
        assertThat(rateLimiter.receivedKey()).isEqualTo(new RateLimitKey(
                RateLimitCategory.AUTH_LOGIN,
                "ip:198.51.100.20"
        ));
    }

    @Test
    void shouldKeepMultipleClientsBehindTrustedProxyIndependent()
            throws Exception {

        RequestRateLimitFilter trustedProxyFilter =
                filterWithTrustedProxies("10.0.0.0/24");
        MockHttpServletRequest firstRequest =
                request("POST", "/api/v1/auth/google");
        firstRequest.setRemoteAddr("10.0.0.10");
        firstRequest.addHeader("X-Forwarded-For", "198.51.100.20");
        MockHttpServletRequest secondRequest =
                request("POST", "/api/v1/auth/google");
        secondRequest.setRemoteAddr("10.0.0.10");
        secondRequest.addHeader("X-Forwarded-For", "198.51.100.21");

        trustedProxyFilter.doFilter(
                firstRequest,
                new MockHttpServletResponse(),
                new CountingFilterChain()
        );
        RateLimitKey firstKey = rateLimiter.receivedKey();

        trustedProxyFilter.doFilter(
                secondRequest,
                new MockHttpServletResponse(),
                new CountingFilterChain()
        );

        assertThat(firstKey).isEqualTo(new RateLimitKey(
                RateLimitCategory.AUTH_LOGIN,
                "ip:198.51.100.20"
        ));
        assertThat(rateLimiter.receivedKey()).isEqualTo(new RateLimitKey(
                RateLimitCategory.AUTH_LOGIN,
                "ip:198.51.100.21"
        ));
    }

    @Test
    void shouldReturnSafeProblemDetailWhenLimitIsExceeded()
            throws Exception {

        rateLimiter.decision =
                RateLimitDecision.rejected(Duration.ofSeconds(7));
        MockHttpServletRequest request =
                request("POST", "/api/v1/auth/google");
        request.setRemoteAddr("203.0.113.10");
        MockHttpServletResponse response = new MockHttpServletResponse();
        CountingFilterChain chain = new CountingFilterChain();

        filter.doFilter(request, response, chain);

        assertThat(chain.callCount()).isZero();
        assertThat(response.getStatus()).isEqualTo(429);
        assertThat(response.getHeader(HttpHeaders.RETRY_AFTER))
                .isEqualTo("7");
        assertThat(response.getContentType())
                .isEqualTo(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        assertThat(response.getContentAsString())
                .contains("Too many requests")
                .doesNotContain("203.0.113.10")
                .doesNotContain(USER_ID)
                .doesNotContain("ip:")
                .doesNotContain("user:");
    }

    @Test
    void shouldUseAuthenticatedUserIdentityForProtectedEndpoints()
            throws Exception {

        authenticateUser();
        MockHttpServletRequest request = request(
                "POST",
                "/api/v1/memories/memory-1/media"
        );

        filter.doFilter(
                request,
                new MockHttpServletResponse(),
                new CountingFilterChain()
        );

        assertThat(rateLimiter.receivedKey()).isEqualTo(new RateLimitKey(
                RateLimitCategory.MEDIA_UPLOAD,
                "user:" + USER_ID
        ));
    }

    @Test
    void shouldKeepAuthenticatedUserIdentityIndependentFromClientIpResolver()
            throws Exception {

        authenticateUser();
        MockHttpServletRequest request = request(
                "POST",
                "/api/v1/memories/memory-1/media"
        );
        request.setRemoteAddr("10.0.0.10");
        request.addHeader("X-Forwarded-For", "198.51.100.20");

        filterWithTrustedProxies("10.0.0.0/24").doFilter(
                request,
                new MockHttpServletResponse(),
                new CountingFilterChain()
        );

        assertThat(rateLimiter.receivedKey()).isEqualTo(new RateLimitKey(
                RateLimitCategory.MEDIA_UPLOAD,
                "user:" + USER_ID
        ));
    }

    @Test
    void shouldRejectMediaUploadBeforeControllerWorkWhenLimitIsExceeded()
            throws Exception {

        authenticateUser();
        rateLimiter.decision =
                RateLimitDecision.rejected(Duration.ofSeconds(12));
        MockHttpServletResponse response = new MockHttpServletResponse();
        CountingFilterChain chain = new CountingFilterChain();

        filter.doFilter(
                request("POST", "/api/v1/memories/memory-1/media"),
                response,
                chain
        );

        assertThat(chain.callCount()).isZero();
        assertThat(response.getStatus()).isEqualTo(429);
        assertThat(response.getHeader(HttpHeaders.RETRY_AFTER))
                .isEqualTo("12");
        assertThat(rateLimiter.receivedRule().category())
                .isEqualTo(RateLimitCategory.MEDIA_UPLOAD);
    }

    @Test
    void shouldNotRateLimitProtectedEndpointWhenAuthenticationIsMissing()
            throws Exception {

        MockHttpServletRequest request = request(
                "GET",
                "/api/v1/media/media-1/thumbnail"
        );
        CountingFilterChain chain = new CountingFilterChain();

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        assertThat(chain.callCount()).isEqualTo(1);
        assertThat(rateLimiter.callCount()).isZero();
    }

    @Test
    void shouldLeaveUnmatchedRequestsAlone() throws Exception {
        MockHttpServletRequest request = request("GET", "/api/v1/stories");
        CountingFilterChain chain = new CountingFilterChain();

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        assertThat(chain.callCount()).isEqualTo(1);
        assertThat(rateLimiter.callCount()).isZero();
    }

    @Test
    void shouldAllowPrivateMediaPlaybackLikeBurstBelowLimit()
            throws Exception {

        authenticateUser();
        CountingFilterChain chain = new CountingFilterChain();
        MockHttpServletResponse response = new MockHttpServletResponse();

        for (int index = 0; index < 30; index++) {
            filter.doFilter(
                    request("GET", "/api/v1/media/media-" + index +
                            "/thumbnail"),
                    response,
                    chain
            );
            filter.doFilter(
                    request("GET", "/api/v1/media/media-" + index +
                            "/display"),
                    response,
                    chain
            );
        }

        assertThat(chain.callCount()).isEqualTo(60);
        assertThat(rateLimiter.callCount()).isEqualTo(60);
    }

    @Test
    void shouldAllowLegitimateSoundtrackRangeBurstBelowLimit()
            throws Exception {

        authenticateUser();
        CountingFilterChain chain = new CountingFilterChain();

        for (int index = 0; index < 20; index++) {
            MockHttpServletRequest request = request(
                    "GET",
                    "/api/v1/stories/story-1/soundtrack/audio"
            );
            request.addHeader(HttpHeaders.RANGE, "bytes=%d-".formatted(index));
            filter.doFilter(
                    request,
                    new MockHttpServletResponse(),
                    chain
            );
        }

        assertThat(chain.callCount()).isEqualTo(20);
        assertThat(rateLimiter.receivedRule().category())
                .isEqualTo(RateLimitCategory.SOUNDTRACK_STREAM);
    }

    @Test
    void shouldEventuallyRejectSoundtrackAbuse() throws Exception {
        authenticateUser();
        rateLimiter.decision =
                RateLimitDecision.rejected(Duration.ofSeconds(1));
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(
                request("GET", "/api/v1/stories/story-1/soundtrack/audio"),
                response,
                new CountingFilterChain()
        );

        assertThat(response.getStatus()).isEqualTo(429);
        assertThat(rateLimiter.receivedRule().category())
                .isEqualTo(RateLimitCategory.SOUNDTRACK_STREAM);
    }

    private static MockHttpServletRequest request(
            String method,
            String path
    ) {
        return new MockHttpServletRequest(method, path);
    }

    private RequestRateLimitFilter filterWithTrustedProxies(
            String... trustedProxies
    ) {
        return new RequestRateLimitFilter(
                policy,
                rateLimiter,
                new TrustedProxyClientIpResolver(List.of(trustedProxies)),
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC),
                JsonMapper.builder().build(),
                true
        );
    }

    private static void authenticateUser() {
        Jwt jwt = Jwt.withTokenValue("access-token")
                .header("alg", "none")
                .subject(USER_ID)
                .issuedAt(CURRENT_TIME)
                .expiresAt(CURRENT_TIME.plusSeconds(900))
                .build();
        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(jwt, AuthorityUtils.NO_AUTHORITIES)
        );
    }

    private static final class FakeRateLimiter implements RateLimiter {

        private RateLimitDecision decision = RateLimitDecision.accepted();
        private RateLimitKey receivedKey;
        private RateLimitRule receivedRule;
        private int callCount;

        @Override
        public RateLimitDecision tryConsume(
                RateLimitKey key,
                RateLimitRule rule,
                Instant currentTime
        ) {
            receivedKey = key;
            receivedRule = rule;
            callCount++;
            return decision;
        }

        private RateLimitKey receivedKey() {
            return receivedKey;
        }

        private RateLimitRule receivedRule() {
            return receivedRule;
        }

        private int callCount() {
            return callCount;
        }
    }

    private static final class CountingFilterChain implements FilterChain {

        private int callCount;

        @Override
        public void doFilter(
                ServletRequest request,
                ServletResponse response
        ) throws IOException, ServletException {
            callCount++;
        }

        private int callCount() {
            return callCount;
        }
    }
}
