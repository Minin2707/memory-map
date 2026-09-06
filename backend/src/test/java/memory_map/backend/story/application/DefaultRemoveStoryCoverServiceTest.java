package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultRemoveStoryCoverServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-02T10:00:00Z");

    private final List<String> events = new ArrayList<>();
    private final FakeStoryRepository storyRepository =
            new FakeStoryRepository(events);
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository(events);
    private final FakeUserStoryRepository userStoryRepository =
            new FakeUserStoryRepository(events);
    private final FakeStorageCleanupScheduler cleanupScheduler =
            new FakeStorageCleanupScheduler(events);
    private final DefaultRemoveStoryCoverService service =
            new DefaultRemoveStoryCoverService(
                    storyRepository,
                    storyParticipantRepository,
                    userStoryRepository,
                    cleanupScheduler
            );

    @Test
    void shouldRemoveExistingCoverForOwnerAndReturnAutomaticFallback() {
        userStoryRepository.userStory = userStory(autoPreview());

        UserStory result = service.removeStoryCover(command());

        assertThat(result.previewPhoto()).isEqualTo(autoPreview());
        assertThat(storyRepository.requestedLockId).isEqualTo(STORY_ID);
        assertThat(storyRepository.clearedCover).isTrue();
        assertThat(cleanupScheduler.scheduledKeys).containsExactly(
                new StorageKey("stories/story/old/thumbnail"),
                new StorageKey("stories/story/old/display")
        );
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find",
                "story.clearCover",
                "userStory.findByStoryIdAndUserId",
                "cleanup.schedule"
        );
    }

    @Test
    void shouldRemoveExistingCoverForCoOwnerAndReturnAuthoritativeStory() {
        storyParticipantRepository.participant =
                Optional.of(participant(StoryRole.CO_OWNER));
        userStoryRepository.userStory = userStory(null);

        UserStory result = service.removeStoryCover(command());

        assertThat(result).isSameAs(userStoryRepository.userStory);
        assertThat(storyRepository.clearedCover).isTrue();
        assertThat(cleanupScheduler.scheduledKeys).containsExactly(
                new StorageKey("stories/story/old/thumbnail"),
                new StorageKey("stories/story/old/display")
        );
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyRolesThatCannotRemoveCoverBeforeMutation(StoryRole role) {
        storyParticipantRepository.participant =
                Optional.of(participant(role));

        assertThatThrownBy(() -> service.removeStoryCover(command()))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertNoMutationProjectionOrCleanup();
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find"
        );
    }

    @Test
    void shouldConcealMissingStoryBeforeMembershipLookup() {
        storyRepository.story = Optional.empty();

        assertThatThrownBy(() -> service.removeStoryCover(command()))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(events).containsExactly("story.findByIdForUpdate");
        assertThat(storyParticipantRepository.callCount).isZero();
        assertNoMutationProjectionOrCleanup();
    }

    @Test
    void shouldConcealNonParticipantBeforeMutation() {
        storyParticipantRepository.participant = Optional.empty();

        assertThatThrownBy(() -> service.removeStoryCover(command()))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find"
        );
        assertNoMutationProjectionOrCleanup();
    }

    @Test
    void shouldReturnAuthoritativeStoryWhenCoverAlreadyAbsent() {
        storyRepository.story = Optional.of(story(null));
        userStoryRepository.userStory = userStory(autoPreview());

        UserStory result = service.removeStoryCover(command());

        assertThat(result.previewPhoto()).isEqualTo(autoPreview());
        assertThat(storyRepository.clearedCover).isFalse();
        assertThat(cleanupScheduler.scheduledKeys).isEmpty();
        assertThat(events).containsExactly(
                "story.findByIdForUpdate",
                "participant.find",
                "userStory.findByStoryIdAndUserId"
        );
    }

    @Test
    void shouldReturnAuthoritativeNullPreviewWhenNoFallbackExists() {
        userStoryRepository.userStory = userStory(null);

        UserStory result = service.removeStoryCover(command());

        assertThat(result.previewPhoto()).isNull();
        assertThat(storyRepository.clearedCover).isTrue();
        assertThat(cleanupScheduler.scheduledKeys).containsExactly(
                new StorageKey("stories/story/old/thumbnail"),
                new StorageKey("stories/story/old/display")
        );
    }

    @Test
    void shouldPropagateClearFailureWithoutSchedulingCleanup() {
        RuntimeException failure = new RuntimeException("clear failed");
        storyRepository.clearFailure = failure;

        assertThatThrownBy(() -> service.removeStoryCover(command()))
                .isSameAs(failure);

        assertThat(userStoryRepository.callCount).isZero();
        assertThat(cleanupScheduler.scheduledKeys).isEmpty();
    }

    @Test
    void shouldPropagateMissingAuthoritativeProjectionWithoutDeletingStorage() {
        userStoryRepository.userStory = null;

        assertThatThrownBy(() -> service.removeStoryCover(command()))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(storyRepository.clearedCover).isTrue();
        assertThat(cleanupScheduler.scheduledKeys).isEmpty();
    }

    @Test
    void shouldPropagateCleanupSchedulingFailure() {
        RuntimeException failure = new RuntimeException("enqueue failed");
        cleanupScheduler.failure = failure;

        assertThatThrownBy(() -> service.removeStoryCover(command()))
                .isSameAs(failure);

        assertThat(storyRepository.clearedCover).isTrue();
        assertThat(userStoryRepository.callCount).isEqualTo(1);
        assertThat(cleanupScheduler.scheduledKeys).containsExactly(
                new StorageKey("stories/story/old/thumbnail"),
                new StorageKey("stories/story/old/display")
        );
    }

    @Test
    void shouldRejectNullDependenciesAndCommand() {
        assertThatThrownBy(() -> new DefaultRemoveStoryCoverService(
                null,
                storyParticipantRepository,
                userStoryRepository,
                cleanupScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");
        assertThatThrownBy(() -> new DefaultRemoveStoryCoverService(
                storyRepository,
                null,
                userStoryRepository,
                cleanupScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
        assertThatThrownBy(() -> new DefaultRemoveStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                null,
                cleanupScheduler
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");
        assertThatThrownBy(() -> new DefaultRemoveStoryCoverService(
                storyRepository,
                storyParticipantRepository,
                userStoryRepository,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("cleanupScheduler must not be null");
        assertThatThrownBy(() -> service.removeStoryCover(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    private void assertNoMutationProjectionOrCleanup() {
        assertThat(storyRepository.clearedCover).isFalse();
        assertThat(userStoryRepository.callCount).isZero();
        assertThat(cleanupScheduler.scheduledKeys).isEmpty();
    }

    private static RemoveStoryCoverCommand command() {
        return new RemoveStoryCoverCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID
        );
    }

    private static Story story(StoryCoverMetadata cover) {
        return new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                "The beginning",
                null,
                cover,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static StoryParticipant participant(StoryRole role) {
        return new StoryParticipant(STORY_ID, USER_ID, role, CREATED_AT);
    }

    private static StoryCoverMetadata oldCover() {
        return new StoryCoverMetadata(
                "stories/story/old/display",
                2_048L,
                "stories/story/old/thumbnail",
                360L,
                "image/jpeg",
                UPDATED_AT
        );
    }

    private static StoryPhotoPreview autoPreview() {
        return new StoryPhotoPreview(
                "/api/v1/media/media-1/thumbnail",
                "/api/v1/media/media-1/display"
        );
    }

    private static UserStory userStory(StoryPhotoPreview previewPhoto) {
        return new UserStory(
                story(null),
                StoryRole.OWNER,
                3,
                2,
                previewPhoto
        );
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        private final List<String> events;
        private Optional<Story> story = Optional.of(story(oldCover()));
        private UUID requestedLockId;
        private boolean clearedCover;
        private RuntimeException clearFailure;

        private FakeStoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Story save(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Story update(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Story> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Story> findByIdForUpdate(UUID id) {
            events.add("story.findByIdForUpdate");
            requestedLockId = id;
            return story;
        }

        @Override
        public boolean lockById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Story clearCover(UUID id) {
            events.add("story.clearCover");

            if (clearFailure != null) {
                throw clearFailure;
            }

            clearedCover = true;
            story = Optional.of(story(null));
            return story.get();
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> events;
        private Optional<StoryParticipant> participant =
                Optional.of(participant(StoryRole.OWNER));
        private int callCount;

        private FakeStoryParticipantRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            events.add("participant.find");
            callCount++;
            return participant;
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public long countOwners(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void update(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        private final List<String> events;
        private UserStory userStory = userStory(autoPreview());
        private int callCount;

        private FakeUserStoryRepository(List<String> events) {
            this.events = events;
        }

        @Override
        public List<UserStory> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<UserStory> findByStoryIdAndUserId(
                UUID storyId,
                UUID userId
        ) {
            events.add("userStory.findByStoryIdAndUserId");
            callCount++;

            return Optional.ofNullable(userStory);
        }
    }

    private static final class FakeStorageCleanupScheduler
            implements StorageCleanupScheduler {

        private final List<String> events;
        private final List<StorageKey> scheduledKeys = new ArrayList<>();
        private RuntimeException failure;

        private FakeStorageCleanupScheduler(List<String> events) {
            this.events = events;
        }

        @Override
        public void schedule(Collection<StorageKey> storageKeys) {
            events.add("cleanup.schedule");
            scheduledKeys.addAll(storageKeys);

            if (failure != null) {
                throw failure;
            }
        }
    }
}
