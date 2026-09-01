package memory_map.backend.notification.application;

import memory_map.backend.memory.domain.Memory;
import memory_map.backend.notification.domain.Notification;
import memory_map.backend.notification.domain.NotificationType;
import memory_map.backend.notification.repository.NotificationRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class DefaultNotificationPublisher implements NotificationPublisher {

    private final NotificationRepository notificationRepository;
    private final StoryParticipantRepository storyParticipantRepository;

    public DefaultNotificationPublisher(
            NotificationRepository notificationRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        this.notificationRepository = Objects.requireNonNull(
                notificationRepository,
                "notificationRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
    }

    @Override
    public void participantJoined(
            UUID storyId,
            UUID actorUserId,
            Instant createdAt
    ) {
        publish(
                NotificationType.PARTICIPANT_JOINED,
                storyId,
                null,
                actorUserId,
                createdAt
        );
    }

    @Override
    public void memoryCreated(Memory memory, Instant createdAt) {
        Objects.requireNonNull(memory, "memory must not be null");

        publish(
                NotificationType.MEMORY_CREATED,
                memory.storyId(),
                memory.id(),
                memory.createdBy(),
                createdAt
        );
    }

    @Override
    public void photosAdded(
            Memory memory,
            UUID actorUserId,
            Instant createdAt
    ) {
        Objects.requireNonNull(memory, "memory must not be null");

        publish(
                NotificationType.PHOTOS_ADDED,
                memory.storyId(),
                memory.id(),
                actorUserId,
                createdAt
        );
    }

    private void publish(
            NotificationType type,
            UUID storyId,
            UUID memoryId,
            UUID actorUserId,
            Instant createdAt
    ) {
        Objects.requireNonNull(type, "type must not be null");
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(actorUserId, "actorUserId must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");

        List<StoryParticipant> participants =
                storyParticipantRepository.findByStoryId(storyId);

        for (StoryParticipant participant : participants) {
            UUID recipientUserId = participant.userId();

            if (recipientUserId.equals(actorUserId)) {
                continue;
            }

            notificationRepository.save(new Notification(
                    UUID.randomUUID(),
                    recipientUserId,
                    type,
                    actorUserId,
                    storyId,
                    memoryId,
                    createdAt,
                    null
            ));
        }
    }
}
