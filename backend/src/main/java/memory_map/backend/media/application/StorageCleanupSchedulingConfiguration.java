package memory_map.backend.media.application;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

@Configuration
@EnableScheduling
@ConditionalOnProperty(
        prefix = "app.storage.cleanup",
        name = "worker-enabled",
        havingValue = "true"
)
public class StorageCleanupSchedulingConfiguration {

    @Bean
    public StorageCleanupWorker storageCleanupWorker(
            StorageCleanupProcessor processor
    ) {
        return new StorageCleanupWorker(processor);
    }
}
