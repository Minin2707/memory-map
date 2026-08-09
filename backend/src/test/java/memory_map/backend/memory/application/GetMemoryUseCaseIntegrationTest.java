package memory_map.backend.memory.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
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
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

class GetMemoryUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private GetMemoryUseCase getMemoryUseCase;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID REQUESTER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
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

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldReturnMemoryForEveryParticipantRole(StoryRole role) {

        Fixture fixture = authorizedFixture(role);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));

        Memory result = getMemoryUseCase.getMemory(
                new AuthenticatedUser(fixture.requester().id()),
                memory.id()
        );

        assertMemoryMatches(result, memory);
        assertMemoryMatches(
                memoryRepository.findById(memory.id()).orElseThrow(),
                memory
        );
    }

    @Test
    void shouldReturnNullableFieldsAndExactCoordinates() {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);
        Memory memory = saveMemory(memory(
                MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "Quiet evening",
                null,
                null,
                52.520008,
                13.404954,
                LocalDate.of(2024, 2, 14),
                BASE_TIME,
                BASE_TIME.plusSeconds(1)
        ));

        Memory result = getMemoryUseCase.getMemory(
                new AuthenticatedUser(fixture.requester().id()),
                memory.id()
        );

        assertMemoryMatches(result, memory);
        assertThat(result.description()).isNull();
        assertThat(result.placeName()).isNull();
    }

    @Test
    void shouldUseSafeFailureForMissingAndInaccessibleMemory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User outsider = saveUser(REQUESTER_ID, "outsider-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        MemoryNotFoundException inaccessible = catchMemoryNotFound(
                new AuthenticatedUser(outsider.id()),
                memory.id()
        );
        MemoryNotFoundException missing = catchMemoryNotFound(
                new AuthenticatedUser(outsider.id()),
                UUID.randomUUID()
        );

        assertThat(inaccessible.getClass()).isEqualTo(missing.getClass());
        assertThat(inaccessible.getMessage())
                .isEqualTo(missing.getMessage())
                .isEqualTo("Memory was not found");
        assertMemoryMatches(
                memoryRepository.findById(memory.id()).orElseThrow(),
                memory
        );
    }

    @Test
    void shouldDenyParticipantOfAnotherStory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User requester = saveUser(REQUESTER_ID, "requester-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(otherStory.id(), requester.id(), StoryRole.EDITOR);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        MemoryNotFoundException exception = catchMemoryNotFound(
                new AuthenticatedUser(requester.id()),
                memory.id()
        );

        assertThat(exception).hasMessage("Memory was not found");
        assertMemoryMatches(
                memoryRepository.findById(memory.id()).orElseThrow(),
                memory
        );
    }

    @Test
    void shouldDenyOwnerWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        MemoryNotFoundException exception = catchMemoryNotFound(
                new AuthenticatedUser(owner.id()),
                memory.id()
        );

        assertThat(exception).hasMessage("Memory was not found");
    }

    @Test
    void shouldDenyFormerAuthorWithoutMembership() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User formerAuthor =
                saveUser(REQUESTER_ID, "former-author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(defaultMemory(
                story.id(),
                formerAuthor.id()
        ));

        MemoryNotFoundException exception = catchMemoryNotFound(
                new AuthenticatedUser(formerAuthor.id()),
                memory.id()
        );

        assertThat(exception).hasMessage("Memory was not found");
    }

    private MemoryNotFoundException catchMemoryNotFound(
            AuthenticatedUser authenticatedUser,
            UUID memoryId
    ) {
        try {
            getMemoryUseCase.getMemory(authenticatedUser, memoryId);
        } catch (MemoryNotFoundException exception) {
            return exception;
        }

        throw new AssertionError("Expected MemoryNotFoundException");
    }

    private Fixture authorizedFixture(StoryRole role) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User requester = role == StoryRole.OWNER
                ? owner
                : saveUser(REQUESTER_ID, "requester-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), requester.id(), role);

        return new Fixture(owner, requester, story);
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

    private Memory saveMemory(Memory memory) {
        memoryRepository.save(memory);
        return memory;
    }

    private static Memory defaultMemory(UUID storyId, UUID createdBy) {
        return memory(
                MEMORY_ID,
                storyId,
                createdBy,
                "First",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 2, 14),
                BASE_TIME,
                BASE_TIME
        );
    }

    private static Memory memory(
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

    private record Fixture(

            User owner,

            User requester,

            Story story

    ) {
    }
}
