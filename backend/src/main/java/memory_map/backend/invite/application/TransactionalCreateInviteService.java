package memory_map.backend.invite.application;

import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class TransactionalCreateInviteService implements CreateInviteUseCase {

    private final UserStoryRepository userStoryRepository;
    private final InviteRepository inviteRepository;
    private final InviteTokenGenerator inviteTokenGenerator;
    private final InviteTokenHasher inviteTokenHasher;
    private final InviteLinkFactory inviteLinkFactory;
    private final InviteProperties inviteProperties;

    public TransactionalCreateInviteService(
            UserStoryRepository userStoryRepository,
            InviteRepository inviteRepository,
            InviteTokenGenerator inviteTokenGenerator,
            InviteTokenHasher inviteTokenHasher,
            InviteLinkFactory inviteLinkFactory,
            InviteProperties inviteProperties
    ) {
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
        );
        this.inviteRepository = Objects.requireNonNull(
                inviteRepository,
                "inviteRepository must not be null"
        );
        this.inviteTokenGenerator = Objects.requireNonNull(
                inviteTokenGenerator,
                "inviteTokenGenerator must not be null"
        );
        this.inviteTokenHasher = Objects.requireNonNull(
                inviteTokenHasher,
                "inviteTokenHasher must not be null"
        );
        this.inviteLinkFactory = Objects.requireNonNull(
                inviteLinkFactory,
                "inviteLinkFactory must not be null"
        );
        this.inviteProperties = Objects.requireNonNull(
                inviteProperties,
                "inviteProperties must not be null"
        );
    }

    @Override
    @Transactional
    public CreatedInvite createInvite(CreateInviteCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UserStory userStory = userStoryRepository.findByStoryIdAndUserId(
                command.storyId(),
                command.authenticatedUser().userId()
        ).orElseThrow(InviteCreationUnavailableException::new);

        if (!canCreateInvite(userStory.role())) {
            throw new InviteCreationUnavailableException();
        }

        String rawToken = inviteTokenGenerator.generate();
        String tokenHash = inviteTokenHasher.hash(rawToken);
        Instant expiresAt = command.currentTime()
                .plus(inviteProperties.ttl());

        inviteRepository.save(invite(command, tokenHash, expiresAt));

        URI inviteLink = inviteLinkFactory.create(rawToken);

        return new CreatedInvite(inviteLink, expiresAt);
    }

    private static boolean canCreateInvite(StoryRole role) {
        return role == StoryRole.OWNER
                || role == StoryRole.CO_OWNER;
    }

    private static Invite invite(
            CreateInviteCommand command,
            String tokenHash,
            Instant expiresAt
    ) {
        UUID userId = command.authenticatedUser().userId();

        return new Invite(
                command.inviteId(),
                command.storyId(),
                tokenHash,
                userId,
                command.currentTime(),
                expiresAt,
                null
        );
    }
}
