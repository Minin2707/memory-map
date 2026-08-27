package memory_map.backend.media.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.media.application.MediaDownloadReadModel;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
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
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcAuthorizedMediaDownloadRepositoryTest extends IntegrationTest {

    @Autowired
    private AuthorizedMediaDownloadRepository repository;

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

    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
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

    @Test
    void shouldFindAuthorizedMediaDownloadForParticipant() {
        User owner = saveUser("owner");
        Story story = saveStory(owner);
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(story, owner);
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());

        Optional<MediaDownloadReadModel> result =
                repository.findAuthorizedDownload(mediaFile.id(), owner.id());

        assertThat(result).contains(new MediaDownloadReadModel(
                mediaFile.displayStorageKey(),
                mediaFile.displayFileSize(),
                mediaFile.thumbnailStorageKey(),
                mediaFile.thumbnailFileSize(),
                mediaFile.mimeType()
        ));
    }

    @ParameterizedTest
    @EnumSource(StoryRole.class)
    void shouldAllowEveryStoryParticipantRoleToReadMedia(StoryRole role) {
        User owner = saveUser("owner");
        User requester = role == StoryRole.OWNER
                ? owner
                : saveUser("requester");
        Story story = saveStory(owner);
        saveParticipant(story.id(), requester.id(), role);
        Memory memory = saveMemory(story, owner);
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());

        Optional<MediaDownloadReadModel> result =
                repository.findAuthorizedDownload(
                        mediaFile.id(),
                        requester.id()
                );

        assertThat(result).isPresent();
    }

    @Test
    void shouldReturnEmptyForNonParticipant() {
        User owner = saveUser("owner");
        User outsider = saveUser("outsider");
        Story story = saveStory(owner);
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(story, owner);
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());

        Optional<MediaDownloadReadModel> result =
                repository.findAuthorizedDownload(
                        mediaFile.id(),
                        outsider.id()
                );

        assertThat(result).isEmpty();
    }

    @Test
    void shouldReturnEmptyForMissingMedia() {
        User owner = saveUser("owner");

        Optional<MediaDownloadReadModel> result =
                repository.findAuthorizedDownload(UUID.randomUUID(), owner.id());

        assertThat(result).isEmpty();
    }

    @Test
    void shouldRejectNullInputs() {
        User owner = saveUser("owner");

        assertThatThrownBy(() ->
                repository.findAuthorizedDownload(null, owner.id())
        ).isInstanceOf(NullPointerException.class)
                .hasMessage("mediaId must not be null");
        assertThatThrownBy(() ->
                repository.findAuthorizedDownload(MEDIA_ID, null)
        ).isInstanceOf(NullPointerException.class)
                .hasMessage("requesterUserId must not be null");
    }

    private User saveUser(String googleSubject) {
        return userRepository.save(new User(
                UUID.randomUUID(),
                "google-subject-" + googleSubject,
                "Memory Map User",
                null,
                BASE_TIME,
                BASE_TIME
        ));
    }

    private Story saveStory(User owner) {
        return storyRepository.save(new Story(
                UUID.randomUUID(),
                owner.id(),
                "Our Story",
                "The beginning",
                null,
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

    private Memory saveMemory(Story story, User createdBy) {
        Memory memory = new Memory(
                UUID.randomUUID(),
                story.id(),
                createdBy.id(),
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2024, 5, 20),
                BASE_TIME,
                BASE_TIME
        );
        memoryRepository.save(memory);

        return memory;
    }

    private MediaFile saveMediaFile(UUID id, UUID memoryId) {
        MediaFile mediaFile = new MediaFile(
                id,
                memoryId,
                MediaType.PHOTO,
                "private-media-storage/" + id + "/display",
                4L,
                "private-media-storage/" + id + "/thumbnail",
                2L,
                "image/jpeg",
                BASE_TIME
        );
        mediaFileRepository.save(mediaFile);

        return mediaFile;
    }
}
