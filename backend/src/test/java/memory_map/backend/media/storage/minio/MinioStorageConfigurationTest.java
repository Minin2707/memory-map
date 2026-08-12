package memory_map.backend.media.storage.minio;

import io.minio.MinioClient;
import memory_map.backend.media.storage.StorageService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;

class MinioStorageConfigurationTest {

    @Test
    void shouldKeepStorageBeansDisabledByDefault() {
        new ApplicationContextRunner()
                .withUserConfiguration(MinioStorageConfiguration.class)
                .run(context -> {
                    assertThat(context)
                            .hasSingleBean(MinioStorageProperties.class);
                    assertThat(context)
                            .doesNotHaveBean(MinioClient.class);
                    assertThat(context)
                            .doesNotHaveBean(StorageService.class);
                    assertThat(context)
                            .doesNotHaveBean(ApplicationRunner.class);
                });
    }

    @Test
    void shouldRegisterMinioBeansWhenEnabled() {
        new ApplicationContextRunner()
                .withUserConfiguration(MinioStorageConfiguration.class)
                .withPropertyValues(
                        "app.storage.minio.enabled=true",
                        "app.storage.minio.endpoint=http://localhost:9000",
                        "app.storage.minio.access-key=access-key",
                        "app.storage.minio.secret-key=secret-key",
                        "app.storage.minio.bucket=photos"
                )
                .run(context -> {
                    assertThat(context).hasSingleBean(MinioClient.class);
                    assertThat(context).hasSingleBean(StorageService.class);
                    assertThat(context).hasSingleBean(ApplicationRunner.class);
                    assertThat(context.getBean(StorageService.class))
                            .isInstanceOf(MinioStorageService.class);
                });
    }
}
