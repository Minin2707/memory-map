package memory_map.backend.story.application;

import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class TransactionalLeaveStoryService implements LeaveStoryUseCase {

    private static final String CORRUPTED_OWNER_COUNT_MESSAGE =
            "Story owner participant count is inconsistent";

    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;

    public TransactionalLeaveStoryService(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
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
    public void leaveStory(LeaveStoryCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID storyId = command.storyId();
        UUID userId = command.authenticatedUser().userId();

        if (!storyRepository.lockById(storyId)) {
            throw new StoryNotFoundException();
        }

        StoryParticipant requester = storyParticipantRepository
                .find(storyId, userId)
                .orElseThrow(StoryNotFoundException::new);

        if (requester.role() == StoryRole.OWNER) {
            assertOwnerCanLeave(storyId);
        }

        storyParticipantRepository.delete(storyId, userId);
    }

    private void assertOwnerCanLeave(UUID storyId) {
        long ownerCount = storyParticipantRepository.countOwners(storyId);

        if (ownerCount == 0) {
            throw new IllegalStateException(CORRUPTED_OWNER_COUNT_MESSAGE);
        }

        if (ownerCount == 1) {
            throw new LastStoryOwnerCannotLeaveException();
        }
    }
}
