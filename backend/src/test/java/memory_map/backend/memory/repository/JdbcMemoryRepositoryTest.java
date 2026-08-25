package memory_map.backend.memory.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

class JdbcMemoryRepositoryTest extends IntegrationTest {

    @Autowired
    private MemoryRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private JdbcClient jdbcClient;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    private User createUser(String googleSubject) {
        return new User(
                UUID.randomUUID(),
                googleSubject,
                "Konstantin",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private User saveUser(String googleSubject) {
        return userRepository.save(
                createUser(googleSubject)
        );
    }

    private Story createStory(UUID ownerId) {
        return createStory(
                UUID.randomUUID(),
                ownerId
        );
    }

    private Story createStory(UUID id, UUID ownerId) {
        return new Story(
                id,
                ownerId,
                "Our Story",
                "The beginning of our journey",
                null,
                BASE_TIME,
                BASE_TIME
        );
    }

    private Story saveStory(User owner) {
        return storyRepository.save(
                createStory(owner.id())
        );
    }

    private Story saveStory(UUID id, User owner) {
        return storyRepository.save(
                createStory(id, owner.id())
        );
    }

    private Memory createMemory(
            UUID storyId,
            UUID createdBy
    ) {
        return createMemory(
                UUID.randomUUID(),
                storyId,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );
    }

    private Memory createMemory(
            UUID id,
            UUID storyId,
            UUID createdBy,
            String title,
            String description,
            String placeName,
            double latitude,
            double longitude,
            LocalDate eventDate,
            Instant createdAt,
            Instant updatedAt
    ) {
        return new Memory(
                id,
                storyId,
                createdBy,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                createdAt,
                updatedAt
        );
    }

    private void assertMemoryMatches(
            Memory actual,
            Memory expected
    ) {
        assertThat(actual.id()).isEqualTo(expected.id());
        assertThat(actual.storyId()).isEqualTo(expected.storyId());
        assertThat(actual.createdBy()).isEqualTo(expected.createdBy());
        assertThat(actual.title()).isEqualTo(expected.title());
        assertThat(actual.description()).isEqualTo(expected.description());
        assertThat(actual.placeName()).isEqualTo(expected.placeName());
        assertThat(actual.latitude()).isCloseTo(expected.latitude(), within(0.000001));
        assertThat(actual.longitude()).isCloseTo(expected.longitude(), within(0.000001));
        assertThat(actual.eventDate()).isEqualTo(expected.eventDate());
        assertThat(actual.createdAt()).isEqualTo(expected.createdAt());
        assertThat(actual.updatedAt()).isEqualTo(expected.updatedAt());
    }

    @Test
    void shouldSaveAndFindMemoryById() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                user.id()
        );

        repository.save(memory);

        Memory loaded = repository.findById(memory.id())
                .orElseThrow();

        assertMemoryMatches(loaded, memory);
    }

