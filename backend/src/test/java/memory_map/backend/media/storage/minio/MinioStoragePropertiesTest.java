package memory_map.backend.media.storage.minio;

import org.junit.jupiter.api.Test;

import java.net.URI;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MinioStoragePropertiesTest {

    @Test
    void shouldAllowDisabledPropertiesWithoutSecrets() {
        MinioStorageProperties properties = new MinioStorageProperties(
                false,
                null,
                null,
                null,
                null
        );

        assertThat(properties.enabled()).isFalse();
    }

    @Test
    void shouldCreateEnabledProperties() {
        MinioStorageProperties properties = enabledProperties(
                URI.create("HTTP://localhost:9000/")
        );

        assertThat(properties.enabled()).isTrue();
        assertThat(properties.endpoint())
                .isEqualTo(URI.create("http://localhost:9000"));
        assertThat(properties.accessKey()).isEqualTo("access-key");
        assertThat(properties.secretKey()).isEqualTo("secret-key");
        assertThat(properties.bucket()).isEqualTo("photos");
    }

    @Test
    void shouldRejectInvalidEnabledProperties() {
        assertThatThrownBy(() -> new MinioStorageProperties(
                true,
                null,
                "access-key",
                "secret-key",
                "photos"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("endpoint must not be null");

        assertThatThrownBy(() -> new MinioStorageProperties(
                true,
                URI.create("http://localhost:9000"),
                null,
                "secret-key",
                "photos"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("accessKey must not be null");

        assertThatThrownBy(() -> new MinioStorageProperties(
                true,
                URI.create("http://localhost:9000"),
                " ",
                "secret-key",
                "photos"
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessKey must not be blank");

        assertThatThrownBy(() -> new MinioStorageProperties(
                true,
                URI.create("http://localhost:9000"),
                "access-key",
                " ",
                "photos"
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("secretKey must not be blank");

        assertThatThrownBy(() -> new MinioStorageProperties(
                true,
                URI.create("http://localhost:9000"),
                "access-key",
                "secret-key",
                " "
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("bucket must not be blank");
    }

    @Test
    void shouldRejectUnsafeEndpoint() {
        assertThatThrownBy(() -> enabledProperties(URI.create("/minio")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("endpoint must be absolute");

        assertThatThrownBy(() -> enabledProperties(
                URI.create("ftp://localhost:9000")
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("endpoint scheme must be http or https");

        assertThatThrownBy(() -> enabledProperties(
                URI.create("http://localhost:9000/minio")
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("endpoint path must not be present");

        assertThatThrownBy(() -> enabledProperties(
                URI.create("http://user@localhost:9000")
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("endpoint user info must not be present");

        assertThatThrownBy(() -> enabledProperties(
                URI.create("http://localhost:9000?secret=value")
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("endpoint query must not be present");
    }

    @Test
    void shouldHaveSafeToString() {
        MinioStorageProperties properties = enabledProperties(
                URI.create("http://localhost:9000")
        );

        assertThat(properties.toString())
                .contains("MinioStorageProperties")
                .contains("enabled=true")
                .doesNotContain("localhost")
                .doesNotContain("access-key")
                .doesNotContain("secret-key")
                .doesNotContain("photos");
    }

    private static MinioStorageProperties enabledProperties(URI endpoint) {
        return new MinioStorageProperties(
                true,
                endpoint,
                "access-key",
                "secret-key",
                "photos"
        );
    }
}
