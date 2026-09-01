package memory_map.backend.notification.application;

import memory_map.backend.memory.domain.Memory;

import java.time.Instant;
import java.util.UUID;

public interface NotificationPublisher {

    void participantJoined(UUID storyId, UUID actorUserId, Instant createdAt);

    void memoryCreated(Memory memory, Instant createdAt);

    void photosAdded(Memory memory, UUID actorUserId, Instant createdAt);
}
