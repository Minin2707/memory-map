package memory_map.backend.story.application;

import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryDeletionMediaStorageKeys;
import memory_map.backend.story.repository.StoryDeletionRepository;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class TransactionalDeleteStoryService implements DeleteStoryUseCase {

    private static final String DELETE_AFFECTED_NO_ROWS_MESSAGE =
            "Story delete affected no rows after locked lookup";

    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final StoryDeletionRepository storyDeletionRepository;
    private final StorageCleanupScheduler cleanupScheduler;
    private final StoryAccessPolicy accessPolicy;

    public TransactionalDeleteStoryService(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            StoryDeletionRepository storyDeletionRepository,
            StorageCleanupScheduler cleanupScheduler,
            StoryAccessPolicy accessPolicy
    ) {
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.storyDeletionRepository = Objects.requireNonNull(
                storyDeletionRepository,
                "storyDeletionRepository must not be null"
        );
        this.cleanupScheduler = Objects.requireNonNull(
                cleanupScheduler,
                "cleanupScheduler must not be null"
        );
        this.accessPolicy = Objects.requireNonNull(
                accessPolicy,
                "accessPolicy must not be null"
        );
    }

    @Override
    @Transactional
    public void deleteStory(DeleteStoryCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID storyId = command.storyId();
        UUID userId = command.authenticatedUser().userId();

        Story story = storyRepository.findByIdForUpdate(storyId)
                .orElseThrow(StoryNotFoundException::new);
        StoryParticipant requester = storyParticipantRepository
                .find(storyId, userId)
                .orElseThrow(StoryNotFoundException::new);

        if (!accessPolicy.canDeleteStory(requester.role())) {
            throw new StoryNotFoundException();
        }

        List<StorageKey> cleanupKeys = cleanupKeys(story);

        storyDeletionRepository.deleteInvitesByStoryId(storyId);
        storyDeletionRepository.deleteMemoriesByStoryId(storyId);

        if (!storyDeletionRepository.deleteStoryById(storyId)) {
            throw new IllegalStateException(DELETE_AFFECTED_NO_ROWS_MESSAGE);
        }

        cleanupScheduler.schedule(cleanupKeys);
    }

    private List<StorageKey> cleanupKeys(Story story) {
        List<StorageKey> cleanupKeys = new ArrayList<>();
        StoryCoverMetadata cover = story.cover();

        if (cover != null) {
            cleanupKeys.add(new StorageKey(cover.thumbnailStorageKey()));
            cleanupKeys.add(new StorageKey(cover.displayStorageKey()));
        }

        for (StoryDeletionMediaStorageKeys keys
                : storyDeletionRepository.findMediaStorageKeysByStoryId(
                        story.id()
                )) {
            cleanupKeys.add(new StorageKey(keys.thumbnailStorageKey()));
            cleanupKeys.add(new StorageKey(keys.displayStorageKey()));
        }

        return cleanupKeys;
    }
}
