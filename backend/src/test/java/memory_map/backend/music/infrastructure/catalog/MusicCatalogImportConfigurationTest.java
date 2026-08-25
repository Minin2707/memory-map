package memory_map.backend.music.infrastructure.catalog;

import org.junit.jupiter.api.Test;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;

class MusicCatalogImportConfigurationTest {

    @Test
    void shouldNotRegisterImporterWithoutDedicatedProfile() {
        new ApplicationContextRunner()
                .withUserConfiguration(MusicCatalogImportConfiguration.class)
                .run(context -> {
                    assertThat(context)
                            .doesNotHaveBean(MusicCatalogImportRunner.class);
                    assertThat(context)
                            .doesNotHaveBean(ApplicationRunner.class);
                    assertThat(context)
                            .doesNotHaveBean(MusicCatalogWriter.class);
                });
    }
}
