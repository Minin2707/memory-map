package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.media.storage.StorageService;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.simple.JdbcClient;
import tools.jackson.databind.json.JsonMapper;

import java.time.Clock;

@Configuration
@Profile("music-catalog-import")
public class MusicCatalogImportConfiguration {

    @Bean
    public MusicTrackStorageKeyFactory musicTrackStorageKeyFactory() {
        return new MusicTrackStorageKeyFactory();
    }

    @Bean
    public MusicCatalogFileVerifier musicCatalogFileVerifier() {
        return new MusicCatalogFileVerifier();
    }

    @Bean
    public MusicCatalogManifestLoader musicCatalogManifestLoader(
            JsonMapper jsonMapper,
            MusicTrackStorageKeyFactory storageKeyFactory,
            MusicCatalogFileVerifier fileVerifier
    ) {
        return new MusicCatalogManifestLoader(
                jsonMapper,
                storageKeyFactory,
                fileVerifier
        );
    }

    @Bean
    public MusicCatalogWriter musicCatalogWriter(JdbcClient jdbcClient) {
        return new JdbcMusicCatalogWriter(jdbcClient);
    }

    @Bean
    public MusicCatalogImportService musicCatalogImportService(
            MusicCatalogWriter writer,
            StorageService storageService,
            MusicCatalogFileVerifier fileVerifier,
            Clock clock
    ) {
        return new MusicCatalogImportService(
                writer,
                storageService,
                fileVerifier,
                clock
        );
    }

    @Bean
    public ApplicationRunner musicCatalogImportRunner(
            MusicCatalogManifestLoader manifestLoader,
            MusicCatalogImportService importService,
            ConfigurableApplicationContext applicationContext
    ) {
        return new MusicCatalogImportRunner(
                manifestLoader,
                importService,
                applicationContext
        );
    }
}
