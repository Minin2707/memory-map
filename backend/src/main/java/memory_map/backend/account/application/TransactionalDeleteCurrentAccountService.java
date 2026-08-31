package memory_map.backend.account.application;

import memory_map.backend.account.repository.AccountDeletionRepository;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

public class TransactionalDeleteCurrentAccountService
        implements DeleteCurrentAccountUseCase {

    private final UserRepository userRepository;
    private final AccountDeletionRepository accountDeletionRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AccountDeletionMediaCleanupCoordinator mediaCleanupCoordinator;

    public TransactionalDeleteCurrentAccountService(
            UserRepository userRepository,
            AccountDeletionRepository accountDeletionRepository,
            RefreshTokenRepository refreshTokenRepository,
            AccountDeletionMediaCleanupCoordinator mediaCleanupCoordinator
    ) {
        this.userRepository = Objects.requireNonNull(
                userRepository,
                "userRepository must not be null"
        );
        this.accountDeletionRepository = Objects.requireNonNull(
                accountDeletionRepository,
                "accountDeletionRepository must not be null"
        );
        this.refreshTokenRepository = Objects.requireNonNull(
                refreshTokenRepository,
                "refreshTokenRepository must not be null"
        );
        this.mediaCleanupCoordinator = Objects.requireNonNull(
                mediaCleanupCoordinator,
                "mediaCleanupCoordinator must not be null"
        );
    }

    @Override
    @Transactional
    public void deleteCurrentAccount(DeleteCurrentAccountCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID userId = command.authenticatedUser().userId();
        UserDeletionAvatar userDeletionAvatar =
                userRepository.findActiveByIdForUpdate(userId)
                .map(this::avatarForDeletedUser)
                .orElseThrow(AccountDeletionUnavailableException::new);

        List<Story> ownedStories =
                accountDeletionRepository.findOwnedStoriesForUpdate(userId);
        List<StoryParticipant> ownedStoryParticipants =
                accountDeletionRepository.findParticipantsForStoriesForUpdate(
                        storyIds(ownedStories)
                );
        Map<UUID, List<StoryParticipant>> participantsByStoryId =
                ownedStoryParticipants.stream()
                        .collect(Collectors.groupingBy(
                                StoryParticipant::storyId
                        ));

        AccountDeletionPlan plan = planDeletion(
                userId,
                ownedStories,
                participantsByStoryId
        );

        List<StorageKey> storageKeys =
                storageKeysForDeletedStories(plan.deletedStoryIds());
        if (userDeletionAvatar.storageKey() != null) {
            storageKeys = new ArrayList<>(storageKeys);
            storageKeys.add(userDeletionAvatar.storageKey());
        }

        accountDeletionRepository.deleteInvitesByStoryIds(
                plan.deletedStoryIds()
        );
        accountDeletionRepository.deleteUnusedInvitesCreatedBy(userId);

        transferOwnedStories(
                plan.transfers(),
                command
        );

        removeSurvivingParticipations(
                userId,
                plan.deletedStoryIds()
        );

        accountDeletionRepository.deleteMemoriesByStoryIds(
                plan.deletedStoryIds()
        );
        accountDeletionRepository.deleteStoriesByIds(plan.deletedStoryIds());
        refreshTokenRepository.revokeActiveByUserId(
                userId,
                command.currentTime()
        );

        if (!userRepository.tombstoneById(userId, command.currentTime())) {
            throw new AccountDeletionUnavailableException();
        }

        mediaCleanupCoordinator.scheduleAfterCommitCleanup(storageKeys);
    }

    private AccountDeletionPlan planDeletion(
            UUID userId,
            List<Story> ownedStories,
            Map<UUID, List<StoryParticipant>> participantsByStoryId
    ) {
        Set<UUID> deletedStoryIds = new LinkedHashSet<>();
        List<StoryOwnershipTransfer> transfers = ownedStories.stream()
                .map(story -> classifyOwnedStory(
                        userId,
                        story,
                        participantsByStoryId.getOrDefault(
                                story.id(),
                                List.of()
                        )
                ))
                .peek(classification -> {
                    if (classification.blocked()) {
                        throw new AccountDeletionOwnershipConflictException();
                    }
                    if (classification.deletedStoryId() != null) {
                        deletedStoryIds.add(classification.deletedStoryId());
                    }
                })
                .map(classification -> classification.transfer())
                .filter(Objects::nonNull)
                .toList();

        return new AccountDeletionPlan(
                Set.copyOf(deletedStoryIds),
                transfers
        );
    }

    private OwnedStoryClassification classifyOwnedStory(
            UUID userId,
            Story story,
            List<StoryParticipant> participants
    ) {
        List<StoryParticipant> otherParticipants = participants.stream()
                .filter(participant -> !participant.userId().equals(userId))
                .toList();

        if (otherParticipants.isEmpty()) {
            return OwnedStoryClassification.deleteStory(story.id());
        }

        StoryParticipant replacementOwner = otherParticipants.stream()
                .filter(participant -> participant.role() == StoryRole.CO_OWNER)
                .min(Comparator
                        .comparing(StoryParticipant::joinedAt)
                        .thenComparing(StoryParticipant::userId))
                .orElse(null);

        if (replacementOwner == null) {
            return OwnedStoryClassification.block();
        }

        return OwnedStoryClassification.transfer(new StoryOwnershipTransfer(
                story.id(),
                replacementOwner.userId()
        ));
    }

    private List<StorageKey> storageKeysForDeletedStories(
            Collection<UUID> deletedStoryIds
    ) {
        List<StorageKey> storageKeys = new ArrayList<>(
                accountDeletionRepository
                        .findMediaStorageKeysByStoryIds(deletedStoryIds)
                        .stream()
                        .flatMap(keys -> List.of(
                                new StorageKey(keys.thumbnailStorageKey()),
                                new StorageKey(keys.displayStorageKey())
                        ).stream())
                        .toList()
        );
        storageKeys.addAll(accountDeletionRepository
                .findStoryCoverStorageKeysByStoryIds(deletedStoryIds)
                .stream()
                .map(StorageKey::new)
                .toList());

        return storageKeys;
    }

    private void transferOwnedStories(
            List<StoryOwnershipTransfer> transfers,
            DeleteCurrentAccountCommand command
    ) {
        for (StoryOwnershipTransfer transfer : transfers) {
            accountDeletionRepository.transferStoryOwner(
                    transfer.storyId(),
                    transfer.newOwnerId(),
                    command.currentTime()
            );
            accountDeletionRepository.updateParticipantRole(
                    transfer.storyId(),
                    transfer.newOwnerId(),
                    StoryRole.OWNER
            );
        }
    }

    private void removeSurvivingParticipations(
            UUID userId,
            Set<UUID> deletedStoryIds
    ) {
        for (StoryParticipant participant :
                accountDeletionRepository.findUserParticipationsForUpdate(
                        userId
                )) {
            if (!deletedStoryIds.contains(participant.storyId())) {
                accountDeletionRepository.deleteParticipant(
                        participant.storyId(),
                        userId
                );
            }
        }
    }

    private static Set<UUID> storyIds(List<Story> stories) {
        return stories.stream()
                .map(Story::id)
                .collect(Collectors.toCollection(LinkedHashSet::new));
    }

    private UserDeletionAvatar avatarForDeletedUser(User user) {
        if (!user.hasCustomAvatar()) {
            return new UserDeletionAvatar(null);
        }

        return new UserDeletionAvatar(
                new StorageKey(user.customAvatarStorageKey())
        );
    }

    private record UserDeletionAvatar(StorageKey storageKey) {
    }

    private record AccountDeletionPlan(

            Set<UUID> deletedStoryIds,

            List<StoryOwnershipTransfer> transfers

    ) {
    }

    private record StoryOwnershipTransfer(

            UUID storyId,

            UUID newOwnerId

    ) {
    }

    private record OwnedStoryClassification(

            UUID deletedStoryId,

            StoryOwnershipTransfer transfer,

            boolean blocked

    ) {
        private static OwnedStoryClassification deleteStory(UUID storyId) {
            return new OwnedStoryClassification(storyId, null, false);
        }

        private static OwnedStoryClassification transfer(
                StoryOwnershipTransfer transfer
        ) {
            return new OwnedStoryClassification(null, transfer, false);
        }

        private static OwnedStoryClassification block() {
            return new OwnedStoryClassification(null, null, true);
        }
    }
}
