package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultDownloadStoryParticipantAvatarServiceTest {

    private static final UUID REQUESTER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID PARTICIPANT_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final byte[] AVATAR_BYTES = new byte[] {1, 2, 3};

    private final FakeUserRepository userRepository =
            new FakeUserRepository();
    private final FakeStoryParticipantRepository storyParticipantRepository =
            new FakeStoryParticipantRepository();
    private final FakeStorageService storageService =
            new FakeStorageService();
    private final DefaultDownloadStoryParticipantAvatarService service =
            new DefaultDownloadStoryParticipantAvatarService(
                    userRepository,
                    storyParticipantRepository,
                    storageService,
                    new StoryAccessPolicy()
            );

    @Test
    void shouldDownloadStoryParticipantCustomAvatar() throws Exception {
        DownloadedStoryParticipantAvatar result = service.downloadAvatar(
                authenticatedUser(),
                STORY_ID,
                PARTICIPANT_ID
        );

        assertThat(result.content().readAllBytes())
                .containsExactly(AVATAR_BYTES);
        assertThat(result.contentLength()).isEqualTo(AVATAR_BYTES.length);
        assertThat(result.contentType()).isEqualTo("image/jpeg");
        assertThat(storageService.requestedKey)
                .isEqualTo(new StorageKey("users/participant/avatar"));
        assertThat(storyParticipantRepository.findCalls).isEqualTo(2);
        assertThat(userRepository.requestedId).isEqualTo(PARTICIPANT_ID);
    }

    @Test
    void shouldConcealAvatarWhenRequesterIsNotStoryParticipant() {
        storyParticipantRepository.participants = Map.of(
                PARTICIPANT_ID,
                participant(PARTICIPANT_ID, StoryRole.VIEWER)
        );

        assertThatThrownBy(() -> service.downloadAvatar(
                authenticatedUser(),
                STORY_ID,
                PARTICIPANT_ID
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(storageService.readCalls).isZero();
    }

    @Test
    void shouldConcealAvatarWhenTargetIsNotStoryParticipant() {
        storyParticipantRepository.participants = Map.of(
                REQUESTER_ID,
                participant(REQUESTER_ID, StoryRole.OWNER)
        );

        assertThatThrownBy(() -> service.downloadAvatar(
                authenticatedUser(),
                STORY_ID,
                PARTICIPANT_ID
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(storageService.readCalls).isZero();
        assertThat(userRepository.requestedId).isNull();
    }

    @Test
    void shouldReturnNotFoundWhenTargetHasNoCustomAvatar() {
        userRepository.user = Optional.of(new User(
                PARTICIPANT_ID,
                "participant-google-subject",
                "Participant User",
                "https://example.com/google.png",
                CURRENT_TIME,
                CURRENT_TIME
        ));

        assertThatThrownBy(() -> service.downloadAvatar(
                authenticatedUser(),
                STORY_ID,
                PARTICIPANT_ID
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(storageService.readCalls).isZero();
    }

    @Test
    void shouldReturnNotFoundWhenTargetUserIsDeleted() {
        userRepository.user = Optional.of(new User(
                PARTICIPANT_ID,
                "participant-google-subject",
                "Deleted User",
                "https://example.com/google.png",
                "users/participant/avatar",
                CURRENT_TIME,
                CURRENT_TIME,
                CURRENT_TIME,
                CURRENT_TIME
        ));

        assertThatThrownBy(() -> service.downloadAvatar(
                authenticatedUser(),
                STORY_ID,
                PARTICIPANT_ID
        )).isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");

        assertThat(storageService.readCalls).isZero();
    }

    @Test
    void shouldRejectNullDependenciesAndInputs() {
        assertThatThrownBy(() -> new DefaultDownloadStoryParticipantAvatarService(
                null,
                storyParticipantRepository,
                storageService,
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("userRepository must not be null");
        assertThatThrownBy(() -> new DefaultDownloadStoryParticipantAvatarService(
                userRepository,
                null,
                storageService,
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
        assertThatThrownBy(() -> new DefaultDownloadStoryParticipantAvatarService(
                userRepository,
                storyParticipantRepository,
                null,
                new StoryAccessPolicy()
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageService must not be null");
        assertThatThrownBy(() -> new DefaultDownloadStoryParticipantAvatarService(
                userRepository,
                storyParticipantRepository,
                storageService,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("accessPolicy must not be null");
        assertThatThrownBy(() -> service.downloadAvatar(
                null,
                STORY_ID,
                PARTICIPANT_ID
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
        assertThatThrownBy(() -> service.downloadAvatar(
                authenticatedUser(),
                null,
                PARTICIPANT_ID
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
        assertThatThrownBy(() -> service.downloadAvatar(
                authenticatedUser(),
                STORY_ID,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("participantUserId must not be null");
    }

    private static AuthenticatedUser authenticatedUser() {
        return new AuthenticatedUser(REQUESTER_ID);
    }

    private static StoryParticipant participant(UUID userId, StoryRole role) {
        return new StoryParticipant(STORY_ID, userId, role, CURRENT_TIME);
    }

    private static final class FakeUserRepository implements UserRepository {

        private Optional<User> user = Optional.of(new User(
                PARTICIPANT_ID,
                "participant-google-subject",
                "Participant User",
                "https://example.com/google.png",
                "users/participant/avatar",
                CURRENT_TIME,
                CURRENT_TIME,
                CURRENT_TIME,
                null
        ));
        private UUID requestedId;

        @Override
        public User save(User user) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<User> findById(UUID id) {
            requestedId = id;
            return user;
        }

        @Override
        public Optional<User> findByGoogleSubject(String googleSubject) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private Map<UUID, StoryParticipant> participants = Map.of(
                REQUESTER_ID,
                participant(REQUESTER_ID, StoryRole.OWNER),
                PARTICIPANT_ID,
                participant(PARTICIPANT_ID, StoryRole.VIEWER)
        );
        private int findCalls;

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            findCalls++;
            if (!STORY_ID.equals(storyId)) {
                return Optional.empty();
            }

            return Optional.ofNullable(participants.get(userId));
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public long countOwners(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void update(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }
    }

    private static final class FakeStorageService implements StorageService {

        private StorageKey requestedKey;
        private int readCalls;

        @Override
        public void store(StorageObjectWrite object) {
            throw new UnsupportedOperationException();
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            requestedKey = storageKey;
            readCalls++;
            return new StoredObject(
                    new ByteArrayInputStream(AVATAR_BYTES),
                    AVATAR_BYTES.length,
                    "image/jpeg"
            );
        }

        @Override
        public StoredObject readRange(
                StorageKey storageKey,
                StorageByteRange range
        ) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(StorageKey storageKey) {
            throw new UnsupportedOperationException();
        }
    }
}
