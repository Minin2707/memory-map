package memory_map.backend.story.application;

import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class DefaultRemoveStoryCoverService
        implements RemoveStoryCoverUseCase {

    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final UserStoryRepository userStoryRepository;
    private final StorageCleanupScheduler cleanupScheduler;

    public DefaultRemoveStoryCoverService(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            UserStoryRepository userStoryRepository,
            StorageCleanupScheduler cleanupScheduler
    ) {
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
        );
        this.cleanupScheduler = Objects.requireNonNull(
                cleanupScheduler,
                "cleanupScheduler must not be null"
        );
    }

    @Override
    @Transactional
    public UserStory removeStoryCover(RemoveStoryCoverCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID storyId = command.storyId();
        UUID requesterUserId = command.authenticatedUser().userId();
        Story lockedStory = storyRepository.findByIdForUpdate(storyId)
                .orElseThrow(StoryNotFoundException::new);
        StoryParticipant participant = storyParticipantRepository.find(
                storyId,
                requesterUserId
        ).orElseThrow(StoryNotFoundException::new);

        if (!canRemoveCover(participant.role())) {
            throw new StoryNotFoundException();
        }

        StoryCoverMetadata oldCover = lockedStory.cover();
        if (oldCover != null) {
            storyRepository.clearCover(storyId);
        }

        UserStory userStory = userStoryRepository.findByStoryIdAndUserId(
                storyId,
                requesterUserId
        ).orElseThrow(StoryNotFoundException::new);

        scheduleCleanup(oldCover);

        return userStory;
    }

    private static boolean canRemoveCover(StoryRole role) {
        return role == StoryRole.OWNER || role == StoryRole.CO_OWNER;
    }

    private void scheduleCleanup(StoryCoverMetadata oldCover) {
        if (oldCover == null) {
            return;
        }

        cleanupScheduler.schedule(List.of(
                new StorageKey(oldCover.thumbnailStorageKey()),
                new StorageKey(oldCover.displayStorageKey())
        ));
    }
}
