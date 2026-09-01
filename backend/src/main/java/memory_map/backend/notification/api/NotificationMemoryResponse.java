package memory_map.backend.notification.api;

import memory_map.backend.notification.application.NotificationMemoryView;

import java.util.UUID;

public record NotificationMemoryResponse(

        UUID memoryId,

        String title

) {
    static NotificationMemoryResponse from(NotificationMemoryView memory) {
        return new NotificationMemoryResponse(
                memory.memoryId(),
                memory.title()
        );
    }
}
