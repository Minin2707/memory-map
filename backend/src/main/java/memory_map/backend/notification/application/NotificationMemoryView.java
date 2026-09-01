package memory_map.backend.notification.application;

import java.util.Objects;
import java.util.UUID;

public record NotificationMemoryView(

        UUID memoryId,

        String title

) {
    public NotificationMemoryView {
        Objects.requireNonNull(memoryId, "memoryId must not be null");
    }
}
