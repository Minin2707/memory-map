package memory_map.backend.invite.application;

import org.junit.jupiter.api.Test;

import java.net.URI;
import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultInviteLinkFactoryTest {

    private static final String RAW_TOKEN =
            "abcdefghijklmnopqrstuvwxyzABCDE_0123456789-";

    @Test
    void shouldCreateCanonicalInviteLink() {

        URI link = factory("https://app.memorymap.app")
                .create(RAW_TOKEN);

        assertThat(link.toString())
                .isEqualTo("https://app.memorymap.app/invite/" + RAW_TOKEN);
        assertThat(link.getScheme()).isEqualTo("https");
        assertThat(link.getHost()).isEqualTo("app.memorymap.app");
        assertThat(link.getPath()).isEqualTo("/invite/" + RAW_TOKEN);
        assertThat(link.getQuery()).isNull();
        assertThat(link.getFragment()).isNull();
    }

    @Test
    void shouldNormalizeTrailingSlashBaseUrl() {

        URI link = factory("https://app.memorymap.app/")
                .create(RAW_TOKEN);

        assertThat(link.toString())
                .isEqualTo("https://app.memorymap.app/invite/" + RAW_TOKEN);
    }

    @Test
    void shouldPreserveValidBase64UrlToken() {

        String token = "abc-DEF_012";

        URI link = factory("https://app.memorymap.app").create(token);

        assertThat(link.getPath()).isEqualTo("/invite/" + token);
    }

    @Test
    void shouldAllowLocalHttpBaseUrl() {

        URI link = factory("http://localhost:8080").create(RAW_TOKEN);

        assertThat(link.toString())
                .isEqualTo("http://localhost:8080/invite/" + RAW_TOKEN);
    }

    @Test
    void shouldRejectNullProperties() {

        assertThatThrownBy(() -> new DefaultInviteLinkFactory(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("properties must not be null");
    }

    @Test
    void shouldRejectNullRawToken() {

        assertThatThrownBy(() -> factory("https://app.memorymap.app")
                .create(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("rawToken must not be null");
    }

    @Test
    void shouldRejectBlankRawToken() {

        assertThatThrownBy(() -> factory("https://app.memorymap.app")
                .create("   "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("rawToken must not be blank");
    }

    @Test
    void shouldRejectUnsafeTokenPathSeparator() {

        assertThatThrownBy(() -> factory("https://app.memorymap.app")
                .create("abc/def"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("rawToken must be Base64URL path-safe");
    }

    @Test
    void shouldRejectUnsafeTokenPercentEncoding() {

        assertThatThrownBy(() -> factory("https://app.memorymap.app")
                .create("abc%2Fdef"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("rawToken must be Base64URL path-safe");
    }

    @Test
    void shouldRejectUnsafeTokenPlus() {

        assertThatThrownBy(() -> factory("https://app.memorymap.app")
                .create("abc+def"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("rawToken must be Base64URL path-safe");
    }

    private static DefaultInviteLinkFactory factory(String baseUrl) {
        return new DefaultInviteLinkFactory(
                new InviteProperties(
                        Duration.ofDays(30),
                        URI.create(baseUrl)
                )
        );
    }
}
