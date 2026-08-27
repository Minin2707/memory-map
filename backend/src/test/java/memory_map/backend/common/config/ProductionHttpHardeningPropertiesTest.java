package memory_map.backend.common.config;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

class ProductionHttpHardeningPropertiesTest {

    @Test
    void shouldPinProductionErrorDisclosureClosed() throws IOException {
        String productionProperties = Files.readString(
                Path.of("src/main/resources/application-prod.yml")
        );

        assertThat(productionProperties)
                .contains("include-message: never")
                .contains("include-stacktrace: never")
                .contains("include-binding-errors: never")
                .contains("include-exception: false");
    }

    @Test
    void shouldNotTrustForwardedHeadersWithoutTrustedProxyIsolation()
            throws IOException {

        String productionProperties = Files.readString(
                Path.of("src/main/resources/application-prod.yml")
        );

        assertThat(productionProperties)
                .doesNotContain("forward-headers-strategy")
                .doesNotContain("use-forward-headers");
    }
}
