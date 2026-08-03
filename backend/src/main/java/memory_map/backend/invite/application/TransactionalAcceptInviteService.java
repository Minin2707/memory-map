package memory_map.backend.invite.application;

import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class TransactionalAcceptInviteService implements AcceptInviteUseCase {

    private final InviteRepository inviteRepository;
    private final InviteTokenHasher inviteTokenHasher;
    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;

    public TransactionalAcceptInviteService(
            InviteRepository inviteRepository,
            InviteTokenHasher inviteTokenHasher,
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        this.inviteRepository = Objects.requireNonNull(
                inviteRepository,
                "inviteRepository must not be null"
        );
        this.inviteTokenHasher = Objects.requireNonNull(
                inviteTokenHasher,
                "inviteTokenHasher must not be null"
        );
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
    }

    @Override
    @Transactional
    public UserStory acceptInvite(AcceptInviteCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        String tokenHash = inviteTokenHasher.hash(command.rawInviteToken());
        Invite invite = inviteRepository.findByTokenHashForUpdate(tokenHash)
                .orElseThrow(InviteAcceptanceUnavailableException::new);

        validateInvite(invite, command);

        Story story = storyRepository.findById(invite.storyId())
                .orElseThrow(InviteAcceptanceUnavailableException::new);
        UUID userId = command.authenticatedUser().userId();

        if (storyParticipantRepository.exists(invite.storyId(), userId)) {
            throw new InviteAcceptanceUnavailableException();
        }

        storyParticipantRepository.save(new StoryParticipant(
                invite.storyId(),
                userId,
                StoryRole.CO_OWNER,
                command.currentTime()
        ));

        if (
                !inviteRepository.markUsedIfUnused(
                        invite.id(),
                        command.currentTime()
                )
        ) {
            throw new InviteAcceptanceUnavailableException();
        }

        return new UserStory(story, StoryRole.CO_OWNER);
    }

    private static void validateInvite(
            Invite invite,
            AcceptInviteCommand command
    ) {
        if (
                invite.usedAt() != null
                        || invite.expiresAt().isBefore(command.currentTime())
        ) {
            throw new InviteAcceptanceUnavailableException();
        }
    }
}
