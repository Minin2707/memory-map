package memory_map.backend.media.storage.minio;

import io.minio.MinioClient;
import memory_map.backend.media.storage.StorageService;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(MinioStorageProperties.class)
public class MinioStorageConfiguration {

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public MinioClient minioClient(MinioStorageProperties properties) {
        return MinioClient.builder()
                .endpoint(properties.endpoint().toString())
                .credentials(properties.accessKey(), properties.secretKey())
                .build();
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public StorageService storageService(
            MinioClient minioClient,
            MinioStorageProperties properties
    ) {
        return new MinioStorageService(minioClient, properties.bucket());
    }

    @Bean
    @ConditionalOnProperty(
            prefix = "app.storage.minio",
            name = "enabled",
            havingValue = "true"
    )
    public ApplicationRunner minioBucketInitializer(
            MinioClient minioClient,
            MinioStorageProperties properties
    ) {
        MinioBucketInitializer initializer =
                new MinioBucketInitializer(minioClient, properties.bucket());

        return args -> initializer.initialize();
    }
}
