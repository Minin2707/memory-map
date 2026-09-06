package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.application.StorageCleanupScheduler;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryDeletionMediaStorageKeys;
import memory_map.backend.story.repository.StoryDeletionRepository;
import memory_map.backend.story.repository.StoryRepository;
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

class TransactionalDeleteStoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    @Test
    void shouldDeleteOwnerStoryGraphAndScheduleStorageCleanup() {

        TestContext context = testContext(
                Optional.of(storyWithCover()),
                Optional.of(participant(StoryRole.OWNER))
        );
        context.deletionRepository().mediaKeys(List.of(
                new StoryDeletionMediaStorageKeys(
                        "media/thumbnail-a",
                        "media/display-a"
                )
        ));

        context.service().deleteStory(command());

        assertThat(context.storyRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.participantRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.participantRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.deletionRepository().deletedInvitesStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.deletionRepository().deletedMemoriesStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.deletionRepository().deletedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.cleanupScheduler().scheduledKeys())
                .containsExactly(
                        new StorageKey("stories/story/cover/thumbnail"),
                        new StorageKey("stories/story/cover/display"),
                        new StorageKey("media/thumbnail-a"),
                        new StorageKey("media/display-a")
                );
        assertThat(context.calls()).containsExactly(
                "find Story for update",
                "find participant",
                "find media keys",
                "delete invites",
                "delete memories",
                "delete story",
                "schedule cleanup"
        );
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {
            "CO_OWNER",
            "EDITOR",
            "VIEWER"
    })
    void shouldDenyNonOwnerRoles(StoryRole role) {

        TestContext context = testContext(
                Optional.of(storyWithCover()),
                Optional.of(participant(role))
        );

        assertStoryNotFound(() -> context.service().deleteStory(command()));

        assertThat(context.deletionRepository().deleteCallCount()).isZero();
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
        assertThat(context.calls()).containsExactly(
                "find Story for update",
                "find participant"
        );
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryIsMissing() {

        TestContext context = testContext(
                Optional.empty(),
                Optional.of(participant(StoryRole.OWNER))
        );

        assertStoryNotFound(() -> context.service().deleteStory(command()));

        assertThat(context.participantRepository().findCallCount()).isZero();
        assertThat(context.deletionRepository().deleteCallCount()).isZero();
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldThrowStoryNotFoundWhenRequesterIsNotParticipant() {

        TestContext context = testContext(
                Optional.of(storyWithCover()),
                Optional.empty()
        );

        assertStoryNotFound(() -> context.service().deleteStory(command()));

        assertThat(context.deletionRepository().deleteCallCount()).isZero();
        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldThrowWhenDeleteAffectsNoRowsAfterLockedLookup() {

        TestContext context = testContext(
                Optional.of(storyWithCover()),
                Optional.of(participant(StoryRole.OWNER))
        );
        context.deletionRepository().deleteStoryResult(false);

        assertThatThrownBy(() -> context.service().deleteStory(command()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Story delete affected no rows after locked lookup");

        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
    }

    @Test
    void shouldScheduleEmptyCleanupWhenStoryHasNoStorageKeys() {

        TestContext context = testContext(
                Optional.of(storyWithoutCover()),
                Optional.of(participant(StoryRole.OWNER))
        );

        context.service().deleteStory(command());

        assertThat(context.cleanupScheduler().scheduledKeys()).isEmpty();
        assertThat(context.calls()).containsExactly(
                "find Story for update",
                "find participant",
                "find media keys",
                "delete invites",
                "delete memories",
                "delete story",
                "schedule cleanup"
        );
    }

    @Test
    void shouldRejectNullCommand() {

        assertThatThrownBy(() -> testContext(
                Optional.of(storyWithCover()),
                Optional.of(participant(StoryRole.OWNER))
        ).service().deleteStory(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    @Test
    void shouldRejectNullDependencies() {

        TestContext context = testContext(
                Optional.of(storyWithCover()),
                Optional.of(participant(StoryRole.OWNER))
        );

        assertThatThrownBy(() -> new TransactionalDeleteStoryService(
                null,
                context.participantRepository(),
                context.deletionRepository(),
                context.cleanupScheduler(),
                new StoryAccessPolicy()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteStoryService(
                context.storyRepository(),
                null,
                context.deletionRepository(),
                context.cleanupScheduler(),
                new StoryAccessPolicy()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteStoryService(
                context.storyRepository(),
                context.participantRepository(),
                null,
                context.cleanupScheduler(),
                new StoryAccessPolicy()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyDeletionRepository must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteStoryService(
                context.storyRepository(),
                context.participantRepository(),
                context.deletionRepository(),
                null,
                new StoryAccessPolicy()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("cleanupScheduler must not be null");

        assertThatThrownBy(() -> new TransactionalDeleteStoryService(
                context.storyRepository(),
                context.participantRepository(),
                context.deletionRepository(),
                context.cleanupScheduler(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("accessPolicy must not be null");
    }

    private static void assertStoryNotFound(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    private static TestContext testContext(
            Optional<Story> story,
            Optional<StoryParticipant> participant
    ) {
        List<String> calls = new ArrayList<>();
        FakeStoryRepository storyRepository =
                new FakeStoryRepository(story, calls);
        FakeStoryParticipantRepository participantRepository =
                new FakeStoryParticipantRepository(participant, calls);
        FakeStoryDeletionRepository deletionRepository =
                new FakeStoryDeletionRepository(calls);
        FakeStorageCleanupScheduler cleanupScheduler =
                new FakeStorageCleanupScheduler(calls);

        return new TestContext(
                new TransactionalDeleteStoryService(
                        storyRepository,
                        participantRepository,
                        deletionRepository,
                        cleanupScheduler,
                        new StoryAccessPolicy()
                ),
                storyRepository,
                participantRepository,
                deletionRepository,
                cleanupScheduler,
                calls
        );
    }

    private static DeleteStoryCommand command() {
        return new DeleteStoryCommand(new AuthenticatedUser(USER_ID), STORY_ID);
    }

    private static StoryParticipant participant(StoryRole role) {
        return new StoryParticipant(STORY_ID, USER_ID, role, BASE_TIME);
    }

    private static Story storyWithCover() {
        return new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                "The beginning",
                null,
                new StoryCoverMetadata(
                        "stories/story/cover/display",
                        2_048L,
                        "stories/story/cover/thumbnail",
                        512L,
                        "image/jpeg",
                        BASE_TIME
                ),
                BASE_TIME,
                BASE_TIME
        );
    }

    private static Story storyWithoutCover() {
        return new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                "The beginning",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private record TestContext(
            TransactionalDeleteStoryService service,
            FakeStoryRepository storyRepository,
            FakeStoryParticipantRepository participantRepository,
            FakeStoryDeletionRepository deletionRepository,
            FakeStorageCleanupScheduler cleanupScheduler,
            List<String> calls
    ) {
    }

    @FunctionalInterface
    private interface ThrowingAction {
        void run();
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        private final Optional<Story> story;
        private final List<String> calls;
        private UUID receivedStoryId;

        private FakeStoryRepository(
                Optional<Story> story,
                List<String> calls
        ) {
            this.story = story;
            this.calls = calls;
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
            calls.add("find Story for update");
            receivedStoryId = id;

            return story;
        }

        @Override
        public boolean lockById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            throw new UnsupportedOperationException();
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final Optional<StoryParticipant> participant;
        private final List<String> calls;
        private UUID receivedStoryId;
        private UUID receivedUserId;
        private int findCallCount;

        private FakeStoryParticipantRepository(
                Optional<StoryParticipant> participant,
                List<String> calls
        ) {
            this.participant = participant;
            this.calls = calls;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            calls.add("find participant");
            receivedStoryId = storyId;
            receivedUserId = userId;
            findCallCount++;

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

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private int findCallCount() {
            return findCallCount;
        }
    }

    private static final class FakeStoryDeletionRepository
            implements StoryDeletionRepository {

        private final List<String> calls;
        private List<StoryDeletionMediaStorageKeys> mediaKeys = List.of();
        private UUID deletedInvitesStoryId;
        private UUID deletedMemoriesStoryId;
        private UUID deletedStoryId;
        private boolean deleteStoryResult = true;
        private int deleteCallCount;

        private FakeStoryDeletionRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public List<StoryDeletionMediaStorageKeys> findMediaStorageKeysByStoryId(
                UUID storyId
        ) {
            calls.add("find media keys");

            return mediaKeys;
        }

        @Override
        public int deleteInvitesByStoryId(UUID storyId) {
            calls.add("delete invites");
            deletedInvitesStoryId = storyId;
            deleteCallCount++;

            return 1;
        }

        @Override
        public int deleteMemoriesByStoryId(UUID storyId) {
            calls.add("delete memories");
            deletedMemoriesStoryId = storyId;
            deleteCallCount++;

            return 1;
        }

        @Override
        public boolean deleteStoryById(UUID storyId) {
            calls.add("delete story");
            deletedStoryId = storyId;
            deleteCallCount++;

            return deleteStoryResult;
        }

        private void mediaKeys(List<StoryDeletionMediaStorageKeys> mediaKeys) {
            this.mediaKeys = mediaKeys;
        }

        private void deleteStoryResult(boolean deleteStoryResult) {
            this.deleteStoryResult = deleteStoryResult;
        }

        private UUID deletedInvitesStoryId() {
            return deletedInvitesStoryId;
        }

        private UUID deletedMemoriesStoryId() {
            return deletedMemoriesStoryId;
        }

        private UUID deletedStoryId() {
            return deletedStoryId;
        }

        private int deleteCallCount() {
            return deleteCallCount;
        }
    }

    private static final class FakeStorageCleanupScheduler
            implements StorageCleanupScheduler {

        private final List<String> calls;
        private final List<StorageKey> scheduledKeys = new ArrayList<>();

        private FakeStorageCleanupScheduler(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public void schedule(Collection<StorageKey> storageKeys) {
            calls.add("schedule cleanup");
            scheduledKeys.addAll(storageKeys);
        }

        private List<StorageKey> scheduledKeys() {
            return scheduledKeys;
        }
    }
}
