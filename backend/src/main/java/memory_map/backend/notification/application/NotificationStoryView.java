package memory_map.backend.notification.application;

import java.util.UUID;

public record NotificationStoryView(

        UUID storyId,

        String title

) {
    public NotificationStoryView {
        if (storyId == null && title != null) {
            throw new IllegalArgumentException(
                    "story title cannot exist without storyId"
            );
        }
    }
}
