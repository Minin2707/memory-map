package memory_map.backend.invite.application;

import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.notification.application.NotificationPublisher;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.security.SecureRandom;

@Configuration
@EnableConfigurationProperties(InviteProperties.class)
public class InviteApplicationConfiguration {

    @Bean
    public InviteTokenGenerator inviteTokenGenerator() {
        return new SecureInviteTokenGenerator(new SecureRandom());
    }

    @Bean
    public InviteTokenHasher inviteTokenHasher() {
        return new Sha256InviteTokenHasher();
    }

    @Bean
    public InviteLinkFactory inviteLinkFactory(
            InviteProperties properties
    ) {
        return new DefaultInviteLinkFactory(properties);
    }

    @Bean
    public CreateInviteUseCase createInviteUseCase(
            UserStoryRepository userStoryRepository,
            InviteRepository inviteRepository,
            InviteTokenGenerator inviteTokenGenerator,
            InviteTokenHasher inviteTokenHasher,
            InviteLinkFactory inviteLinkFactory,
            InviteProperties inviteProperties
    ) {
        return new TransactionalCreateInviteService(
                userStoryRepository,
                inviteRepository,
                inviteTokenGenerator,
                inviteTokenHasher,
                inviteLinkFactory,
                inviteProperties
        );
    }

    @Bean
    public AcceptInviteUseCase acceptInviteUseCase(
            InviteRepository inviteRepository,
            InviteTokenHasher inviteTokenHasher,
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            NotificationPublisher notificationPublisher
    ) {
        return new TransactionalAcceptInviteService(
                inviteRepository,
                inviteTokenHasher,
                storyRepository,
                storyParticipantRepository,
                notificationPublisher
        );
    }
}
