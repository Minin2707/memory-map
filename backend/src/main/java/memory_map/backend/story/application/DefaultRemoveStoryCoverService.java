package memory_map.backend.story.application;

import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class DefaultRemoveStoryCoverService
        implements RemoveStoryCoverUseCase {

    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final UserStoryRepository userStoryRepository;
    private final StorageService storageService;
    private final TransactionCommitCoordinator commitCoordinator;

    public DefaultRemoveStoryCoverService(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            UserStoryRepository userStoryRepository,
            StorageService storageService,
            TransactionCommitCoordinator commitCoordinator
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
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
        this.commitCoordinator = Objects.requireNonNull(
                commitCoordinator,
                "commitCoordinator must not be null"
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

        scheduleAfterCommitCleanup(oldCover);

        return userStory;
    }

    private static boolean canRemoveCover(StoryRole role) {
        return role == StoryRole.OWNER || role == StoryRole.CO_OWNER;
    }

    private void scheduleAfterCommitCleanup(StoryCoverMetadata oldCover) {
        if (oldCover == null) {
            return;
        }

        commitCoordinator.onCommit(() -> {
            cleanupQuietly(new StorageKey(oldCover.thumbnailStorageKey()));
            cleanupQuietly(new StorageKey(oldCover.displayStorageKey()));
        });
    }

    private void cleanupQuietly(StorageKey key) {
        try {
            storageService.delete(key);
        } catch (RuntimeException ignored) {
            // Storage cleanup is best-effort after DB outcome is known.
        }
    }
}
