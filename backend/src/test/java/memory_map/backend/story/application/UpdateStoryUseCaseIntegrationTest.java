package memory_map.backend.story.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.JdbcStoryRepository;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(UpdateStoryUseCaseIntegrationTest.UpdateStoryUseCaseTestConfiguration.class)
class UpdateStoryUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private UpdateStoryUseCase updateStoryUseCase;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private FailingStoryRepository failingStoryRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        failingStoryRepository.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldUpdateTitleForOwner() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        UserStory result = updateStoryUseCase.updateStory(command(
                owner.id(),
                story.id(),
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        ));

        Story persisted = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(result).isEqualTo(
                new UserStory(persisted, StoryRole.OWNER)
        );
        assertThat(persisted.id()).isEqualTo(story.id());
        assertThat(persisted.ownerId()).isEqualTo(owner.id());
        assertThat(persisted.title()).isEqualTo("Updated Story");
        assertThat(persisted.description()).isEqualTo("The beginning");
        assertThat(persisted.createdAt()).isEqualTo(story.createdAt());
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldUpdateDescriptionForCoOwner() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(USER_ID, "co-owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);

        UserStory result = updateStoryUseCase.updateStory(command(
                coOwner.id(),
                story.id(),
                UpdateStoryField.notProvided(),
                UpdateStoryField.provided("Updated description")
        ));

        Story persisted = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(result.role()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(persisted.ownerId()).isEqualTo(owner.id());
        assertThat(persisted.title()).isEqualTo("Our Story");
        assertThat(persisted.description())
                .isEqualTo("Updated description");
        assertThat(persisted.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldClearDescription() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        updateStoryUseCase.updateStory(command(
                owner.id(),
                story.id(),
                UpdateStoryField.notProvided(),
                UpdateStoryField.<String>provided(null)
        ));

        assertThat(storyRepository.findById(story.id())
                .orElseThrow()
                .description())
                .isNull();
    }

    @Test
    void shouldUpdateBothFields() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        updateStoryUseCase.updateStory(command(
                owner.id(),
                story.id(),
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.provided("Updated description")
        ));

        Story persisted = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(persisted.title()).isEqualTo("Updated Story");
        assertThat(persisted.description())
                .isEqualTo("Updated description");
    }

    @Test
    void shouldDenyEditorAndKeepStoryUnchanged() {

        assertDeniedRoleKeepsStoryUnchanged(StoryRole.EDITOR);
    }

    @Test
    void shouldDenyViewerAndKeepStoryUnchanged() {

        assertDeniedRoleKeepsStoryUnchanged(StoryRole.VIEWER);
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryDoesNotExist() {

        User user = saveUser(USER_ID, "current-google-subject");

        assertStoryNotFound(() -> updateStoryUseCase.updateStory(command(
                user.id(),
                STORY_ID,
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        )));
    }

    @Test
    void shouldThrowSameStoryNotFoundWhenStoryIsInaccessible() {

        User user = saveUser(USER_ID, "current-google-subject");
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        StoryNotFoundException inaccessible = catchStoryNotFound(
                () -> updateStoryUseCase.updateStory(command(
                        user.id(),
                        story.id(),
                        UpdateStoryField.provided("Updated Story"),
                        UpdateStoryField.notProvided()
                ))
        );
        StoryNotFoundException missing = catchStoryNotFound(
                () -> updateStoryUseCase.updateStory(command(
                        user.id(),
                        OTHER_STORY_ID,
                        UpdateStoryField.provided("Updated Story"),
                        UpdateStoryField.notProvided()
                ))
        );

        assertThat(inaccessible).hasMessage("Story was not found");
        assertThat(missing).hasMessage("Story was not found");
        assertThat(inaccessible.getClass()).isEqualTo(missing.getClass());
        assertThat(inaccessible.getMessage())
                .isEqualTo(missing.getMessage());
        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldDenyOwnerWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Owner Without Membership Story",
                "The beginning"
        );

        assertStoryNotFound(() -> updateStoryUseCase.updateStory(command(
                owner.id(),
                story.id(),
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        )));

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldDenyWrongMembershipUser() {

        User user = saveUser(USER_ID, "current-google-subject");
        User otherUser = saveUser(OTHER_USER_ID, "other-google-subject");
        Story story = saveStory(
                STORY_ID,
                otherUser.id(),
                "Wrong User Story",
                "The beginning"
        );
        saveParticipant(story.id(), otherUser.id(), StoryRole.OWNER);

        assertStoryNotFound(() -> updateStoryUseCase.updateStory(command(
                user.id(),
                story.id(),
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        )));

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    @Test
    void shouldPreserveImmutableFields() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        updateStoryUseCase.updateStory(command(
                owner.id(),
                story.id(),
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.provided("Updated description")
        ));

        Story persisted = storyRepository.findById(story.id())
                .orElseThrow();

        assertThat(persisted.id()).isEqualTo(story.id());
        assertThat(persisted.ownerId()).isEqualTo(story.ownerId());
        assertThat(persisted.createdAt()).isEqualTo(story.createdAt());
    }

    @Test
    void shouldRollbackStoryUpdateWhenRepositoryFailsAfterDatabaseUpdate() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        failingStoryRepository.failAfterUpdate(
                new RuntimeException("story update failed")
        );

        assertThatThrownBy(() -> updateStoryUseCase.updateStory(command(
                owner.id(),
                story.id(),
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.provided("Updated description")
        )))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("story update failed");

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    private void assertDeniedRoleKeepsStoryUnchanged(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), user.id(), role);

        assertStoryNotFound(() -> updateStoryUseCase.updateStory(command(
                user.id(),
                story.id(),
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided()
        )));

        assertThat(storyRepository.findById(story.id()))
                .contains(story);
    }

    private User saveUser(
            UUID userId,
            String googleSubject
    ) {
        return userRepository.save(
                new User(
                        userId,
                        googleSubject,
                        "Memory Map User",
                        null,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private Story saveStory(
            UUID storyId,
            UUID ownerId,
            String title,
            String description
    ) {
        return storyRepository.save(
                new Story(
                        storyId,
                        ownerId,
                        title,
                        description,
                        BASE_TIME,
                        BASE_TIME
                )
        );
    }

    private void saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role
    ) {
        storyParticipantRepository.save(
                new StoryParticipant(
                        storyId,
                        userId,
                        role,
                        BASE_TIME
                )
        );
    }

    private static UpdateStoryCommand command(
            UUID userId,
            UUID storyId,
            UpdateStoryField<String> title,
            UpdateStoryField<String> description
    ) {
        return new UpdateStoryCommand(
                new AuthenticatedUser(userId),
                storyId,
                title,
                description,
                CURRENT_TIME
        );
    }

    private static void assertStoryNotFound(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    private static StoryNotFoundException catchStoryNotFound(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (StoryNotFoundException exception) {
            return exception;
        }

        throw new AssertionError("Expected StoryNotFoundException");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class UpdateStoryUseCaseTestConfiguration {

        @Bean
        @Primary
        FailingStoryRepository failingStoryRepository(
                JdbcStoryRepository delegate
        ) {
            return new FailingStoryRepository(delegate);
        }
    }

    static final class FailingStoryRepository
            implements StoryRepository {

        private final StoryRepository delegate;
        private RuntimeException failure;

        private FailingStoryRepository(StoryRepository delegate) {
            this.delegate = delegate;
        }

        @Override
        public Story save(Story story) {
            return delegate.save(story);
        }

        @Override
        public Story update(Story story) {
            Story updated = delegate.update(story);

            if (failure != null) {
                throw failure;
            }

            return updated;
        }

        @Override
        public Optional<Story> findById(UUID id) {
            return delegate.findById(id);
        }

        @Override
        public boolean lockById(UUID id) {
            return delegate.lockById(id);
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            return delegate.findByOwnerId(ownerId);
        }

        private void failAfterUpdate(RuntimeException failure) {
            this.failure = failure;
        }

        private void reset() {
            failure = null;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
