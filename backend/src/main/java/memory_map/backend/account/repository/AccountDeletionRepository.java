package memory_map.backend.account.repository;

import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface AccountDeletionRepository {

    List<Story> findOwnedStoriesForUpdate(UUID ownerId);

    List<StoryParticipant> findParticipantsForStoriesForUpdate(
            Collection<UUID> storyIds
    );

    List<StoryParticipant> findUserParticipationsForUpdate(UUID userId);

    List<AccountDeletionMediaStorageKeys> findMediaStorageKeysByStoryIds(
            Collection<UUID> storyIds
    );

    void transferStoryOwner(
            UUID storyId,
            UUID newOwnerId,
            Instant updatedAt
    );

    void updateParticipantRole(
            UUID storyId,
            UUID userId,
            StoryRole role
    );

    void deleteParticipant(UUID storyId, UUID userId);

    int deleteInvitesByStoryIds(Collection<UUID> storyIds);

    int deleteUnusedInvitesCreatedBy(UUID userId);

    int deleteMemoriesByStoryIds(Collection<UUID> storyIds);

    int deleteStoriesByIds(Collection<UUID> storyIds);
}
