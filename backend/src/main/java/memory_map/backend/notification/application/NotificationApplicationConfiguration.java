package memory_map.backend.notification.application;

import memory_map.backend.notification.repository.NotificationRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class NotificationApplicationConfiguration {

    @Bean
    public NotificationPublisher notificationPublisher(
            NotificationRepository notificationRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        return new DefaultNotificationPublisher(
                notificationRepository,
                storyParticipantRepository
        );
    }

    @Bean
    public DefaultNotificationInboxService notificationInboxService(
            NotificationRepository notificationRepository
    ) {
        return new DefaultNotificationInboxService(notificationRepository);
    }
}
