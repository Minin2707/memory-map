package memory_map.backend.media.api;

import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.media.application.CoordinatedUploadPhotoService;
import memory_map.backend.media.application.DeleteMediaAuthorizationPolicy;
import memory_map.backend.media.application.DeleteMediaUseCase;
import memory_map.backend.media.application.DownloadMediaUseCase;
import memory_map.backend.media.application.ListMemoryMediaUseCase;
import memory_map.backend.media.application.PhotoUploadAuthorizationPolicy;
import memory_map.backend.media.application.TransactionCommitCoordinator;
import memory_map.backend.media.application.TransactionRollbackCoordinator;
import memory_map.backend.media.application.TransactionalDeleteMediaService;
import memory_map.backend.media.application.TransactionalDownloadMediaService;
import memory_map.backend.media.application.TransactionalListMemoryMediaService;
import memory_map.backend.media.application.UploadPhotoUseCase;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.image.ImageProcessor;
import memory_map.backend.media.repository.AuthorizedMediaDownloadRepository;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.MediaStorageKeyFactory;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageObjectWrite;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.notification.application.NotificationPublisher;
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
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Import(MediaControllerIntegrationTest.MediaControllerIntegrationTestConfiguration.class)
class MediaControllerIntegrationTest extends IntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private AccessTokenService accessTokenService;

    @Autowired
    private MemoryRepository memoryRepository;

    @Autowired
    private MediaFileRepository mediaFileRepository;

    @Autowired
    private TestStorageService storageService;

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
    private static final UUID AUTHOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID OUTSIDER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID OTHER_STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000012");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID CLIENT_SUPPLIED_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000099");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabaseAndStorage() {
        storageService.reset();
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldUploadPngForOwnerAndPersistOneRowAndTwoObjects()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User author = saveUser(AUTHOR_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        JsonNode response = uploadPhoto(
                validAccessToken(owner.id()),
                memory.id(),
                pngBytes(),
                "image/png",
                201
        );

        UUID mediaId = UUID.fromString(response.at("/id").asText());
        MediaFile persisted = mediaFileRepository.findById(mediaId)
                .orElseThrow();

        assertMediaResponseMatches(response, persisted);
        assertThat(persisted.memoryId()).isEqualTo(memory.id());
        assertThat(persisted.type().name()).isEqualTo("PHOTO");
        assertThat(persisted.mimeType()).isEqualTo("image/jpeg");
        assertThat(persisted.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(storageService.objects).containsOnlyKeys(
                new StorageKey(persisted.displayStorageKey()),
                new StorageKey(persisted.thumbnailStorageKey())
        );
        assertThat(storageService.objects.values())
                .allSatisfy(object -> assertThat(object.contentType())
                        .isEqualTo("image/jpeg"));
        assertThat(mediaCount()).isEqualTo(1);
        assertThat(response.toString())
                .doesNotContain("displayStorageKey")
                .doesNotContain("thumbnailStorageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio")
                .doesNotContain("memories/" + memory.id());
    }

    @ParameterizedTest
    @EnumSource(
            value = StoryRole.class,
            names = {"OWNER", "CO_OWNER", "EDITOR", "VIEWER"}
    )
    void shouldRespectAllowedRoleMatrix(StoryRole role) throws Exception {
        User owner = saveUser(OWNER_ID);
        User requester = role == StoryRole.OWNER
                ? owner
                : saveUser(USER_ID);
        User author = role == StoryRole.EDITOR || role == StoryRole.VIEWER
                ? requester
                : saveUser(AUTHOR_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), requester.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        JsonNode response = uploadPhoto(
                validAccessToken(requester.id()),
                memory.id(),
                jpegBytes(),
                "image/jpeg",
                201
        );

        assertThat(mediaFileRepository.findById(
                UUID.fromString(response.at("/id").asText())
        )).isPresent();
        assertThat(storageService.objects).hasSize(2);
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldReturnSafeNotFoundForDeniedAuthorRoles(StoryRole role)
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        User author = saveUser(AUTHOR_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), requester.id(), role);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        JsonNode denied = uploadPhoto(
                validAccessToken(requester.id()),
                memory.id(),
                pngBytes(),
                "image/png",
                404
        );
        JsonNode missing = uploadPhoto(
                validAccessToken(requester.id()),
                UUID.randomUUID(),
                pngBytes(),
                "image/png",
                404
        );

        assertSamePublicProblem(denied, missing);
        assertNoMediaStorageOrRows();
    }

    @Test
    void shouldReturnSafeNotFoundForOutsiderFormerAuthorAndWrongStory()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User requester = saveUser(USER_ID);
        User author = saveUser(AUTHOR_ID);
        User outsider = saveUser(OUTSIDER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        Story otherStory = saveStory(OTHER_STORY_ID, owner.id());
        saveParticipant(otherStory.id(), requester.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        JsonNode outsiderResponse = uploadPhoto(
                validAccessToken(outsider.id()),
                memory.id(),
                pngBytes(),
                "image/png",
                404
        );
        JsonNode formerAuthorResponse = uploadPhoto(
                validAccessToken(author.id()),
                memory.id(),
                pngBytes(),
                "image/png",
                404
        );
        JsonNode wrongStoryResponse = uploadPhoto(
                validAccessToken(requester.id()),
                memory.id(),
                pngBytes(),
                "image/png",
                404
        );

        assertPhotoUnavailableBodyIsSafe(outsiderResponse);
        assertSamePublicProblem(outsiderResponse, formerAuthorResponse);
        assertSamePublicProblem(outsiderResponse, wrongStoryResponse);
        assertNoMediaStorageOrRows();
    }

    @Test
    void shouldIgnoreServerOwnedMultipartFieldsAndKeepAuthorizationReal()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User viewer = saveUser(USER_ID);
        User author = saveUser(AUTHOR_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), viewer.id(), StoryRole.VIEWER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), author.id());

        String response = mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        memory.id()
                )
                        .file(file(pngBytes(), "image/png"))
                        .param("mediaId", CLIENT_SUPPLIED_MEDIA_ID.toString())
                        .param("role", "OWNER")
                        .param("createdAt", "2000-01-01T00:00:00Z")
                        .param("displayStorageKey", "attacker-display")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(viewer.id())
                        ))
                .andExpect(status().isNotFound())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertPhotoUnavailableBodyIsSafe(jsonMapper.readTree(response));
        assertNoMediaStorageOrRows();
    }

    @Test
    void shouldReturnBadRequestForMimeMismatchAndInvalidBytes()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        String accessToken = validAccessToken(owner.id());

        JsonNode mismatch = uploadPhoto(
                accessToken,
                memory.id(),
                pngBytes(),
                "image/jpeg",
                400
        );
        JsonNode invalid = uploadPhoto(
                accessToken,
                memory.id(),
                new byte[] {1, 2, 3, 4},
                "image/jpeg",
                400
        );

        assertInvalidPhotoBody(mismatch);
        assertInvalidPhotoBody(invalid);
        assertNoMediaStorageOrRows();
    }

    @Test
    void shouldReturnUnauthorizedBeforeUploadUseCase() throws Exception {
        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                ).file(file(pngBytes(), "image/png")))
                .andExpect(status().isUnauthorized());

        assertNoMediaStorageOrRows();
    }

    @Test
    void shouldListMediaForParticipantWithBackendUrlsAndNoStorageLeak()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.VIEWER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile first = saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);
        MediaFile second = saveMediaFile(
                SECOND_MEDIA_ID,
                memory.id(),
                BASE_TIME.plusSeconds(1)
        );

        JsonNode response = listMedia(
                validAccessToken(owner.id()),
                memory.id(),
                200
        );

        assertThat(response.size()).isEqualTo(2);
        assertMediaResponseMatches(response.get(0), first);
        assertThat(response.at("/0/thumbnailUrl").asText())
                .isEqualTo("/api/v1/media/%s/thumbnail".formatted(first.id()));
        assertThat(response.at("/0/displayUrl").asText())
                .isEqualTo("/api/v1/media/%s/display".formatted(first.id()));
        assertThat(response.at("/1/id").asText())
                .isEqualTo(second.id().toString());
        assertThat(response.toString())
                .doesNotContain("displayStorageKey")
                .doesNotContain("thumbnailStorageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio")
                .doesNotContain(first.displayStorageKey())
                .doesNotContain(first.thumbnailStorageKey());
    }

    @Test
    void shouldReturnEmptyMediaListForAuthorizedParticipant()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());

        JsonNode response = listMedia(
                validAccessToken(owner.id()),
                memory.id(),
                200
        );

        assertThat(response.isArray()).isTrue();
        assertThat(response.size()).isZero();
    }

    @Test
    void shouldReturnSafeNotFoundForInaccessibleMediaList()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(OUTSIDER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);

        JsonNode inaccessible = listMedia(
                validAccessToken(outsider.id()),
                memory.id(),
                404
        );
        JsonNode missing = listMedia(
                validAccessToken(outsider.id()),
                UUID.randomUUID(),
                404
        );

        assertMediaUnavailableBodyIsSafe(inaccessible);
        assertSamePublicProblem(inaccessible, missing);
        assertThat(storageService.readCalls).isZero();
    }

    @Test
    void shouldDownloadThumbnailAndDisplayThroughBackend()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.VIEWER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);
        storageService.objects.put(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageObjectWrite(
                        new StorageKey(mediaFile.thumbnailStorageKey()),
                        new byte[] {1, 2},
                        "image/jpeg"
                )
        );
        storageService.objects.put(
                new StorageKey(mediaFile.displayStorageKey()),
                new StorageObjectWrite(
                        new StorageKey(mediaFile.displayStorageKey()),
                        new byte[] {3, 4, 5, 6},
                        "image/jpeg"
                )
        );

        byte[] thumbnail = download(
                validAccessToken(owner.id()),
                mediaFile.id(),
                "thumbnail",
                200,
                mediaFile.thumbnailFileSize()
        );
        byte[] display = download(
                validAccessToken(owner.id()),
                mediaFile.id(),
                "display",
                200,
                mediaFile.displayFileSize()
        );

        assertThat(thumbnail).containsExactly((byte) 1, (byte) 2);
        assertThat(display).containsExactly(
                (byte) 3,
                (byte) 4,
                (byte) 5,
                (byte) 6
        );
        assertThat(storageService.readKeys).containsExactly(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageKey(mediaFile.displayStorageKey())
        );
    }

    @Test
    void shouldReturnSafeNotFoundForInaccessibleDownload()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(OUTSIDER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);

        String response = downloadProblem(
                validAccessToken(outsider.id()),
                mediaFile.id(),
                "thumbnail",
                404
        );

        assertMediaUnavailableBodyIsSafe(jsonMapper.readTree(response));
        assertThat(storageService.readCalls).isZero();
    }

    @Test
    void shouldReturnSameSafeNotFoundForMissingAndUnauthorizedDownload()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(OUTSIDER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);

        JsonNode unauthorized = jsonMapper.readTree(downloadProblem(
                validAccessToken(outsider.id()),
                mediaFile.id(),
                "thumbnail",
                404
        ));
        JsonNode missing = jsonMapper.readTree(downloadProblem(
                validAccessToken(outsider.id()),
                UUID.randomUUID(),
                "thumbnail",
                404
        ));

        assertMediaUnavailableBodyIsSafe(unauthorized);
        assertSamePublicProblem(unauthorized, missing);
        assertThat(storageService.readCalls).isZero();
    }

    @Test
    void shouldReturnSafeNotFoundForMissingStorageObject()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);

        String response = downloadProblem(
                validAccessToken(owner.id()),
                mediaFile.id(),
                "display",
                404
        );

        assertMediaUnavailableBodyIsSafe(jsonMapper.readTree(response));
    }

    @Test
    void shouldReturnTechnicalFailureForStorageFailure()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);
        storageService.failure = new StorageException();

        String response = downloadProblem(
                validAccessToken(owner.id()),
                mediaFile.id(),
                "display",
                500
        );

        JsonNode problem = jsonMapper.readTree(response);
        assertThat(problem.at("/detail").asText())
                .isEqualTo("Photo upload failed");
        assertThat(problem.toString())
                .doesNotContain(mediaFile.displayStorageKey())
                .doesNotContain("MinIO")
                .doesNotContain("bucket");
    }

    @Test
    void shouldDeleteMediaThroughRestAndCleanupStorageAfterCommit()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);
        storageService.objects.put(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageObjectWrite(
                        new StorageKey(mediaFile.thumbnailStorageKey()),
                        new byte[] {1, 2},
                        "image/jpeg"
                )
        );
        storageService.objects.put(
                new StorageKey(mediaFile.displayStorageKey()),
                new StorageObjectWrite(
                        new StorageKey(mediaFile.displayStorageKey()),
                        new byte[] {3, 4, 5, 6},
                        "image/jpeg"
                )
        );

        mockMvc.perform(delete(
                        "/api/v1/media/{mediaId}",
                        mediaFile.id()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(owner.id())
                        ))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        assertThat(mediaFileRepository.findById(mediaFile.id())).isEmpty();
        assertThat(storageService.deletedKeys).containsExactly(
                new StorageKey(mediaFile.thumbnailStorageKey()),
                new StorageKey(mediaFile.displayStorageKey())
        );
        assertThat(storageService.objects).isEmpty();
    }

    @Test
    void shouldReturnSafeNotFoundForInaccessibleDelete()
            throws Exception {

        User owner = saveUser(OWNER_ID);
        User outsider = saveUser(OUTSIDER_ID);
        Story story = saveStory(STORY_ID, owner.id());
        saveParticipant(story.id(), owner.id(), StoryRole.OWNER);
        Memory memory = saveMemory(MEMORY_ID, story.id(), owner.id());
        MediaFile mediaFile = saveMediaFile(MEDIA_ID, memory.id(), BASE_TIME);

        String response = mockMvc.perform(delete(
                        "/api/v1/media/{mediaId}",
                        mediaFile.id()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken(outsider.id())
                        ))
                .andExpect(status().isNotFound())
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode problem = jsonMapper.readTree(response);
        assertThat(problem.at("/detail").asText())
                .isEqualTo("Media could not be deleted");
        assertThat(problem.toString())
                .doesNotContain(mediaFile.id().toString())
                .doesNotContain(mediaFile.displayStorageKey())
                .doesNotContain("storage")
                .doesNotContain("MinIO");
        assertThat(mediaFileRepository.findById(mediaFile.id()))
                .contains(mediaFile);
        assertThat(storageService.deletedKeys).isEmpty();
    }

    private JsonNode uploadPhoto(
            String accessToken,
            UUID memoryId,
            byte[] content,
            String contentType,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        memoryId
                )
                        .file(file(content, contentType))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();

        return jsonMapper.readTree(response);
    }

    private JsonNode listMedia(
            String accessToken,
            UUID memoryId,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}/media",
                        memoryId
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();

        return jsonMapper.readTree(response);
    }

    private byte[] download(
            String accessToken,
            UUID mediaId,
            String representation,
            int expectedStatus,
            long expectedContentLength
    ) throws Exception {
        MvcResult result = mockMvc.perform(get(
                        "/api/v1/media/{mediaId}/{representation}",
                        mediaId,
                        representation
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        return mockMvc.perform(asyncDispatch(result))
                .andExpect(status().is(expectedStatus))
                .andExpect(content().contentType("image/jpeg"))
                .andExpect(header().string(
                        HttpHeaders.CACHE_CONTROL,
                        "private, no-store"
                ))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_LENGTH,
                        Long.toString(expectedContentLength)
                ))
                .andReturn()
                .getResponse()
                .getContentAsByteArray();
    }

    private String downloadProblem(
            String accessToken,
            UUID mediaId,
            String representation,
            int expectedStatus
    ) throws Exception {
        return mockMvc.perform(get(
                        "/api/v1/media/{mediaId}/{representation}",
                        mediaId,
                        representation
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + accessToken
                        ))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();
    }

    private User saveUser(UUID id) {
        return userRepository.save(new User(
                id,
                "google-subject-" + id,
                "Memory Map User",
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

    private Memory saveMemory(UUID id, UUID storyId, UUID createdBy) {
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

    private MediaFile saveMediaFile(UUID id, UUID memoryId, Instant createdAt) {
        MediaFile mediaFile = new MediaFile(
                id,
                memoryId,
                memory_map.backend.media.domain.MediaType.PHOTO,
                "private-media-storage/" + id + "/display",
                4L,
                "private-media-storage/" + id + "/thumbnail",
                2L,
                "image/jpeg",
                createdAt
        );
        mediaFileRepository.save(mediaFile);

        return mediaFile;
    }

    private String validAccessToken(UUID userId) {
        return accessTokenService.issueAccessToken(userId, Instant.now());
    }

    private int mediaCount() {
        return jdbcClient.sql("""
                SELECT COUNT(*)
                FROM media_files
                """)
                .query(Integer.class)
                .single();
    }

    private void assertNoMediaStorageOrRows() {
        assertThat(mediaCount()).isZero();
        assertThat(storageService.objects).isEmpty();
    }

    private static void assertMediaResponseMatches(
            JsonNode response,
            MediaFile mediaFile
    ) {
        assertThat(response.at("/id").asText())
                .isEqualTo(mediaFile.id().toString());
        assertThat(response.at("/memoryId").asText())
                .isEqualTo(mediaFile.memoryId().toString());
        assertThat(response.at("/mediaType").asText())
                .isEqualTo(mediaFile.type().name());
        assertThat(response.at("/displayFileSize").asLong())
                .isEqualTo(mediaFile.displayFileSize());
        assertThat(response.at("/thumbnailFileSize").asLong())
                .isEqualTo(mediaFile.thumbnailFileSize());
        assertThat(response.at("/mimeType").asText())
                .isEqualTo(mediaFile.mimeType());
        assertThat(response.at("/createdAt").asText())
                .isEqualTo(mediaFile.createdAt().toString());
        assertThat(response.at("/thumbnailUrl").asText())
                .isEqualTo("/api/v1/media/%s/thumbnail".formatted(
                        mediaFile.id()
                ));
        assertThat(response.at("/displayUrl").asText())
                .isEqualTo("/api/v1/media/%s/display".formatted(
                        mediaFile.id()
                ));
    }

    private static void assertPhotoUnavailableBodyIsSafe(JsonNode response) {
        assertThat(response.at("/title").asText()).isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Photo could not be uploaded");
        assertThat(response.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(AUTHOR_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("VIEWER")
                .doesNotContain("storage")
                .doesNotContain("media/")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc");
    }

    private static void assertMediaUnavailableBodyIsSafe(JsonNode response) {
        assertThat(response.at("/title").asText()).isEqualTo("Not Found");
        assertThat(response.at("/status").asInt()).isEqualTo(404);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Media could not be found");
        assertThat(response.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain(AUTHOR_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("VIEWER")
                .doesNotContain("storage")
                .doesNotContain("media/")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc");
    }

    private static void assertInvalidPhotoBody(JsonNode response) {
        assertThat(response.at("/title").asText()).isEqualTo("Bad Request");
        assertThat(response.at("/status").asInt()).isEqualTo(400);
        assertThat(response.at("/detail").asText())
                .isEqualTo("Invalid photo request");
        assertThat(response.toString())
                .doesNotContain("MIME_MISMATCH")
                .doesNotContain("INVALID_IMAGE")
                .doesNotContain("stackTrace")
                .doesNotContain("ImageIO");
    }

    private static void assertSamePublicProblem(
            JsonNode first,
            JsonNode second
    ) {
        assertThat(first.at("/title").asText())
                .isEqualTo(second.at("/title").asText());
        assertThat(first.at("/status").asInt())
                .isEqualTo(second.at("/status").asInt());
        assertThat(first.at("/detail").asText())
                .isEqualTo(second.at("/detail").asText());
        assertThat(first.at("/instance").asText())
                .isEqualTo(second.at("/instance").asText());
    }

    private static MockMultipartFile file(
            byte[] content,
            String contentType
    ) {
        return new MockMultipartFile(
                "file",
                "photo",
                contentType,
                content
        );
    }

    private static byte[] pngBytes() {
        return imageBytes("png");
    }

    private static byte[] jpegBytes() {
        return imageBytes("jpeg");
    }

    private static byte[] imageBytes(String format) {
        try {
            BufferedImage image = new BufferedImage(
                    40,
                    20,
                    BufferedImage.TYPE_INT_RGB
            );
            Graphics2D graphics = image.createGraphics();
            try {
                graphics.setColor(Color.BLUE);
                graphics.fillRect(0, 0, image.getWidth(), image.getHeight());
            } finally {
                graphics.dispose();
            }

            ByteArrayOutputStream output = new ByteArrayOutputStream();
            ImageIO.write(image, format, output);

            return output.toByteArray();
        } catch (IOException exception) {
            throw new IllegalStateException(exception);
        }
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class MediaControllerIntegrationTestConfiguration {

        @Bean
        MediaController mediaController(
                UploadPhotoUseCase uploadPhotoUseCase,
                ListMemoryMediaUseCase listMemoryMediaUseCase,
                DownloadMediaUseCase downloadMediaUseCase,
                DeleteMediaUseCase deleteMediaUseCase,
                CurrentAuthenticatedUserProvider
                        currentAuthenticatedUserProvider,
                Clock clock
        ) {
            return new MediaController(
                    uploadPhotoUseCase,
                    listMemoryMediaUseCase,
                    downloadMediaUseCase,
                    deleteMediaUseCase,
                    currentAuthenticatedUserProvider,
                    clock
            );
        }

        @Bean
        @Primary
        Clock fixedClock() {
            return Clock.fixed(CURRENT_TIME, ZoneOffset.UTC);
        }

        @Bean
        @Primary
        TestStorageService testStorageService() {
            return new TestStorageService();
        }

        @Bean
        @Primary
        ListMemoryMediaUseCase testListMemoryMediaUseCase(
                MemoryRepository memoryRepository,
                StoryParticipantRepository storyParticipantRepository,
                MediaFileRepository mediaFileRepository
        ) {
            return new TransactionalListMemoryMediaService(
                    memoryRepository,
                    storyParticipantRepository,
                    mediaFileRepository
            );
        }

        @Bean
        @Primary
        DownloadMediaUseCase testDownloadMediaUseCase(
                AuthorizedMediaDownloadRepository
                        authorizedMediaDownloadRepository,
                StorageService storageService
        ) {
            return new TransactionalDownloadMediaService(
                    authorizedMediaDownloadRepository,
                    storageService
            );
        }

        @Bean
        @Primary
        UploadPhotoUseCase testUploadPhotoUseCase(
                MemoryRepository memoryRepository,
                StoryParticipantRepository storyParticipantRepository,
                MediaFileRepository mediaFileRepository,
                PhotoUploadAuthorizationPolicy authorizationPolicy,
                ImageProcessor imageProcessor,
                MediaStorageKeyFactory storageKeyFactory,
                StorageService storageService,
                TransactionRollbackCoordinator rollbackCoordinator,
                NotificationPublisher notificationPublisher
        ) {
            return new CoordinatedUploadPhotoService(
                    memoryRepository,
                    storyParticipantRepository,
                    mediaFileRepository,
                    authorizationPolicy,
                    imageProcessor,
                    storageKeyFactory,
                    storageService,
                    rollbackCoordinator,
                    notificationPublisher
            );
        }

        @Bean
        @Primary
        DeleteMediaUseCase testDeleteMediaUseCase(
                MediaFileRepository mediaFileRepository,
                MemoryRepository memoryRepository,
                StoryParticipantRepository storyParticipantRepository,
                DeleteMediaAuthorizationPolicy authorizationPolicy,
                StorageService storageService,
                TransactionCommitCoordinator commitCoordinator
        ) {
            return new TransactionalDeleteMediaService(
                    mediaFileRepository,
                    memoryRepository,
                    storyParticipantRepository,
                    authorizationPolicy,
                    storageService,
                    commitCoordinator
            );
        }
    }

    static final class TestStorageService implements StorageService {

        private final Map<StorageKey, StorageObjectWrite> objects =
                new LinkedHashMap<>();
        private final java.util.List<StorageKey> readKeys =
                new java.util.ArrayList<>();
        private final java.util.List<StorageKey> deletedKeys =
                new java.util.ArrayList<>();
        private RuntimeException failure;
        private int readCalls;

        @Override
        public void store(StorageObjectWrite object) {
            objects.put(object.storageKey(), object);
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            readCalls++;
            readKeys.add(storageKey);

            if (failure != null) {
                throw failure;
            }

            StorageObjectWrite object = objects.get(storageKey);
            if (object == null) {
                throw new StorageObjectNotFoundException();
            }

            return new StoredObject(
                    new ByteArrayInputStream(object.content()),
                    object.contentLength(),
                    object.contentType()
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
            deletedKeys.add(storageKey);
            objects.remove(storageKey);
        }

        private void reset() {
            objects.clear();
            readKeys.clear();
            deletedKeys.clear();
            failure = null;
            readCalls = 0;
        }
    }
}