    @Test
    void shouldPreserveNullableFields() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                UUID.randomUUID(),
                story.id(),
                user.id(),
                "Quiet evening",
                null,
                null,
                41.715137,
                44.827096,
                LocalDate.of(2024, 6, 1),
                BASE_TIME,
                BASE_TIME
        );

        repository.save(memory);

        Memory loaded = repository.findById(memory.id())
                .orElseThrow();

        assertThat(loaded.description()).isNull();
        assertThat(loaded.placeName()).isNull();
    }

    @Test
    void shouldReturnEmptyWhenMemoryDoesNotExist() {

        Optional<Memory> found =
                repository.findById(UUID.randomUUID());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindExistingMemoryByIdForUpdate() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                user.id()
        );

        repository.save(memory);

        Optional<Memory> found =
                repository.findByIdForUpdate(memory.id());

        assertThat(found)
                .contains(memory);

        assertThat(repository.findById(memory.id()))
                .contains(memory);
    }

    @Test
    void shouldReturnEmptyWhenLockedMemoryDoesNotExist() {

        Optional<Memory> found =
                repository.findByIdForUpdate(UUID.randomUUID());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindLockedMemoryWithNullableFields() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                UUID.randomUUID(),
                story.id(),
                user.id(),
                "Quiet evening",
                null,
                null,
                41.715137,
                44.827096,
                LocalDate.of(2024, 6, 1),
                BASE_TIME,
                BASE_TIME
        );

        repository.save(memory);

        Memory locked = repository.findByIdForUpdate(memory.id())
                .orElseThrow();

        assertMemoryMatches(locked, memory);
        assertThat(locked.description()).isNull();
        assertThat(locked.placeName()).isNull();
    }

    @Test
    void shouldRejectNullFindByIdForUpdateId() {

        assertThatThrownBy(() -> repository.findByIdForUpdate(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");
    }

    @Test
    void shouldReturnEmptyListWhenStoryHasNoMemories() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);

        List<Memory> memories =
                repository.findByStoryId(story.id());

        assertThat(memories).isEmpty();
    }

    @Test
    void shouldFindMemoriesByStoryId() {

        User user = saveUser("google-subject-123");
        Story firstStory = saveStory(user);
        Story secondStory = saveStory(user);

        Memory first = createMemory(
                firstStory.id(),
                user.id()
        );
        Memory second = createMemory(
                UUID.randomUUID(),
                firstStory.id(),
                user.id(),
                "Second trip",
                "Another day",
                "Batumi",
                41.616754,
                41.636745,
                LocalDate.of(2024, 5, 21),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        );
        Memory other = createMemory(
                secondStory.id(),
                user.id()
        );

        repository.save(first);
        repository.save(second);
        repository.save(other);

        List<Memory> memories =
                repository.findByStoryId(firstStory.id());

        assertThat(memories)
                .hasSize(2);

        assertMemoryMatches(memories.get(0), first);
        assertMemoryMatches(memories.get(1), second);
    }

    @Test
    void shouldFindMemoriesByStoryIdSortedByEventDateCreatedAtAndId() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);

        Memory first = createMemory(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                story.id(),
                user.id(),
                "First",
                "First by event date",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 1, 1),
                BASE_TIME.plusSeconds(2),
                BASE_TIME.plusSeconds(2)
        );
        Memory second = createMemory(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                story.id(),
                user.id(),
                "Second",
                "Second by created at",
                "Tbilisi",
                41.715138,
                44.827097,
                LocalDate.of(2024, 1, 2),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        );
        Memory third = createMemory(
                UUID.fromString("00000000-0000-0000-0000-000000000003"),
                story.id(),
                user.id(),
                "Third",
                "Third by id",
                "Tbilisi",
                41.715139,
                44.827098,
                LocalDate.of(2024, 1, 2),
                BASE_TIME.plusSeconds(3),
                BASE_TIME.plusSeconds(3)
        );
        Memory fourth = createMemory(
                UUID.fromString("00000000-0000-0000-0000-000000000004"),
                story.id(),
                user.id(),
                "Fourth",
                "Fourth by id",
                "Tbilisi",
                41.715140,
                44.827099,
                LocalDate.of(2024, 1, 2),
                BASE_TIME.plusSeconds(3),
                BASE_TIME.plusSeconds(3)
        );

        repository.save(fourth);
        repository.save(third);
        repository.save(second);
        repository.save(first);

        List<Memory> memories =
                repository.findByStoryId(story.id());

        assertThat(memories)
                .extracting(Memory::id)
                .containsExactly(
                        first.id(),
                        second.id(),
                        third.id(),
                        fourth.id()
                );
    }

    @Test
    void shouldUpdateMemory() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                user.id()
        );
        Memory updatedMemory = createMemory(
                memory.id(),
                memory.storyId(),
                memory.createdBy(),
                "Updated title",
                "Updated description",
                "Kutaisi",
                42.267910,
                42.694595,
                LocalDate.of(2025, 1, 2),
                memory.createdAt(),
                BASE_TIME.plusSeconds(60)
        );

        repository.save(memory);

        boolean updated = repository.update(updatedMemory);

        Memory loaded = repository.findById(memory.id())
                .orElseThrow();

        assertThat(updated).isTrue();
        assertMemoryMatches(loaded, updatedMemory);
        assertThat(loaded.id()).isEqualTo(memory.id());
        assertThat(loaded.storyId()).isEqualTo(memory.storyId());
        assertThat(loaded.createdBy()).isEqualTo(memory.createdBy());
        assertThat(loaded.createdAt()).isEqualTo(memory.createdAt());
    }

    @Test
    void shouldUpdateNullableFieldsToNull() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                user.id()
        );
        Memory updatedMemory = createMemory(
                memory.id(),
                memory.storyId(),
                memory.createdBy(),
                memory.title(),
                null,
                null,
                memory.latitude(),
                memory.longitude(),
                memory.eventDate(),
                memory.createdAt(),
                BASE_TIME.plusSeconds(60)
        );

        repository.save(memory);

        boolean updated = repository.update(updatedMemory);

        Memory loaded = repository.findById(memory.id())
                .orElseThrow();

        assertThat(updated).isTrue();
        assertThat(loaded.description()).isNull();
        assertThat(loaded.placeName()).isNull();
    }

    @Test
    void shouldReturnFalseWhenUpdatingMissingMemory() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                UUID.randomUUID(),
                story.id(),
                user.id(),
                "Missing",
                "This row was never inserted",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME.plusSeconds(60)
        );

        boolean updated = repository.update(memory);

        assertThat(updated).isFalse();
    }

    @Test
    void shouldRejectNullMemoryUpdate() {

        assertThatThrownBy(() -> repository.update(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memory must not be null");
    }

    @Test
    void shouldDeleteMemory() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory first = createMemory(
                story.id(),
                user.id()
        );
        Memory second = createMemory(
                UUID.randomUUID(),
                story.id(),
                user.id(),
                "Second trip",
                "Another day",
                "Batumi",
                41.616754,
                41.636745,
                LocalDate.of(2024, 5, 21),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        );

        repository.save(first);
        repository.save(second);

        boolean deleted = repository.delete(first.id());

        assertThat(deleted).isTrue();
        assertThat(repository.findById(first.id()))
                .isEmpty();

        assertThat(repository.findById(second.id()))
                .isPresent();

        assertThat(storyRepository.findById(story.id()))
                .isPresent();
    }

    @Test
    void shouldReturnFalseWhenDeletingMissingMemory() {

        boolean deleted = repository.delete(UUID.randomUUID());

        assertThat(deleted).isFalse();
    }

    @Test
    void shouldReturnFalseWhenDeletingMemoryTwice() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                user.id()
        );

        repository.save(memory);

        boolean firstDelete = repository.delete(memory.id());
        boolean secondDelete = repository.delete(memory.id());

        assertThat(firstDelete).isTrue();
        assertThat(secondDelete).isFalse();
        assertThat(repository.findById(memory.id()))
                .isEmpty();
    }

    @Test
    void shouldRejectNullMemoryDeleteId() {

        assertThatThrownBy(() -> repository.delete(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");
    }

    @Test
    void shouldRejectDuplicateMemoryId() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                user.id()
        );

        repository.save(memory);

        assertThatThrownBy(() -> repository.save(memory))
                .isInstanceOf(DuplicateKeyException.class);
    }

    @Test
    void shouldRejectMemoryWithUnknownStory() {

        User user = saveUser("google-subject-123");
        Memory memory = createMemory(
                UUID.randomUUID(),
                user.id()
        );

        assertThatThrownBy(() -> repository.save(memory))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void shouldRejectMemoryWithUnknownCreator() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                UUID.randomUUID()
        );

        assertThatThrownBy(() -> repository.save(memory))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void shouldRoundTripPostgisLocationCoordinates() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                UUID.randomUUID(),
                story.id(),
                user.id(),
                "Tbilisi",
                "Coordinates with precision",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );

        repository.save(memory);

        Memory loaded = repository.findById(memory.id())
                .orElseThrow();

        assertThat(loaded.latitude())
                .isCloseTo(41.715137, within(0.000001));

        assertThat(loaded.longitude())
                .isCloseTo(44.827096, within(0.000001));
    }

    @Test
    void shouldStorePostgisLocationWithSrid4326() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                UUID.randomUUID(),
                story.id(),
                user.id(),
                "Tbilisi",
                "SRID must remain explicit",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );

        repository.save(memory);

        Integer srid = jdbcClient.sql("""
                SELECT ST_SRID(location::geometry)
                FROM memories
                WHERE id = :id
                """)
                .param("id", memory.id())
                .query(Integer.class)
                .single();

        assertThat(srid).isEqualTo(4326);
    }

    @Test
    void shouldRollbackRepositoryDeleteInExternalTransaction() {

        User user = saveUser("google-subject-123");
        Story story = saveStory(user);
        Memory memory = createMemory(
                story.id(),
                user.id()
        );
        TransactionTemplate transactionTemplate =
                new TransactionTemplate(transactionManager);

        repository.save(memory);

        assertThatThrownBy(() ->
                transactionTemplate.execute(status -> {
                    boolean deleted = repository.delete(memory.id());

                    assertThat(deleted).isTrue();
                    assertThat(repository.findById(memory.id()))
                            .isEmpty();

                    throw new IllegalStateException("rollback memory delete");
                })
        )
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("rollback memory delete");

        assertThat(repository.findById(memory.id()))
                .contains(memory);
    }
}
