package memory_map.backend.account.application;

import memory_map.backend.IntegrationTest;
import memory_map.backend.account.repository.AccountDeletionRepository;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
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
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Import(DeleteCurrentAccountUseCaseIntegrationTest
        .DeleteCurrentAccountTestConfiguration.class)
class DeleteCurrentAccountUseCaseIntegrationTest extends IntegrationTest {

    @Autowired
    private DeleteCurrentAccountUseCase deleteCurrentAccountUseCase;

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
    private InviteRepository inviteRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private UserStoryRepository userStoryRepository;

    @Autowired
    private AccountDeletionRepository accountDeletionRepository;

    @Autowired
    private TestStorageService storageService;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID CO_OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID EDITOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID VIEWER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000005");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID THIRD_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000013");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000041");
    private static final UUID REFRESH_TOKEN_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000051");
    private static final UUID MUSIC_TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000061");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-02-01T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users, music_tracks
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        storageService.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldTombstoneUserWithNoStoriesAndRevokeRefreshTokens() {

        User user = saveUser(USER_ID, "google-subject-123");
        userRepository.updateCustomAvatar(
                user.id(),
                "users/%s/avatar/avatar-object".formatted(user.id()),
                BASE_TIME
        );
        RefreshToken refreshToken = saveRefreshToken(user.id());

        deleteCurrentAccountUseCase.deleteCurrentAccount(command(user.id()));

        User tombstone = userRepository.findById(user.id()).orElseThrow();
        RefreshToken loadedToken =
                refreshTokenRepository.findById(refreshToken.id())
                        .orElseThrow();

        assertThat(tombstone.id()).isEqualTo(user.id());
        assertThat(tombstone.googleSubject()).isNull();
        assertThat(tombstone.displayName()).isEqualTo("Deleted user");
        assertThat(tombstone.avatarUrl()).isNull();
        assertThat(tombstone.customAvatarStorageKey()).isNull();
        assertThat(tombstone.customAvatarUpdatedAt()).isNull();
        assertThat(tombstone.deletedAt()).isEqualTo(CURRENT_TIME);
        assertThat(userRepository.existsActiveById(user.id())).isFalse();
        assertThat(loadedToken.revokedAt()).isEqualTo(CURRENT_TIME);
        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey(
                        "users/%s/avatar/avatar-object".formatted(user.id())
                )
        );
    }

    @Test
    void shouldDeleteSoleParticipantOwnedStoryGraphAndCleanupMediaAfterCommit() {

        User user = saveUser(USER_ID, "google-subject-123");
        UUID soundtrackId = saveMusicTrack();
        Story story = saveStory(STORY_ID, user.id(), soundtrackId);
        saveParticipant(story.id(), user.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), user.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());
        saveInvite(INVITE_ID, story.id(), user.id(), null);

        deleteCurrentAccountUseCase.deleteCurrentAccount(command(user.id()));

        assertThat(storyRepository.findById(story.id())).isEmpty();
        assertThat(memoryRepository.findById(memory.id())).isEmpty();
        assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
        assertThat(inviteRepository.findById(INVITE_ID)).isEmpty();
        assertThat(musicTrackCount(soundtrackId)).isEqualTo(1);
        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageKey(mediaFile.displayStorageKey())
        );
    }

    @Test
    void shouldFindStoryCoverStorageKeysOnlyForRequestedStories() {

        User user = saveUser(USER_ID, "google-subject-123");
        Story storyWithCover = saveStory(
                STORY_ID,
                user.id(),
                null,
                coverMetadata(STORY_ID, "cover-a")
        );
        Story storyWithoutCover = saveStory(OTHER_STORY_ID, user.id(), null);
        StoryCoverMetadata unrelatedCover =
                coverMetadata(THIRD_STORY_ID, "cover-c");
        saveStory(
                THIRD_STORY_ID,
                user.id(),
                null,
                unrelatedCover
        );

        List<String> storageKeys = accountDeletionRepository
                .findStoryCoverStorageKeysByStoryIds(List.of(
                        storyWithCover.id(),
                        storyWithoutCover.id()
                ));

        assertThat(storageKeys).containsExactly(
                storyWithCover.cover().thumbnailStorageKey(),
                storyWithCover.cover().displayStorageKey()
        );
        assertThat(storageKeys)
                .doesNotContain(unrelatedCover.thumbnailStorageKey())
                .doesNotContain(unrelatedCover.displayStorageKey());
        assertThat(accountDeletionRepository
                .findStoryCoverStorageKeysByStoryIds(List.of()))
                .isEmpty();
    }

    @Test
    void shouldCleanupOnlyCoversForPhysicallyDeletedStoriesAfterCommit() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(CO_OWNER_ID, "co-owner-google-subject");
        Story deletedWithCover = saveStory(
                STORY_ID,
                owner.id(),
                null,
                coverMetadata(STORY_ID, "deleted-cover")
        );
        Story deletedWithoutCover = saveStory(
                OTHER_STORY_ID,
                owner.id(),
                null
        );
        Story survivingWithCover = saveStory(
                THIRD_STORY_ID,
                owner.id(),
                null,
                coverMetadata(THIRD_STORY_ID, "surviving-cover")
        );
        saveParticipant(deletedWithCover.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(deletedWithoutCover.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(survivingWithCover.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(
                survivingWithCover.id(),
                coOwner.id(),
                StoryRole.CO_OWNER
        );

        deleteCurrentAccountUseCase.deleteCurrentAccount(command(owner.id()));

        assertThat(storyRepository.findById(deletedWithCover.id())).isEmpty();
        assertThat(storyRepository.findById(deletedWithoutCover.id()))
                .isEmpty();
        Story transferred = storyRepository.findById(survivingWithCover.id())
                .orElseThrow();

        assertThat(transferred.ownerId()).isEqualTo(coOwner.id());
        assertThat(transferred.cover()).isEqualTo(survivingWithCover.cover());
        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey(deletedWithCover.cover().thumbnailStorageKey()),
                new StorageKey(deletedWithCover.cover().displayStorageKey())
        );
    }

    @Test
    void shouldTransferOwnedStoryToEarliestCoOwnerAndPreserveStoryData() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User laterCoOwner = saveUser(USER_ID, "later-google-subject");
        User earliestCoOwner = saveUser(CO_OWNER_ID, "co-owner-google-subject");
        UUID soundtrackId = saveMusicTrack();
        Story story = saveStory(
                STORY_ID,
                owner.id(),
                soundtrackId,
                coverMetadata(STORY_ID, "surviving-cover")
        );
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER, BASE_TIME);
        saveParticipant(
                story.id(),
                laterCoOwner.id(),
                StoryRole.CO_OWNER,
                BASE_TIME.plusSeconds(20)
        );
        saveParticipant(
                story.id(),
                earliestCoOwner.id(),
                StoryRole.CO_OWNER,
                BASE_TIME.plusSeconds(10)
        );
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id());

        deleteCurrentAccountUseCase.deleteCurrentAccount(command(owner.id()));

        Story transferred = storyRepository.findById(story.id()).orElseThrow();

        assertThat(transferred.ownerId()).isEqualTo(earliestCoOwner.id());
        assertThat(storyParticipantRepository.find(
                story.id(),
                earliestCoOwner.id()
        ).orElseThrow().role()).isEqualTo(StoryRole.OWNER);
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .isEmpty();
        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
        assertThat(mediaFileRepository.findById(mediaFile.id()))
                .contains(mediaFile);
        assertThat(transferred.soundtrackId()).isEqualTo(soundtrackId);
        assertThat(transferred.cover()).isEqualTo(story.cover());
        assertThat(storageService.deletedKeys).isEmpty();
        assertThat(userStoryRepository.findByUserId(owner.id())).isEmpty();
    }

    @Test
    void shouldBlockOwnerDeletionWhenSharedStoryHasOnlyEditor() {

        assertOwnerDeletionBlockedForRole(StoryRole.EDITOR);
    }

    @Test
    void shouldBlockOwnerDeletionWhenSharedStoryHasOnlyViewer() {

        assertOwnerDeletionBlockedForRole(StoryRole.VIEWER);
    }

    @Test
    void shouldRemoveCoOwnerParticipationAndPreserveAuthoredMemories() {

        assertNonOwnerDeletionPreservesStoryAndMemory(StoryRole.CO_OWNER);
    }

    @Test
    void shouldRemoveEditorParticipationAndPreserveAuthoredMemories() {

        assertNonOwnerDeletionPreservesStoryAndMemory(StoryRole.EDITOR);
    }

    @Test
    void shouldRemoveViewerParticipationAndPreserveAuthoredMemories() {

        assertNonOwnerDeletionPreservesStoryAndMemory(StoryRole.VIEWER);
    }

    @Test
    void shouldDeleteUnusedInvitesCreatedByDeletedUserForSurvivingStories() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User user = saveUser(USER_ID, "google-subject-123");
        Story story = saveStory(STORY_ID, owner.id(), null);
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), user.id(), StoryRole.EDITOR);
        saveInvite(INVITE_ID, story.id(), user.id(), null);

        deleteCurrentAccountUseCase.deleteCurrentAccount(command(user.id()));

        assertThat(inviteRepository.findById(INVITE_ID)).isEmpty();
        assertThat(storyRepository.findById(story.id())).contains(story);
    }

    @Test
    void shouldRejectDuplicateDeletionAfterAccountIsTombstoned() {

        User user = saveUser(USER_ID, "google-subject-123");

        deleteCurrentAccountUseCase.deleteCurrentAccount(command(user.id()));

        assertThatThrownBy(() -> deleteCurrentAccountUseCase
                .deleteCurrentAccount(command(user.id())))
                .isInstanceOf(AccountDeletionUnavailableException.class);
        assertThat(userRepository.findById(user.id())
                .orElseThrow()
                .deletedAt())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldNotPartiallyMutateWhenAnyOwnedStoryBlocksDeletion() {

        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User coOwner = saveUser(CO_OWNER_ID, "co-owner-google-subject");
        User editor = saveUser(EDITOR_ID, "editor-google-subject");
        Story transferable = saveStory(
                STORY_ID,
                owner.id(),
                null,
                coverMetadata(STORY_ID, "transferable-cover")
        );
        Story blocked = saveStory(
                OTHER_STORY_ID,
                owner.id(),
                null,
                coverMetadata(OTHER_STORY_ID, "blocked-cover")
        );
        saveParticipant(transferable.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(transferable.id(), coOwner.id(), StoryRole.CO_OWNER);
        saveParticipant(blocked.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(blocked.id(), editor.id(), StoryRole.EDITOR);
        RefreshToken refreshToken = saveRefreshToken(owner.id());

        assertThatThrownBy(() -> deleteCurrentAccountUseCase
                .deleteCurrentAccount(command(owner.id())))
                .isInstanceOf(AccountDeletionOwnershipConflictException.class);

        assertThat(storyRepository.findById(transferable.id())
                .orElseThrow()
                .ownerId())
                .isEqualTo(owner.id());
        assertThat(storyParticipantRepository.find(
                transferable.id(),
                owner.id()
        )).isPresent();
        assertThat(userRepository.findById(owner.id())
                .orElseThrow()
                .deletedAt())
                .isNull();
        assertThat(refreshTokenRepository.findById(refreshToken.id())
                .orElseThrow()
                .revokedAt())
                .isNull();
        assertThat(storyRepository.findById(transferable.id())
                .orElseThrow()
                .cover())
                .isEqualTo(transferable.cover());
        assertThat(storyRepository.findById(blocked.id())
                .orElseThrow()
                .cover())
                .isEqualTo(blocked.cover());
        assertThat(storageService.deletedKeys).isEmpty();
    }

    private void assertOwnerDeletionBlockedForRole(StoryRole otherRole) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User other = saveUser(USER_ID, "other-google-subject");
        Story story = saveStory(STORY_ID, owner.id(), null);
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), other.id(), otherRole);

        assertThatThrownBy(() -> deleteCurrentAccountUseCase
                .deleteCurrentAccount(command(owner.id())))
                .isInstanceOf(AccountDeletionOwnershipConflictException.class)
                .hasMessage(
                        "Transfer ownership of shared stories before deleting your profile."
                );

        assertThat(storyRepository.findById(story.id())).contains(story);
        assertThat(storyParticipantRepository.find(story.id(), owner.id()))
                .isPresent();
        assertThat(userRepository.findById(owner.id()).orElseThrow()
                .deletedAt())
                .isNull();
        assertThat(storageService.deletedKeys).isEmpty();
    }

    private void assertNonOwnerDeletionPreservesStoryAndMemory(
            StoryRole deletingUserRole
    ) {
        User owner = saveUser(OWNER_ID, "owner-google-subject");
        User deletingUser = saveUser(USER_ID, "google-subject-123");
        Story story = saveStory(STORY_ID, owner.id(), null);
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        saveParticipant(story.id(), deletingUser.id(), deletingUserRole);
        Memory memory = saveMemory(
                MEMORY_ID,
                story.id(),
                deletingUser.id()
        );

        deleteCurrentAccountUseCase.deleteCurrentAccount(
                command(deletingUser.id())
        );

        assertThat(storyRepository.findById(story.id())).contains(story);
        assertThat(storyParticipantRepository.find(
                story.id(),
                deletingUser.id()
        )).isEmpty();
        assertThat(memoryRepository.findById(memory.id()))
                .contains(memory);
        assertThat(memoryRepository.findById(memory.id())
                .orElseThrow()
                .createdBy())
                .isEqualTo(deletingUser.id());
        assertThat(userRepository.findById(deletingUser.id())
                .orElseThrow()
                .deletedAt())
                .isEqualTo(CURRENT_TIME);
        assertThat(userStoryRepository.findByUserId(deletingUser.id()))
                .isEmpty();
    }

    private User saveUser(UUID id, String googleSubject) {
        return userRepository.save(new User(
                id,
                googleSubject,
                "Memory Map User",
                "https://example.com/avatar.png",
                BASE_TIME,
                BASE_TIME
        ));
    }

    private Story saveStory(UUID id, UUID ownerId, UUID soundtrackId) {
        return saveStory(id, ownerId, soundtrackId, null);
    }

    private Story saveStory(
            UUID id,
            UUID ownerId,
            UUID soundtrackId,
            StoryCoverMetadata cover
    ) {
        return storyRepository.save(new Story(
                id,
                ownerId,
                "Our Story",
                "The beginning",
                soundtrackId,
                cover,
                BASE_TIME,
                BASE_TIME
        ));
    }

    private static StoryCoverMetadata coverMetadata(
            UUID storyId,
            String objectId
    ) {
        return new StoryCoverMetadata(
                "stories/%s/cover/%s/display".formatted(storyId, objectId),
                2_048L,
                "stories/%s/cover/%s/thumbnail".formatted(storyId, objectId),
                512L,
                "image/jpeg",
                BASE_TIME
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
        storyParticipantRepository.save(new StoryParticipant(
                storyId,
                userId,
                role,
                joinedAt
        ));
    }

    private Memory saveMemory(
            UUID id,
            UUID storyId,
            UUID createdBy
    ) {
        Memory memory = new Memory(
                id,
                storyId,
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE,
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
                "display-key-" + id,
                1_024L,
                "thumbnail-key-" + id,
                128L,
                "image/jpeg",
                BASE_TIME
        );
        mediaFileRepository.save(mediaFile);

        return mediaFile;
    }

    private Invite saveInvite(
            UUID id,
            UUID storyId,
            UUID createdBy,
            Instant usedAt
    ) {
        Invite invite = new Invite(
                id,
                storyId,
                "token-hash-" + id,
                createdBy,
                BASE_TIME,
                BASE_TIME.plusSeconds(86_400),
                usedAt
        );
        inviteRepository.save(invite);

        return invite;
    }

    private RefreshToken saveRefreshToken(UUID userId) {
        RefreshToken refreshToken = new RefreshToken(
                REFRESH_TOKEN_ID,
                userId,
                UUID.randomUUID(),
                "refresh-token-hash",
                BASE_TIME,
                BASE_TIME.plusSeconds(86_400),
                null,
                null
        );
        refreshTokenRepository.save(refreshToken);

        return refreshToken;
    }

    private UUID saveMusicTrack() {
        jdbcClient.sql("""
                INSERT INTO music_tracks (
                    id,
                    title,
                    artist,
                    duration_seconds,
                    status,
                    sort_order,
                    storage_key,
                    mime_type,
                    file_size,
                    created_at,
                    updated_at
                )
                VALUES (
                    :id,
                    'Autumn Leaves',
                    'Memory Story',
                    120,
                    'ACTIVE',
                    1,
                    'music/autumn-leaves.mp3',
                    'audio/mpeg',
                    1024,
                    :createdAt,
                    :updatedAt
                )
                """)
                .param("id", MUSIC_TRACK_ID)
                .param(
                        "createdAt",
                        DatabaseTimestamps.toOffsetDateTime(BASE_TIME)
                )
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(BASE_TIME)
                )
                .update();

        return MUSIC_TRACK_ID;
    }

    private int musicTrackCount(UUID trackId) {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM music_tracks
                WHERE id = :trackId
                """)
                .param("trackId", trackId)
                .query(Long.class)
                .single()
                .intValue();
    }

    private static DeleteCurrentAccountCommand command(UUID userId) {
        return new DeleteCurrentAccountCommand(
                new AuthenticatedUser(userId),
                CURRENT_TIME
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class DeleteCurrentAccountTestConfiguration {

        @Bean
        @Primary
        TestStorageService testStorageService() {
            return new TestStorageService();
        }
    }

    static final class TestStorageService implements StorageService {

        private final List<StorageKey> deletedKeys = new ArrayList<>();

        @Override
        public void store(StorageObjectWrite object) {
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            throw new UnsupportedOperationException();
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
            deletedKeys.add(storageKey);
        }

        private void reset() {
            deletedKeys.clear();
        }
    }
}
