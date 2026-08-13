package memory_map.backend.memory.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.story.application.StoryNotFoundException;
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
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

class GetStoryMemoriesUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private GetStoryMemoriesUseCase getStoryMemoriesUseCase;

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
    void shouldReturnOrderedMemoriesForEveryParticipantRole(StoryRole role) {

        Fixture fixture = authorizedFixture(role);
        Memory second = saveMemory(memory(
                SECOND_MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "Second",
                null,
                null,
                52.520008,
                13.404954,
                LocalDate.of(2024, 2, 15),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        ));
        Memory first = saveMemory(memory(
                MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "First",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 2, 14),
                BASE_TIME,
                BASE_TIME
        ));

        List<MemoryReadModel> result = getStoryMemoriesUseCase.getMemories(
                new AuthenticatedUser(fixture.requester().id()),
                fixture.story().id()
        );

        assertThat(result).hasSize(2);
        assertMemoryMatches(result.get(0).memory(), first);
        assertMemoryMatches(result.get(1).memory(), second);
        assertThat(result).extracting(MemoryReadModel::previewPhoto)
                .containsExactly(null, null);
        assertMemoryMatches(
                memoryRepository.findById(first.id()).orElseThrow(),
                first
        );
    }

    @Test
    void shouldReturnAccessibleEmptyStory() {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);

        List<MemoryReadModel> result = getStoryMemoriesUseCase.getMemories(
                new AuthenticatedUser(fixture.requester().id()),
                fixture.story().id()
        );

        assertThat(result).isEmpty();
    }

    @Test
    void shouldUseSafeFailureForMissingAndInaccessibleStory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User outsider = saveUser(REQUESTER_ID, "outsider-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveMemory(defaultMemory(story.id(), owner.id()));

        StoryNotFoundException inaccessible = catchStoryNotFound(
                new AuthenticatedUser(outsider.id()),
                story.id()
        );
        StoryNotFoundException missing = catchStoryNotFound(
                new AuthenticatedUser(outsider.id()),
                OTHER_STORY_ID
        );

        assertThat(inaccessible.getClass()).isEqualTo(missing.getClass());
        assertThat(inaccessible.getMessage())
                .isEqualTo(missing.getMessage())
                .isEqualTo("Story was not found");
    }

    @Test
    void shouldDenyParticipantOfAnotherStory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User requester = saveUser(REQUESTER_ID, "requester-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(otherStory.id(), requester.id(), StoryRole.EDITOR);
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        StoryNotFoundException exception = catchStoryNotFound(
                new AuthenticatedUser(requester.id()),
                story.id()
        );

        assertThat(exception).hasMessage("Story was not found");
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

        StoryNotFoundException exception = catchStoryNotFound(
                new AuthenticatedUser(owner.id()),
                story.id()
        );

        assertThat(exception).hasMessage("Story was not found");
        assertMemoryMatches(
                memoryRepository.findById(memory.id()).orElseThrow(),
                memory
        );
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

        StoryNotFoundException exception = catchStoryNotFound(
                new AuthenticatedUser(formerAuthor.id()),
                story.id()
        );

        assertThat(exception).hasMessage("Story was not found");
        assertMemoryMatches(
                memoryRepository.findById(memory.id()).orElseThrow(),
                memory
        );
    }

    private StoryNotFoundException catchStoryNotFound(
            AuthenticatedUser authenticatedUser,
            UUID storyId
    ) {
        try {
            getStoryMemoriesUseCase.getMemories(authenticatedUser, storyId);
        } catch (StoryNotFoundException exception) {
            return exception;
        }

        throw new AssertionError("Expected StoryNotFoundException");
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
