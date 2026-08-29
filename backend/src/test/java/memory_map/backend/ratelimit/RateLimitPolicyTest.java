package memory_map.backend.ratelimit;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;

class RateLimitPolicyTest {

    private final RateLimitPolicy policy =
            new RateLimitPolicy(RateLimitTestSupport.properties());

    @Test
    void shouldMapGoogleLoginToIpScopedAuthLogin() {
        RateLimitRule rule = ruleFor("POST", "/api/v1/auth/google");

        assertThat(rule.category()).isEqualTo(RateLimitCategory.AUTH_LOGIN);
        assertThat(rule.identity()).isEqualTo(RateLimitIdentity.CLIENT_IP);
    }

    @Test
    void shouldMapRefreshAndLogoutToIpScopedAuthPolicies() {
        assertThat(ruleFor("POST", "/api/v1/auth/refresh").category())
                .isEqualTo(RateLimitCategory.AUTH_REFRESH);
        assertThat(ruleFor("POST", "/api/v1/auth/logout").category())
                .isEqualTo(RateLimitCategory.AUTH_LOGOUT);
        assertThat(ruleFor("POST", "/api/v1/auth/refresh").identity())
                .isEqualTo(RateLimitIdentity.CLIENT_IP);
    }

    @Test
    void shouldMapInviteAcceptToAuthenticatedUserPolicy() {
        RateLimitRule rule = ruleFor(
                "POST",
                "/api/v1/invites/raw-token/accept"
        );

        assertThat(rule.category()).isEqualTo(RateLimitCategory.INVITE_ACCEPT);
        assertThat(rule.identity())
                .isEqualTo(RateLimitIdentity.AUTHENTICATED_USER);
    }

    @Test
    void shouldMapMediaUploadToUploadPolicy() {
        RateLimitRule rule = ruleFor(
                "POST",
                "/api/v1/memories/memory-1/media"
        );

        assertThat(rule.category()).isEqualTo(RateLimitCategory.MEDIA_UPLOAD);
        assertThat(rule.identity())
                .isEqualTo(RateLimitIdentity.AUTHENTICATED_USER);
    }

    @Test
    void shouldMapAvatarUploadToUploadPolicy() {
        RateLimitRule rule = ruleFor("PUT", "/api/v1/me/avatar");

        assertThat(rule.category()).isEqualTo(RateLimitCategory.MEDIA_UPLOAD);
        assertThat(rule.identity())
                .isEqualTo(RateLimitIdentity.AUTHENTICATED_USER);
    }

    @Test
    void shouldMapPrivateMediaReadsToPermissiveReadPolicy() {
        assertThat(ruleFor(
                "GET",
                "/api/v1/media/media-1/thumbnail"
        ).category()).isEqualTo(RateLimitCategory.PRIVATE_MEDIA_READ);
        assertThat(ruleFor(
                "GET",
                "/api/v1/media/media-1/display"
        ).category()).isEqualTo(RateLimitCategory.PRIVATE_MEDIA_READ);
        assertThat(ruleFor(
                "GET",
                "/api/v1/me/avatar"
        ).category()).isEqualTo(RateLimitCategory.PRIVATE_MEDIA_READ);
        assertThat(ruleFor(
                "GET",
                "/api/v1/me/avatar/1768039200000"
        ).category()).isEqualTo(RateLimitCategory.PRIVATE_MEDIA_READ);
    }

    @Test
    void shouldMapSoundtrackAudioToRangeCompatiblePolicy() {
        RateLimitRule rule = ruleFor(
                "GET",
                "/api/v1/stories/story-1/soundtrack/audio"
        );

        assertThat(rule.category())
                .isEqualTo(RateLimitCategory.SOUNDTRACK_STREAM);
        assertThat(rule.capacity()).isEqualTo(240);
    }

    @Test
    void shouldMapNormalMutationsWithoutLimitingNormalGets() {
        assertThat(ruleFor("POST", "/api/v1/stories").category())
                .isEqualTo(RateLimitCategory.NORMAL_MUTATION);
        assertThat(ruleFor("DELETE", "/api/v1/me").category())
                .isEqualTo(RateLimitCategory.NORMAL_MUTATION);
        assertThat(ruleFor("DELETE", "/api/v1/me/avatar").category())
                .isEqualTo(RateLimitCategory.NORMAL_MUTATION);
        assertThat(ruleFor("PATCH", "/api/v1/me/display-name").category())
                .isEqualTo(RateLimitCategory.NORMAL_MUTATION);
        assertThat(ruleFor("PATCH", "/api/v1/stories/story-1").category())
                .isEqualTo(RateLimitCategory.NORMAL_MUTATION);
        assertThat(ruleFor(
                "POST",
                "/api/v1/stories/story-1/memories"
        ).category()).isEqualTo(RateLimitCategory.NORMAL_MUTATION);
        assertThat(policy.ruleFor(request("GET", "/api/v1/stories")))
                .isEmpty();
    }

    private RateLimitRule ruleFor(String method, String path) {
        return policy.ruleFor(request(method, path)).orElseThrow();
    }

    private static MockHttpServletRequest request(
            String method,
            String path
    ) {
        return new MockHttpServletRequest(method, path);
    }
}
