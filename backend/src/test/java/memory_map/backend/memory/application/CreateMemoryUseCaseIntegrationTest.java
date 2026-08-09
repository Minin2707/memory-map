package memory_map.backend.memory.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.JdbcMemoryRepository;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.story.domain.Story;
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
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

@Import(CreateMemoryUseCaseIntegrationTest.CreateMemoryUseCaseTestConfiguration.class)
class CreateMemoryUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private CreateMemoryUseCase createMemoryUseCase;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private RollbackTestingMemoryRepository rollbackTestingMemoryRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

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
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID SECOND_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2025, 5, 20);
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        rollbackTestingMemoryRepository.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldCreateMemoryForOwner() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        Memory result = createMemoryUseCase.createMemory(command(
                owner.id(),
                story.id(),
                MEMORY_ID
        ));

        Memory persisted = memoryRepository.findById(MEMORY_ID)
                .orElseThrow();

        assertMemoryMatches(result, expectedMemory(
                MEMORY_ID,
                story.id(),
                owner.id()
        ));
        assertMemoryMatches(persisted, result);
        assertThat(memoryCount()).isEqualTo(1);
    }

    @Test
    void shouldCreateMemoryForCoOwner() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(USER_ID, "co-owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);

        Memory result = createMemoryUseCase.createMemory(command(
                coOwner.id(),
                story.id(),
                MEMORY_ID
        ));

        assertThat(result.createdBy()).isEqualTo(coOwner.id());
        assertThat(result.storyId()).isEqualTo(story.id());
        assertMemoryMatches(
                memoryRepository.findById(MEMORY_ID).orElseThrow(),
                result
        );
    }

    @Test
    void shouldCreateMemoryForEditor() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User editor = saveUser(USER_ID, "editor-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), editor.id(), StoryRole.EDITOR);

        Memory result = createMemoryUseCase.createMemory(command(
                editor.id(),
                story.id(),
                MEMORY_ID
        ));

        assertThat(result.createdBy()).isEqualTo(editor.id());
        assertMemoryMatches(
                memoryRepository.findById(MEMORY_ID).orElseThrow(),
                result
        );
    }

    @Test
    void shouldDenyViewerAndCreateNoMemory() {

        assertDeniedRoleCreatesNoMemory(StoryRole.VIEWER);
    }

    @Test
    void shouldThrowMemoryUnavailableWhenStoryDoesNotExist() {

        User user = saveUser(USER_ID, "current-google-subject");

        assertMemoryUnavailable(() -> createMemoryUseCase.createMemory(
                command(user.id(), STORY_ID, MEMORY_ID)
        ));

        assertThat(memoryRepository.findById(MEMORY_ID)).isEmpty();
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldThrowSameMemoryUnavailableWhenStoryIsInaccessible() {

        User user = saveUser(USER_ID, "current-google-subject");
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());

        MemoryCreationUnavailableException inaccessible =
                catchMemoryUnavailable(() -> createMemoryUseCase.createMemory(
                        command(user.id(), story.id(), MEMORY_ID)
                ));
        MemoryCreationUnavailableException missing =
                catchMemoryUnavailable(() -> createMemoryUseCase.createMemory(
                        command(user.id(), OTHER_STORY_ID, SECOND_MEMORY_ID)
                ));

        assertThat(inaccessible.getClass()).isEqualTo(missing.getClass());
        assertThat(inaccessible.getMessage())
                .isEqualTo(missing.getMessage())
                .isEqualTo("Memory could not be created");
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldDenyOwnerWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());

        assertMemoryUnavailable(() -> createMemoryUseCase.createMemory(
                command(owner.id(), story.id(), MEMORY_ID)
        ));

        assertThat(memoryRepository.findById(MEMORY_ID)).isEmpty();
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldDenyParticipantOfAnotherStory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(otherStory.id(), user.id(), StoryRole.EDITOR);

        assertMemoryUnavailable(() -> createMemoryUseCase.createMemory(
                command(user.id(), story.id(), MEMORY_ID)
        ));

        assertThat(memoryRepository.findById(MEMORY_ID)).isEmpty();
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldDenyWrongMembershipUser() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        User otherUser = saveUser(OTHER_USER_ID, "other-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), otherUser.id(), StoryRole.EDITOR);

        assertMemoryUnavailable(() -> createMemoryUseCase.createMemory(
                command(user.id(), story.id(), MEMORY_ID)
        ));

        assertThat(memoryRepository.findById(MEMORY_ID)).isEmpty();
        assertThat(memoryCount()).isZero();
    }

    @Test
    void shouldCreateMultipleMemoriesForSameStory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        Memory first = createMemoryUseCase.createMemory(command(
                owner.id(),
                story.id(),
                MEMORY_ID
        ));
        Memory second = createMemoryUseCase.createMemory(command(
                owner.id(),
                story.id(),
                SECOND_MEMORY_ID
        ));

        assertMemoryMatches(
                memoryRepository.findById(first.id()).orElseThrow(),
                first
        );
        assertMemoryMatches(
                memoryRepository.findById(second.id()).orElseThrow(),
                second
        );
        assertThat(memoryCount()).isEqualTo(2);
    }

    @Test
    void shouldPropagateDuplicateMemoryIdFailureAndKeepOriginalMemory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory original = createMemoryUseCase.createMemory(command(
                owner.id(),
                story.id(),
                MEMORY_ID
        ));

        assertThatThrownBy(() -> createMemoryUseCase.createMemory(command(
                owner.id(),
                story.id(),
                MEMORY_ID
        )))
                .isInstanceOf(RuntimeException.class)
                .isNotInstanceOf(MemoryCreationUnavailableException.class);

        assertMemoryMatches(
                memoryRepository.findById(MEMORY_ID).orElseThrow(),
                original
        );
        assertThat(memoryCount()).isEqualTo(1);
    }

    @Test
    void shouldRollbackMemoryInsertWhenRepositoryFailsAfterSave() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        rollbackTestingMemoryRepository.failAfterSave(
                new RuntimeException("memory save failed after insert")
        );

        assertThatThrownBy(() -> createMemoryUseCase.createMemory(command(
                owner.id(),
                story.id(),
                MEMORY_ID
        )))
                .isInstanceOf(RuntimeException.class)
                .hasMessage("memory save failed after insert")
                .isNotInstanceOf(MemoryCreationUnavailableException.class);

        assertThat(memoryRepository.findById(MEMORY_ID)).isEmpty();
        assertThat(memoryCount()).isZero();
    }

    private void assertDeniedRoleCreatesNoMemory(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), user.id(), role);

        assertMemoryUnavailable(() -> createMemoryUseCase.createMemory(
                command(user.id(), story.id(), MEMORY_ID)
        ));

        assertThat(memoryRepository.findById(MEMORY_ID)).isEmpty();
        assertThat(memoryCount()).isZero();
    }

    private User saveUser(UUID id, String googleSubject) {
        return userRepository.save(new User(
                id,
                googleSubject,
                "Konstantin",
                null,
                BASE_TIME,
                BASE_TIME
        ));
    }

    private Story saveStory(UUID id, UUID ownerId) {
        return storyRepository.save(new Story(
                id,
                ownerId,
                "Our Story",
                "The beginning of our journey",
                BASE_TIME,
                BASE_TIME
        ));
    }

    private void saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role
    ) {
        storyParticipantRepository.save(new StoryParticipant(
                storyId,
                userId,
                role,
                BASE_TIME
        ));
    }

    private static CreateMemoryCommand command(
            UUID userId,
            UUID storyId,
            UUID memoryId
    ) {
        return new CreateMemoryCommand(
                new AuthenticatedUser(userId),
                storyId,
                memoryId,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        );
    }

    private static Memory expectedMemory(
            UUID memoryId,
            UUID storyId,
            UUID createdBy
    ) {
        return new Memory(
                memoryId,
                storyId,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    private static void assertMemoryMatches(
            Memory actual,
            Memory expected
    ) {
        assertThat(actual.id()).isEqualTo(expected.id());
        assertThat(actual.storyId()).isEqualTo(expected.storyId());
        assertThat(actual.createdBy()).isEqualTo(expected.createdBy());
        assertThat(actual.title()).isEqualTo(expected.title());
        assertThat(actual.description()).isEqualTo(expected.description());
        assertThat(actual.placeName()).isEqualTo(expected.placeName());
        assertThat(actual.latitude())
                .isCloseTo(expected.latitude(), within(0.000001));
        assertThat(actual.longitude())
                .isCloseTo(expected.longitude(), within(0.000001));
        assertThat(actual.eventDate()).isEqualTo(expected.eventDate());
        assertThat(actual.createdAt()).isEqualTo(expected.createdAt());
        assertThat(actual.updatedAt()).isEqualTo(expected.updatedAt());
    }

    private int memoryCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM memories
                """)
                .query(Integer.class)
                .single();
    }

    private static void assertMemoryUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(MemoryCreationUnavailableException.class)
                .hasMessage("Memory could not be created");
    }

    private static MemoryCreationUnavailableException catchMemoryUnavailable(
            ThrowingAction action
    ) {
        try {
            action.run();
        } catch (MemoryCreationUnavailableException exception) {
            return exception;
        }

        throw new AssertionError("Expected MemoryCreationUnavailableException");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class CreateMemoryUseCaseTestConfiguration {

        @Bean
        @Primary
        RollbackTestingMemoryRepository rollbackTestingMemoryRepository(
                JdbcMemoryRepository delegate,
                JdbcClient jdbcClient
        ) {
            return new RollbackTestingMemoryRepository(delegate, jdbcClient);
        }
    }

    static final class RollbackTestingMemoryRepository
            implements MemoryRepository {

        private final MemoryRepository delegate;
        private final JdbcClient jdbcClient;
        private RuntimeException failure;

        private RollbackTestingMemoryRepository(
                MemoryRepository delegate,
                JdbcClient jdbcClient
        ) {
            this.delegate = delegate;
            this.jdbcClient = jdbcClient;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            return delegate.findById(id);
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            return delegate.findByIdForUpdate(id);
        }

        @Override
        public List<Memory> findByStoryId(UUID storyId) {
            return delegate.findByStoryId(storyId);
        }

        @Override
        public void save(Memory memory) {
            delegate.save(memory);

            if (failure != null) {
                assertThat(memoryCountInCurrentTransaction(memory.id()))
                        .isEqualTo(1);
                throw failure;
            }
        }

        @Override
        public boolean update(Memory memory) {
            return delegate.update(memory);
        }

        @Override
        public boolean delete(UUID id) {
            return delegate.delete(id);
        }

        private void failAfterSave(RuntimeException failure) {
            this.failure = failure;
        }

        private void reset() {
            failure = null;
        }

        private int memoryCountInCurrentTransaction(UUID memoryId) {
            return jdbcClient.sql("""
                    SELECT COUNT(*)
                    FROM memories
                    WHERE id = :id
                    """)
                    .param("id", memoryId)
                    .query(Integer.class)
                    .single();
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
