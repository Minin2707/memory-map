package memory_map.backend.story.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.story.application.StoryPhotoPreview;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
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
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcUserStoryRepositoryTest extends IntegrationTest {

    @Autowired
    private UserStoryRepository repository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoryRepository storyRepository;

    @Autowired
    private StoryParticipantRepository storyParticipantRepository;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private MediaFileRepository mediaFileRepository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID THIRD_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID SECOND_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final UUID THIRD_MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000023");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final UUID THIRD_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000033");
    private static final UUID FOURTH_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000034");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final LocalDate BASE_DATE =
            LocalDate.parse("2026-01-01");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldFindUserStoryWhenMembershipMatches() {

        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                user.id(),
                "Our Story",
                "The beginning"
        );
        saveParticipant(story.id(), user.id(), StoryRole.OWNER);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found)
                .contains(new UserStory(story, StoryRole.OWNER));
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldFindUserStoryForEveryRole(StoryRole role) {

        User owner = saveUser(OTHER_USER_ID, "owner-google-subject");
        User user = role == StoryRole.OWNER
                ? owner
                : saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Role Story",
                "The beginning"
        );
        saveParticipant(story.id(), user.id(), role);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found)
                .contains(new UserStory(story, role));
    }

    @Test
    void shouldReturnEmptyWhenStoryDoesNotExist() {

        User user = saveUser(USER_ID, "current-google-subject");

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(STORY_ID, user.id());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldReturnEmptyWhenStoryExistsWithoutMembership() {

        User owner = saveUser(OTHER_USER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Private Story",
                "The beginning"
        );

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldReturnEmptyWhenMembershipBelongsToAnotherUser() {

        User owner = saveUser(OTHER_USER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                "Other Membership Story",
                "The beginning"
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldUseExactStoryAndUserPair() {

        User user = saveUser(USER_ID, "current-google-subject");
        User otherUser = saveUser(OTHER_USER_ID, "other-google-subject");
        Story story = saveStory(
                STORY_ID,
                user.id(),
                "Current Story",
                "The beginning"
        );
        Story otherStory = saveStory(
                OTHER_STORY_ID,
                otherUser.id(),
                "Other Story",
                "The beginning"
        );
        saveParticipant(story.id(), user.id(), StoryRole.EDITOR);
        saveParticipant(otherStory.id(), otherUser.id(), StoryRole.VIEWER);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());
        Optional<UserStory> crossed =
                repository.findByStoryIdAndUserId(
                        story.id(),
                        otherUser.id()
                );

        assertThat(found)
                .contains(new UserStory(story, StoryRole.EDITOR));
        assertThat(crossed).isEmpty();
    }

    @Test
    void shouldMapNullableDescription() {

        User user = saveUser(USER_ID, "current-google-subject");
        Story story = saveStory(
                STORY_ID,
                user.id(),
                "Nullable Description Story",
                null
        );
        saveParticipant(story.id(), user.id(), StoryRole.VIEWER);

        Optional<UserStory> found =
                repository.findByStoryIdAndUserId(story.id(), user.id());

        assertThat(found)
                .contains(new UserStory(story, StoryRole.VIEWER));
        assertThat(found.orElseThrow().story().description()).isNull();
    }

    @Test
    void shouldReturnCountsForStoryProjection() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        User coOwner = saveUser(OTHER_USER_ID, "co-owner-google-subject");
        User editor = saveUser(THIRD_USER_ID, "editor-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Count Story", null);
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);
        saveParticipant(story.id(), editor.id(), StoryRole.EDITOR);
        saveMemory(MEMORY_ID, story.id(), owner.id(), BASE_DATE, BASE_TIME);
        saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE.plusDays(1),
                BASE_TIME.plusSeconds(1)
        );

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.memoryCount()).isEqualTo(2);
        assertThat(found.participantCount()).isEqualTo(3);
        assertThat(found.previewPhoto()).isNull();
    }

    @Test
    void shouldReturnOwnerOnlyParticipantCountAsOne() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Owner Story", null);
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.participantCount()).isEqualTo(1);
    }

    @Test
    void shouldAvoidMultiplicativeCountInflation() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        User coOwner = saveUser(OTHER_USER_ID, "co-owner-google-subject");
        User editor = saveUser(THIRD_USER_ID, "editor-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Inflation Story", null);
        Memory firstMemory = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        Memory secondMemory = saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE.plusDays(1),
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);
        saveParticipant(story.id(), editor.id(), StoryRole.EDITOR);
        saveMedia(MEDIA_ID, firstMemory.id(), MediaType.PHOTO, BASE_TIME);
        saveMedia(
                SECOND_MEDIA_ID,
                firstMemory.id(),
                MediaType.PHOTO,
                BASE_TIME.plusSeconds(1)
        );
        saveMedia(
                THIRD_MEDIA_ID,
                secondMemory.id(),
                MediaType.PHOTO,
                BASE_TIME.plusSeconds(2)
        );

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.memoryCount()).isEqualTo(2);
        assertThat(found.participantCount()).isEqualTo(3);
    }

    @Test
    void shouldSelectNewestMemoryWithPhotoAndSkipNewestMemoryWithoutPhoto() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Preview Story", null);
        Memory olderWithPhoto = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE.plusDays(1),
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveMedia(MEDIA_ID, olderWithPhoto.id(), MediaType.PHOTO, BASE_TIME);

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.previewPhoto())
                .isEqualTo(new StoryPhotoPreview(MEDIA_ID));
    }

    @Test
    void shouldSelectEarliestPhotoInsideSelectedNewestEligibleMemory() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Photo Story", null);
        Memory older = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        Memory newest = saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE.plusDays(1),
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveMedia(MEDIA_ID, older.id(), MediaType.PHOTO, BASE_TIME);
        saveMedia(
                THIRD_MEDIA_ID,
                newest.id(),
                MediaType.PHOTO,
                BASE_TIME.plusSeconds(4)
        );
        saveMedia(
                SECOND_MEDIA_ID,
                newest.id(),
                MediaType.PHOTO,
                BASE_TIME.plusSeconds(3)
        );

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.previewPhoto())
                .isEqualTo(new StoryPhotoPreview(SECOND_MEDIA_ID));
    }

    @Test
    void shouldUseMediaIdAsTieBreakerForPhotosWithSameCreatedAt() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Tie Story", null);
        Memory memory = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveMedia(SECOND_MEDIA_ID, memory.id(), MediaType.PHOTO, BASE_TIME);
        saveMedia(MEDIA_ID, memory.id(), MediaType.PHOTO, BASE_TIME);

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.previewPhoto())
                .isEqualTo(new StoryPhotoPreview(MEDIA_ID));
    }

    @Test
    void shouldUseMemoryCreatedAtAndIdAsTieBreakersForSameEventDate() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Memory Tie Story", null);
        Memory earlierCreated = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        Memory laterCreated = saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveMedia(MEDIA_ID, earlierCreated.id(), MediaType.PHOTO, BASE_TIME);
        saveMedia(
                SECOND_MEDIA_ID,
                laterCreated.id(),
                MediaType.PHOTO,
                BASE_TIME
        );

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.previewPhoto())
                .isEqualTo(new StoryPhotoPreview(SECOND_MEDIA_ID));
    }

    @Test
    void shouldUseMemoryIdAsFinalTieBreaker() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Id Tie Story", null);
        Memory lowerId = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        Memory higherId = saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveMedia(MEDIA_ID, lowerId.id(), MediaType.PHOTO, BASE_TIME);
        saveMedia(
                SECOND_MEDIA_ID,
                higherId.id(),
                MediaType.PHOTO,
                BASE_TIME
        );

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.previewPhoto())
                .isEqualTo(new StoryPhotoPreview(SECOND_MEDIA_ID));
    }

    @Test
    void shouldIgnoreNonPhotoMediaAndMediaFromOtherStories() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Current Story", null);
        Story otherStory =
                saveStory(OTHER_STORY_ID, owner.id(), "Other Story", null);
        Memory memory = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        Memory otherMemory = saveMemory(
                SECOND_MEMORY_ID,
                otherStory.id(),
                owner.id(),
                BASE_DATE.plusDays(1),
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(otherStory.id(), owner.id(), StoryRole.OWNER);
        saveMedia(MEDIA_ID, memory.id(), MediaType.VOICE, BASE_TIME);
        saveMedia(
                SECOND_MEDIA_ID,
                otherMemory.id(),
                MediaType.PHOTO,
                BASE_TIME
        );

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.previewPhoto()).isNull();
    }

    @Test
    void shouldNotLetRecentlyUploadedPhotoOnOlderMemoryBeatNewerMemory() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Chronology Story", null);
        Memory olderMemory = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        Memory newerMemory = saveMemory(
                SECOND_MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE.plusDays(1),
                BASE_TIME.plusSeconds(1)
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveMedia(
                MEDIA_ID,
                olderMemory.id(),
                MediaType.PHOTO,
                BASE_TIME.plusSeconds(10)
        );
        saveMedia(
                SECOND_MEDIA_ID,
                newerMemory.id(),
                MediaType.PHOTO,
                BASE_TIME.plusSeconds(2)
        );

        UserStory found = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(found.previewPhoto())
                .isEqualTo(new StoryPhotoPreview(SECOND_MEDIA_ID));
    }

    @Test
    void shouldReturnConsistentProjectionForListAndSingleStory() {

        User owner = saveUser(USER_ID, "owner-google-subject");
        User coOwner = saveUser(OTHER_USER_ID, "co-owner-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), "Consistent Story", null);
        Memory memory = saveMemory(
                MEMORY_ID,
                story.id(),
                owner.id(),
                BASE_DATE,
                BASE_TIME
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), coOwner.id(), StoryRole.CO_OWNER);
        saveMedia(MEDIA_ID, memory.id(), MediaType.PHOTO, BASE_TIME);

        UserStory listItem = repository.findByUserId(owner.id()).get(0);
        UserStory singleItem = repository
                .findByStoryIdAndUserId(story.id(), owner.id())
                .orElseThrow();

        assertThat(listItem).isEqualTo(singleItem);
        assertThat(listItem.role()).isEqualTo(StoryRole.OWNER);
        assertThat(listItem.memoryCount()).isEqualTo(1);
        assertThat(listItem.participantCount()).isEqualTo(2);
        assertThat(listItem.previewPhoto())
                .isEqualTo(new StoryPhotoPreview(MEDIA_ID));
    }

    @Test
    void shouldPreserveStoryListOrdering() {

        User user = saveUser(USER_ID, "current-google-subject");
        Story first = saveStory(STORY_ID, user.id(), "First Story", null);
        Story second =
                saveStory(OTHER_STORY_ID, user.id(), "Second Story", null);
        saveParticipant(
                second.id(),
                user.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(2)
        );
        saveParticipant(
                first.id(),
                user.id(),
                StoryRole.OWNER,
                BASE_TIME.plusSeconds(1)
        );
        Memory latestMemory = saveMemory(
                MEMORY_ID,
                second.id(),
                user.id(),
                BASE_DATE.plusDays(10),
                BASE_TIME.plusSeconds(10)
        );
        saveMedia(MEDIA_ID, latestMemory.id(), MediaType.PHOTO, BASE_TIME);

        List<UserStory> found = repository.findByUserId(user.id());

        assertThat(found)
                .extracting(userStory -> userStory.story().id())
                .containsExactly(first.id(), second.id());
    }

    @Test
    void shouldRejectNullUserIdForListLookup() {

        assertThatThrownBy(() -> repository.findByUserId(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userId must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> repository.findByStoryIdAndUserId(
                null,
                USER_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldRejectNullUserId() {

        assertThatThrownBy(() -> repository.findByStoryIdAndUserId(
                STORY_ID,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userId must not be null");
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
        saveParticipant(storyId, userId, role, BASE_TIME);
    }

    private void saveParticipant(
            UUID storyId,
            UUID userId,
            StoryRole role,
            Instant joinedAt
    ) {
        storyParticipantRepository.save(
                new StoryParticipant(
                        storyId,
                        userId,
                        role,
                        joinedAt
                )
        );
    }

    private Memory saveMemory(
            UUID memoryId,
            UUID storyId,
            UUID createdBy,
            LocalDate eventDate,
            Instant createdAt
    ) {
        Memory memory = new Memory(
                memoryId,
                storyId,
                createdBy,
                "Memory " + memoryId,
                null,
                null,
                55.7558,
                37.6173,
                eventDate,
                createdAt,
                createdAt
        );
        memoryRepository.save(memory);
        return memory;
    }

    private void saveMedia(
            UUID mediaId,
            UUID memoryId,
            MediaType type,
            Instant createdAt
    ) {
        mediaFileRepository.save(
                new MediaFile(
                        mediaId,
                        memoryId,
                        type,
                        "display-key-" + mediaId,
                        1_024L,
                        "thumbnail-key-" + mediaId,
                        128L,
                        type == MediaType.PHOTO ? "image/jpeg" : "audio/mpeg",
                        createdAt
                )
        );
    }
}
