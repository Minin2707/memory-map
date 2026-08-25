package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TransactionalCreateStoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    @Test
    void shouldCreateStoryFromCommand() {

        TestContext context = testContext();

        Story result = context.service().create(command(
                "Our Story",
                "The beginning of our journey"
        ));

        assertThat(result).isEqualTo(expectedStory(
                "Our Story",
                "The beginning of our journey"
        ));
        assertThat(context.storyRepository().savedStory())
                .isEqualTo(result);
    }

    @Test
    void shouldUseAuthenticatedUserAsOwner() {

        TestContext context = testContext();

        context.service().create(command());

        assertThat(context.storyRepository().savedStory().ownerId())
                .isEqualTo(USER_ID);
    }

    @Test
    void shouldUseProvidedStoryIdTitleDescriptionAndCurrentTime() {

        TestContext context = testContext();

        context.service().create(command(
                "  Our Story  ",
                "  Description  "
        ));

        Story savedStory = context.storyRepository().savedStory();

        assertThat(savedStory.id()).isEqualTo(STORY_ID);
        assertThat(savedStory.title()).isEqualTo("  Our Story  ");
        assertThat(savedStory.description()).isEqualTo("  Description  ");
        assertThat(savedStory.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(savedStory.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldAllowNullDescription() {

        TestContext context = testContext();

        context.service().create(command("Our Story", null));

        assertThat(context.storyRepository().savedStory().description())
                .isNull();
    }

    @Test
    void shouldCreateOwnerParticipant() {

        TestContext context = testContext();

        context.service().create(command());

        StoryParticipant participant =
                context.storyParticipantRepository()
                        .savedParticipant();

        assertThat(participant.storyId()).isEqualTo(STORY_ID);
        assertThat(participant.userId()).isEqualTo(USER_ID);
        assertThat(participant.role()).isEqualTo(StoryRole.OWNER);
        assertThat(participant.joinedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldSaveStoryBeforeParticipant() {

        TestContext context = testContext();

        context.service().create(command());

        assertThat(context.calls()).containsExactly(
                "save Story",
                "save StoryParticipant"
        );
    }

    @Test
    void shouldReturnCreatedStory() {

        TestContext context = testContext();

        Story result = context.service().create(command());

        assertThat(result).isSameAs(context.storyRepository().savedStory());
    }

    @Test
    void shouldRejectNullCommand() {

        assertThatThrownBy(() -> testContext().service().create(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");
    }

    @Test
    void shouldRejectNullStoryRepositoryDependency() {

        StoryParticipantRepository participantRepository =
                testContext().storyParticipantRepository();

        assertThatThrownBy(() -> new TransactionalCreateStoryService(
                null,
                participantRepository
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyRepository must not be null");
    }

    @Test
    void shouldRejectNullStoryParticipantRepositoryDependency() {

        StoryRepository storyRepository =
                testContext().storyRepository();

        assertThatThrownBy(() -> new TransactionalCreateStoryService(
                storyRepository,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
    }

    @Test
    void shouldNotGenerateUuidOrTimeInternally() {

        TestContext context = testContext();

        context.service().create(command());

        Story savedStory = context.storyRepository().savedStory();
        StoryParticipant savedParticipant =
                context.storyParticipantRepository()
                        .savedParticipant();

        assertThat(savedStory.id()).isEqualTo(STORY_ID);
        assertThat(savedStory.ownerId()).isEqualTo(USER_ID);
        assertThat(savedStory.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(savedStory.updatedAt()).isEqualTo(CURRENT_TIME);
        assertThat(savedParticipant.storyId()).isEqualTo(STORY_ID);
        assertThat(savedParticipant.userId()).isEqualTo(USER_ID);
        assertThat(savedParticipant.joinedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldPropagateStoryPersistenceFailure() {

        RuntimeException failure = new RuntimeException("story save failed");
        TestContext context = testContext();
        context.storyRepository().failOnSave(failure);

        assertThatThrownBy(() -> context.service().create(command()))
                .isSameAs(failure);
    }

    @Test
    void shouldNotSaveParticipantWhenStorySaveFails() {

        TestContext context = testContext();
        context.storyRepository().failOnSave(
                new RuntimeException("story save failed")
        );

        assertThatThrownBy(() -> context.service().create(command()))
                .isInstanceOf(RuntimeException.class);

        assertThat(context.storyParticipantRepository()
                .savedParticipant()).isNull();
        assertThat(context.calls()).containsExactly("save Story");
    }

    @Test
    void shouldPropagateParticipantPersistenceFailure() {

        RuntimeException failure =
                new RuntimeException("participant save failed");
        TestContext context = testContext();
        context.storyParticipantRepository().failOnSave(failure);

        assertThatThrownBy(() -> context.service().create(command()))
                .isSameAs(failure);
        assertThat(context.storyRepository().savedStory()).isNotNull();
    }

    private static TestContext testContext() {
        List<String> calls = new ArrayList<>();
        FakeStoryRepository storyRepository =
                new FakeStoryRepository(calls);
        FakeStoryParticipantRepository storyParticipantRepository =
                new FakeStoryParticipantRepository(calls);

        return new TestContext(
                new TransactionalCreateStoryService(
                        storyRepository,
                        storyParticipantRepository
                ),
                storyRepository,
                storyParticipantRepository,
                calls
        );
    }

    private static CreateStoryCommand command() {
        return command("Our Story", "The beginning of our journey");
    }

    private static CreateStoryCommand command(
            String title,
            String description
    ) {
        return new CreateStoryCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                title,
                description,
                CURRENT_TIME
        );
    }

    private static Story expectedStory(
            String title,
            String description
    ) {
        return new Story(
                STORY_ID,
                USER_ID,
                title,
                description,
                null,
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    private record TestContext(

            TransactionalCreateStoryService service,

            FakeStoryRepository storyRepository,

            FakeStoryParticipantRepository storyParticipantRepository,

            List<String> calls

    ) {
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        private final List<String> calls;
        private Story savedStory;
        private RuntimeException failure;

        private FakeStoryRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Story save(Story story) {
            calls.add("save Story");

            if (failure != null) {
                throw failure;
            }

            savedStory = story;

            return story;
        }

        @Override
        public Story update(Story story) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Story> findById(UUID id) {
            return Optional.empty();
        }

        @Override
        public boolean lockById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            return List.of();
        }

        private Story savedStory() {
            return savedStory;
        }

        private void failOnSave(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> calls;
        private StoryParticipant savedParticipant;
        private RuntimeException failure;

        private FakeStoryParticipantRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            return Optional.empty();
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            return List.of();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            return List.of();
        }

        @Override
        public long countOwners(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            return false;
        }

        @Override
        public void save(StoryParticipant participant) {
            calls.add("save StoryParticipant");

            if (failure != null) {
                throw failure;
            }

            savedParticipant = participant;
        }

        @Override
        public void update(StoryParticipant participant) {
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
        }

        private StoryParticipant savedParticipant() {
            return savedParticipant;
        }

        private void failOnSave(RuntimeException failure) {
            this.failure = failure;
        }
    }
}
