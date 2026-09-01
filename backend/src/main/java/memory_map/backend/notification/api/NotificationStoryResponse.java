package memory_map.backend.notification.api;

import memory_map.backend.notification.application.NotificationStoryView;

import java.util.UUID;

public record NotificationStoryResponse(

        UUID storyId,

        String title

) {
    static NotificationStoryResponse from(NotificationStoryView story) {
        return new NotificationStoryResponse(
                story.storyId(),
                story.title()
        );
    }
}
