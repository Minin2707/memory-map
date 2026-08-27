package memory_map.backend.ratelimit;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TrustedProxyClientIpResolverTest {

    @Test
    void shouldUseDirectRemoteAddressWithoutTrustedProxy() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of());
        MockHttpServletRequest request = request("203.0.113.10");

        assertThat(resolver.resolveClientIp(request))
                .contains("203.0.113.10");
    }

    @Test
    void shouldPreserveDevelopmentDirectClientBehavior() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of());
        MockHttpServletRequest request = request("127.0.0.1");
        request.addHeader("X-Forwarded-For", "198.51.100.99");

        assertThat(resolver.resolveClientIp(request))
                .contains("127.0.0.1");
    }

    @Test
    void shouldIgnoreSpoofedForwardedForFromUntrustedRemoteAddress() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of("10.0.0.10"));
        MockHttpServletRequest request = request("203.0.113.10");
        request.addHeader("X-Forwarded-For", "198.51.100.99");

        assertThat(resolver.resolveClientIp(request))
                .contains("203.0.113.10");
    }

    @Test
    void shouldResolveClientAddressFromTrustedExactProxy() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of("10.0.0.10"));
        MockHttpServletRequest request = request("10.0.0.10");
        request.addHeader("X-Forwarded-For", "198.51.100.20");

        assertThat(resolver.resolveClientIp(request))
                .contains("198.51.100.20");
    }

    @Test
    void shouldResolveClientAddressFromTrustedProxyCidr() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of("10.0.0.0/24"));
        MockHttpServletRequest request = request("10.0.0.42");
        request.addHeader("X-Forwarded-For", "198.51.100.20");

        assertThat(resolver.resolveClientIp(request))
                .contains("198.51.100.20");
    }

    @Test
    void shouldResolveRightMostUntrustedAddressFromForwardedChain() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of("10.0.0.0/24"));
        MockHttpServletRequest request = request("10.0.0.10");
        request.addHeader(
                "X-Forwarded-For",
                "192.0.2.200, 198.51.100.20, 10.0.0.11"
        );

        assertThat(resolver.resolveClientIp(request))
                .contains("198.51.100.20");
    }

    @Test
    void shouldNotLetSpoofedForwardedChainChooseArbitraryIdentity() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of("10.0.0.0/24"));
        MockHttpServletRequest request = request("10.0.0.10");
        request.addHeader(
                "X-Forwarded-For",
                "192.0.2.200, 198.51.100.20"
        );

        assertThat(resolver.resolveClientIp(request))
                .contains("198.51.100.20");
    }

    @Test
    void shouldFallBackToRemoteAddressWhenTrustedForwardedHeaderIsMalformed() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of("10.0.0.0/24"));
        MockHttpServletRequest request = request("10.0.0.10");
        request.addHeader("X-Forwarded-For", "198.51.100.20, not-an-ip");

        assertThat(resolver.resolveClientIp(request))
                .contains("10.0.0.10");
    }

    @Test
    void shouldSupportIpv6DirectRemoteAddress() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of());
        MockHttpServletRequest request = request("2001:db8::10");

        assertThat(resolver.resolveClientIp(request))
                .contains("2001:db8:0:0:0:0:0:10");
    }

    @Test
    void shouldSupportTrustedIpv6Proxy() {
        TrustedProxyClientIpResolver resolver =
                new TrustedProxyClientIpResolver(List.of("2001:db8::1/128"));
        MockHttpServletRequest request = request("2001:db8::1");
        request.addHeader("X-Forwarded-For", "2001:db8:abcd::42");

        assertThat(resolver.resolveClientIp(request))
                .contains("2001:db8:abcd:0:0:0:0:42");
    }

    @Test
    void shouldRejectInvalidTrustedProxyConfiguration() {
        assertThatThrownBy(() ->
                new TrustedProxyClientIpResolver(List.of("example.test")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private static MockHttpServletRequest request(String remoteAddress) {
        MockHttpServletRequest request = new MockHttpServletRequest(
                "POST",
                "/api/v1/auth/google"
        );
        request.setRemoteAddr(remoteAddress);
        return request;
    }
}
