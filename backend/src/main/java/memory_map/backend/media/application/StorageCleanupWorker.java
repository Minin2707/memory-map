package memory_map.backend.media.application;

import org.springframework.scheduling.annotation.Scheduled;

import java.util.Objects;

public class StorageCleanupWorker {

    private final StorageCleanupProcessor processor;

    public StorageCleanupWorker(StorageCleanupProcessor processor) {
        this.processor = Objects.requireNonNull(
                processor,
                "processor must not be null"
        );
    }

    @Scheduled(
            fixedDelayString =
                    "${app.storage.cleanup.fixed-delay-millis:30000}"
    )
    public void processDueTasks() {
        processor.processDueTasks();
    }
}
