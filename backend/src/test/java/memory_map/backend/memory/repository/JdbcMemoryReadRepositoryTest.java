package memory_map.backend.memory.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.memory.application.MemoryPreviewPhoto;
import memory_map.backend.memory.application.MemoryReadModel;
import memory_map.backend.memory.application.StoryMemoriesView;
import memory_map.backend.memory.domain.Memory;
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

import java.lang.reflect.Constructor;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

class JdbcMemoryReadRepositoryTest extends IntegrationTest {

    @Autowired
    private MemoryReadRepository repository;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private MediaFileRepository mediaFileRepository;

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
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
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
    void shouldFindStoryMemoriesForEveryParticipantRole(StoryRole role) {

        Fixture fixture = authorizedFixture(role);
        Memory memory = saveMemory(memory(
                MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2025, 5, 20),
                BASE_TIME,
                BASE_TIME.plusSeconds(1)
        ));

        Optional<StoryMemoriesView> result =
                repository.findByStoryIdAndRequesterUserId(
                        fixture.story().id(),
                        fixture.requester().id()
                );

        assertThat(result).isPresent();
        assertThat(result.orElseThrow().memories())
                .extracting(MemoryReadModel::memory)
                .containsExactly(memory);
    }

    @Test
    void shouldReturnAccessibleEmptyStoryMemories() {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);

        Optional<StoryMemoriesView> result =
                repository.findByStoryIdAndRequesterUserId(
                        fixture.story().id(),
                        fixture.requester().id()
                );

        assertThat(result).isPresent();
        assertThat(result.orElseThrow().memories()).isEmpty();
    }

    @Test
    void shouldReturnEmptyWhenStoryIsMissingOrInaccessible() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User requester = saveUser(REQUESTER_ID, "requester-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveMemory(defaultMemory(story.id(), owner.id()));

        assertThat(repository.findByStoryIdAndRequesterUserId(
                UUID.randomUUID(),
                requester.id()
        )).isEmpty();
        assertThat(repository.findByStoryIdAndRequesterUserId(
                story.id(),
                requester.id()
        )).isEmpty();
    }

    @Test
    void shouldDenyOwnerWithoutMembershipForList() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveMemory(defaultMemory(story.id(), owner.id()));

        Optional<StoryMemoriesView> result =
                repository.findByStoryIdAndRequesterUserId(
                        story.id(),
                        owner.id()
                );

        assertThat(result).isEmpty();
    }

    @Test
    void shouldDenyFormerAuthorWithoutMembershipForList() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User formerAuthor =
                saveUser(REQUESTER_ID, "former-author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        saveMemory(defaultMemory(story.id(), formerAuthor.id()));

        Optional<StoryMemoriesView> result =
                repository.findByStoryIdAndRequesterUserId(
                        story.id(),
                        formerAuthor.id()
                );

        assertThat(result).isEmpty();
    }

    @Test
    void shouldDenyParticipantOfAnotherStoryForList() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User requester = saveUser(REQUESTER_ID, "requester-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(otherStory.id(), requester.id(), StoryRole.VIEWER);
        saveMemory(defaultMemory(story.id(), owner.id()));

        Optional<StoryMemoriesView> result =
                repository.findByStoryIdAndRequesterUserId(
                        story.id(),
                        requester.id()
                );

        assertThat(result).isEmpty();
    }

    @Test
    void shouldPreserveCanonicalListOrder() {

        Fixture fixture = authorizedFixture(StoryRole.OWNER);
        Memory a = memory(
                UUID.fromString("00000000-0000-0000-0000-000000000004"),
                fixture.story().id(),
                fixture.owner().id(),
                "A",
                "Later event date",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2020, 1, 2),
                BASE_TIME,
                BASE_TIME
        );
        Memory b = memory(
                UUID.fromString("00000000-0000-0000-0000-000000000003"),
                fixture.story().id(),
                fixture.owner().id(),
                "B",
                "Same event, later creation",
                "Tbilisi",
                41.715138,
                44.827097,
                LocalDate.of(2020, 1, 1),
                BASE_TIME.plusSeconds(2),
                BASE_TIME.plusSeconds(2)
        );
        Memory c = memory(
                UUID.fromString("00000000-0000-0000-0000-000000000002"),
                fixture.story().id(),
                fixture.owner().id(),
                "C",
                "Same event and creation, later id",
                "Tbilisi",
                41.715139,
                44.827098,
                LocalDate.of(2020, 1, 1),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        );
        Memory d = memory(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                fixture.story().id(),
                fixture.owner().id(),
                "D",
                "Same event and creation, earlier id",
                "Tbilisi",
                41.715140,
                44.827099,
                LocalDate.of(2020, 1, 1),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        );

        saveMemory(a);
        saveMemory(b);
        saveMemory(c);
        saveMemory(d);

        List<MemoryReadModel> memories = repository
                .findByStoryIdAndRequesterUserId(
                        fixture.story().id(),
                        fixture.requester().id()
                )
                .orElseThrow()
                .memories();

        assertThat(memories)
                .extracting(memory -> memory.memory().id())
                .containsExactly(d.id(), c.id(), b.id(), a.id());
    }

    @Test
    void shouldReturnNullPreviewWhenMemoryHasNoPhoto() {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));

        MemoryReadModel result = repository.findByIdAndRequesterUserId(
                memory.id(),
                fixture.requester().id()
        ).orElseThrow();

        assertThat(result.memory()).isEqualTo(memory);
        assertThat(result.previewPhoto()).isNull();
    }

    @Test
    void shouldSelectSinglePhotoPreviewForListAndGet() {

        Fixture fixture = authorizedFixture(StoryRole.EDITOR);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME, MediaType.PHOTO);

        List<MemoryReadModel> list = repository
                .findByStoryIdAndRequesterUserId(
                        fixture.story().id(),
                        fixture.requester().id()
                )
                .orElseThrow()
                .memories();
        MemoryReadModel single = repository.findByIdAndRequesterUserId(
                memory.id(),
                fixture.requester().id()
        ).orElseThrow();

        assertThat(list).hasSize(1);
        assertThat(list.get(0).previewPhoto())
                .isEqualTo(new MemoryPreviewPhoto(MEDIA_ID));
        assertThat(single.previewPhoto())
                .isEqualTo(new MemoryPreviewPhoto(MEDIA_ID));
    }

    @Test
    void shouldSelectEarliestPhotoByCreatedAt() {

        Fixture fixture = authorizedFixture(StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        saveMediaFile(
                MEDIA_ID,
                memory.id(),
                BASE_TIME.plusSeconds(5),
                MediaType.PHOTO
        );
        saveMediaFile(
                SECOND_MEDIA_ID,
                memory.id(),
                BASE_TIME,
                MediaType.PHOTO
        );

        MemoryReadModel result = repository.findByIdAndRequesterUserId(
                memory.id(),
                fixture.requester().id()
        ).orElseThrow();

        assertThat(result.previewPhoto())
                .isEqualTo(new MemoryPreviewPhoto(SECOND_MEDIA_ID));
    }

    @Test
    void shouldBreakPreviewTieByLowestMediaId() {

        Fixture fixture = authorizedFixture(StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        saveMediaFile(
                SECOND_MEDIA_ID,
                memory.id(),
                BASE_TIME,
                MediaType.PHOTO
        );
        saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME, MediaType.PHOTO);

        MemoryReadModel result = repository.findByIdAndRequesterUserId(
                memory.id(),
                fixture.requester().id()
        ).orElseThrow();

        assertThat(result.previewPhoto())
                .isEqualTo(new MemoryPreviewPhoto(MEDIA_ID));
    }

    @Test
    void shouldNotSelectMediaBelongingToAnotherMemory() {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);
        Memory target = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        Memory other = saveMemory(memory(
                SECOND_MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "Other",
                null,
                null,
                52.520008,
                13.404954,
                LocalDate.of(2024, 2, 14),
                BASE_TIME,
                BASE_TIME
        ));
        saveMediaFile(MEDIA_ID, other.id(), BASE_TIME, MediaType.PHOTO);

        MemoryReadModel result = repository.findByIdAndRequesterUserId(
                target.id(),
                fixture.requester().id()
        ).orElseThrow();

        assertThat(result.previewPhoto()).isNull();
    }

    @Test
    void shouldAssignOwnPreviewsForMultipleMemories() {

        Fixture fixture = authorizedFixture(StoryRole.CO_OWNER);
        Memory first = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        Memory second = saveMemory(memory(
                SECOND_MEMORY_ID,
                fixture.story().id(),
                fixture.owner().id(),
                "Second",
                null,
                null,
                52.520008,
                13.404954,
                LocalDate.of(2024, 5, 19),
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)
        ));
        saveMediaFile(MEDIA_ID, first.id(), BASE_TIME, MediaType.PHOTO);
        saveMediaFile(SECOND_MEDIA_ID, second.id(), BASE_TIME, MediaType.PHOTO);

        List<MemoryReadModel> result = repository
                .findByStoryIdAndRequesterUserId(
                        fixture.story().id(),
                        fixture.requester().id()
                )
                .orElseThrow()
                .memories();

        assertThat(result)
                .extracting(memory -> memory.memory().id())
                .containsExactlyInAnyOrder(first.id(), second.id());
        assertThat(previewFor(result, first.id()))
                .isEqualTo(new MemoryPreviewPhoto(MEDIA_ID));
        assertThat(previewFor(result, second.id()))
                .isEqualTo(new MemoryPreviewPhoto(SECOND_MEDIA_ID));
    }

    @Test
    void shouldIgnoreNonPhotoMediaForPreview() {

        Fixture fixture = authorizedFixture(StoryRole.VIEWER);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME, MediaType.VIDEO);
        saveMediaFile(SECOND_MEDIA_ID, memory.id(), BASE_TIME, MediaType.PHOTO);

        MemoryReadModel result = repository.findByIdAndRequesterUserId(
                memory.id(),
                fixture.requester().id()
        ).orElseThrow();

        assertThat(result.previewPhoto())
                .isEqualTo(new MemoryPreviewPhoto(SECOND_MEDIA_ID));
    }

    @Test
    void shouldNotExposeStorageProviderDataInReadModel() {

        Fixture fixture = authorizedFixture(StoryRole.OWNER);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));
        saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME, MediaType.PHOTO);

        String value = repository.findByIdAndRequesterUserId(
                memory.id(),
                fixture.requester().id()
        ).orElseThrow().toString();

        assertThat(value)
                .doesNotContain("display-key")
                .doesNotContain("thumbnail-key")
                .doesNotContain("storage")
                .doesNotContain("MinIO")
                .doesNotContain(MEDIA_ID.toString());
    }

    @Test
    void shouldNotDependOnMediaFileRepositoryForPreviewLookup() {

        Constructor<?>[] constructors =
                JdbcMemoryReadRepository.class.getDeclaredConstructors();

        assertThat(constructors).hasSize(1);
        assertThat(constructors[0].getParameterTypes())
                .containsExactly(JdbcClient.class);
    }

    @Test
    void shouldFindMemoryByIdForAuthorizedParticipant() {

        Fixture fixture = authorizedFixture(StoryRole.EDITOR);
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

        Optional<MemoryReadModel> result = repository
                .findByIdAndRequesterUserId(
                        memory.id(),
                        fixture.requester().id()
                );

        assertThat(result).isPresent();
        assertMemoryMatches(result.orElseThrow().memory(), memory);
        assertThat(result.orElseThrow().previewPhoto()).isNull();
        assertThat(result.orElseThrow().memory().description()).isNull();
        assertThat(result.orElseThrow().memory().placeName()).isNull();
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldFindMemoryByIdForEveryParticipantRole(StoryRole role) {

        Fixture fixture = authorizedFixture(role);
        Memory memory = saveMemory(defaultMemory(
                fixture.story().id(),
                fixture.owner().id()
        ));

        Optional<MemoryReadModel> result = repository
                .findByIdAndRequesterUserId(
                        memory.id(),
                        fixture.requester().id()
                );

        assertThat(result).isPresent();
        assertThat(result.orElseThrow().memory()).isEqualTo(memory);
    }

    @Test
    void shouldReturnEmptyForMissingOrInaccessibleMemory() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User requester = saveUser(REQUESTER_ID, "requester-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        assertThat(repository.findByIdAndRequesterUserId(
                UUID.randomUUID(),
                requester.id()
        )).isEmpty();
        assertThat(repository.findByIdAndRequesterUserId(
                memory.id(),
                requester.id()
        )).isEmpty();
    }

    @Test
    void shouldDenyOwnerWithoutMembershipForGet() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(defaultMemory(story.id(), owner.id()));

        Optional<MemoryReadModel> result = repository
                .findByIdAndRequesterUserId(
                        memory.id(),
                        owner.id()
                );

        assertThat(result).isEmpty();
    }

    @Test
    void shouldDenyFormerAuthorWithoutMembershipForGet() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User formerAuthor =
                saveUser(REQUESTER_ID, "former-author-google-subject");
        Story story = saveStory(STORY_ID, owner.id());
        Memory memory = saveMemory(defaultMemory(
                story.id(),
                formerAuthor.id()
        ));

        Optional<MemoryReadModel> result = repository
                .findByIdAndRequesterUserId(
                        memory.id(),
                        formerAuthor.id()
                );

        assertThat(result).isEmpty();
    }

    @Test
    void shouldRejectNullInputs() {

        assertThatThrownBy(() -> repository.findByStoryIdAndRequesterUserId(
                null,
                REQUESTER_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
        assertThatThrownBy(() -> repository.findByStoryIdAndRequesterUserId(
                STORY_ID,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("requesterUserId must not be null");
        assertThatThrownBy(() -> repository.findByIdAndRequesterUserId(
                null,
                REQUESTER_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");
        assertThatThrownBy(() -> repository.findByIdAndRequesterUserId(
                MEMORY_ID,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("requesterUserId must not be null");
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

    private MediaFile saveMediaFile(
            UUID id,
            UUID memoryId,
            Instant createdAt,
            MediaType type
    ) {
        MediaFile mediaFile = new MediaFile(
                id,
                memoryId,
                type,
                "display-key-" + id,
                1_024L,
                "thumbnail-key-" + id,
                128L,
                "image/jpeg",
                createdAt
        );
        mediaFileRepository.save(mediaFile);

        return mediaFile;
    }

    private static MemoryPreviewPhoto previewFor(
            List<MemoryReadModel> memories,
            UUID memoryId
    ) {
        return memories.stream()
                .filter(memory -> memory.memory().id().equals(memoryId))
                .findFirst()
                .orElseThrow()
                .previewPhoto();
    }

    private static Memory defaultMemory(UUID storyId, UUID createdBy) {
        return memory(
                MEMORY_ID,
                storyId,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2025, 5, 20),
                BASE_TIME,
                BASE_TIME.plusSeconds(1)
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
