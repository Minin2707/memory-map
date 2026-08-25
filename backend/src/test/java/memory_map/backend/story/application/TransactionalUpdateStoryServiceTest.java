package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalUpdateStoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-02T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");

    @Test
    void shouldUpdateStoryForOwner() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        UserStory result = context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        ));

        assertThat(result).isEqualTo(new UserStory(
                updatedStory("Updated Story", "The beginning"),
                StoryRole.OWNER
        ));
        assertThat(context.userStoryRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.userStoryRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.storyRepository().updatedStory())
                .isEqualTo(updatedStory("Updated Story", "The beginning"));
    }

    @Test
    void shouldUpdateStoryForCoOwner() {

        TestContext context = testContext(userStory(StoryRole.CO_OWNER));

        UserStory result = context.service().updateStory(command(
                UpdateStoryField.notProvided(),
                UpdateStoryField.provided("Updated description")
        ));

        assertThat(result.role()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(context.storyRepository().updatedStory())
                .isEqualTo(updatedStory(
                        "Our Story",
                        "Updated description"
                ));
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyRolesThatCannotUpdateStoryMetadata(StoryRole role) {

        TestContext context = testContext(userStory(role));

        assertStoryNotFound(() -> context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        )));

        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryIsMissingOrInaccessible() {

        TestContext context = testContext(Optional.empty());

        assertStoryNotFound(() -> context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        )));

        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldApplyTitleOnlyUpdate() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        ));

        Story updated = context.storyRepository().updatedStory();

        assertThat(updated.id()).isEqualTo(STORY_ID);
        assertThat(updated.ownerId()).isEqualTo(OWNER_ID);
        assertThat(updated.title()).isEqualTo("Updated Story");
        assertThat(updated.description()).isEqualTo("The beginning");
        assertThat(updated.createdAt()).isEqualTo(CREATED_AT);
        assertThat(updated.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldApplyDescriptionOnlyUpdate() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        context.service().updateStory(command(
                UpdateStoryField.notProvided(),
                UpdateStoryField.provided("Updated description")
        ));

        Story updated = context.storyRepository().updatedStory();

        assertThat(updated.title()).isEqualTo("Our Story");
        assertThat(updated.description()).isEqualTo("Updated description");
    }

    @Test
    void shouldClearDescriptionWhenProvidedNull() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        context.service().updateStory(command(
                UpdateStoryField.notProvided(),
                UpdateStoryField.<String>provided(null)
        ));

        assertThat(context.storyRepository().updatedStory().description())
                .isNull();
    }

    @Test
    void shouldApplyBothFields() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.provided("Updated description")
        ));

        Story updated = context.storyRepository().updatedStory();

        assertThat(updated.title()).isEqualTo("Updated Story");
        assertThat(updated.description()).isEqualTo("Updated description");
    }

    @Test
    void shouldUpdateEvenWhenProvidedValuesAreSameAsExistingValues() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        context.service().updateStory(command(
                UpdateStoryField.provided("Our Story"),
                UpdateStoryField.provided("The beginning")
        ));

        assertThat(context.storyRepository().updateCallCount()).isEqualTo(1);
        assertThat(context.storyRepository().updatedStory().updatedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectNullUserStoryRepositoryDependency() {

        StoryRepository storyRepository = testContext(
                userStory(StoryRole.OWNER)
        ).storyRepository();

        assertThatThrownBy(() -> new TransactionalUpdateStoryService(
                null,
                storyRepository
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userStoryRepository must not be null");
    }

    @Test
    void shouldRejectNullStoryRepositoryDependency() {

        UserStoryRepository userStoryRepository = testContext(
                userStory(StoryRole.OWNER)
        ).userStoryRepository();

        assertThatThrownBy(() -> new TransactionalUpdateStoryService(
                userStoryRepository,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");
    }

    @Test
    void shouldRejectNullCommand() {

        assertThatThrownBy(() -> testContext(
                userStory(StoryRole.OWNER)
        ).service().updateStory(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    @Test
    void shouldPropagateLookupRepositoryFailure() {

        RuntimeException failure =
                new RuntimeException("lookup failed");
        TestContext context = testContext(userStory(StoryRole.OWNER));
        context.userStoryRepository().failWith(failure);

        assertThatThrownBy(() -> context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        )))
                .isSameAs(failure);
        assertThat(context.storyRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldPropagateUpdateRepositoryFailure() {

        RuntimeException failure =
                new RuntimeException("update failed");
        TestContext context = testContext(userStory(StoryRole.OWNER));
        context.storyRepository().failOnUpdate(failure);

        assertThatThrownBy(() -> context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        )))
                .isSameAs(failure);
    }

    @Test
    void shouldLookupBeforeUpdate() {

        TestContext context = testContext(userStory(StoryRole.OWNER));

        context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        ));

        assertThat(context.calls()).containsExactly(
                "find UserStory",
                "update Story"
        );
    }

    @Test
    void shouldReturnExactStoryReturnedByRepositoryWithSameRole() {

        TestContext context = testContext(userStory(StoryRole.CO_OWNER));
        Story repositoryResult = new Story(
                STORY_ID,
                OWNER_ID,
                "Repository Story",
                "Repository description",
                null,
                CREATED_AT,
                UPDATED_AT
        );
        context.storyRepository().returnUpdatedStory(repositoryResult);

        UserStory result = context.service().updateStory(command(
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        ));

        assertThat(result.story()).isSameAs(repositoryResult);
        assertThat(result.role()).isEqualTo(StoryRole.CO_OWNER);
    }

    private static void assertStoryNotFound(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    private static TestContext testContext(UserStory userStory) {
        return testContext(Optional.of(userStory));
    }

    private static TestContext testContext(Optional<UserStory> userStory) {
        List<String> calls = new ArrayList<>();
        FakeUserStoryRepository userStoryRepository =
                new FakeUserStoryRepository(userStory, calls);
        FakeStoryRepository storyRepository =
                new FakeStoryRepository(calls);

        return new TestContext(
                new TransactionalUpdateStoryService(
                        userStoryRepository,
                        storyRepository
                ),
                userStoryRepository,
                storyRepository,
                calls
        );
    }

    private static UpdateStoryCommand command(
            UpdateStoryField<String> title,
            UpdateStoryField<String> description
    ) {
        return new UpdateStoryCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                title,
                description,
                CURRENT_TIME
        );
    }

    private static UserStory userStory(StoryRole role) {
        return new UserStory(
                existingStory(),
                role
        );
    }

    private static Story existingStory() {
        return new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                "The beginning",
                null,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static Story updatedStory(
            String title,
            String description
    ) {
        return new Story(
                STORY_ID,
                OWNER_ID,
                title,
                description,
                null,
                CREATED_AT,
                CURRENT_TIME
        );
    }

    private record TestContext(

            TransactionalUpdateStoryService service,

            FakeUserStoryRepository userStoryRepository,

            FakeStoryRepository storyRepository,

            List<String> calls

    ) {
    }

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        private final Optional<UserStory> userStory;
        private final List<String> calls;
        private UUID receivedStoryId;
        private UUID receivedUserId;
        private RuntimeException failure;

        private FakeUserStoryRepository(
                Optional<UserStory> userStory,
                List<String> calls
        ) {
            this.userStory = userStory;
            this.calls = calls;
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
            calls.add("find UserStory");
            receivedStoryId = storyId;
            receivedUserId = userId;

            if (failure != null) {
                throw failure;
            }

            return userStory;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private void failWith(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        private final List<String> calls;
        private Story updatedStory;
        private Story updateResult;
        private int updateCallCount;
        private RuntimeException failure;

        private FakeStoryRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Story save(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Story update(Story story) {
            calls.add("update Story");
            updateCallCount++;
            updatedStory = story;

            if (failure != null) {
                throw failure;
            }

            if (updateResult != null) {
                return updateResult;
            }

            return story;
        }

        @Override
        public Optional<Story> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean lockById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            throw new UnsupportedOperationException();
        }

        private Story updatedStory() {
            return updatedStory;
        }

        private int updateCallCount() {
            return updateCallCount;
        }

        private void returnUpdatedStory(Story story) {
            updateResult = story;
        }

        private void failOnUpdate(RuntimeException failure) {
            this.failure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
