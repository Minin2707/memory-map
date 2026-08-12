package memory_map.backend.media.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.media.application.DeleteMediaCommand;
import memory_map.backend.media.application.DeleteMediaUseCase;
import memory_map.backend.media.application.DownloadMediaUseCase;
import memory_map.backend.media.application.DownloadedMedia;
import memory_map.backend.media.application.ListMemoryMediaUseCase;
import memory_map.backend.media.application.MediaDeletionUnavailableException;
import memory_map.backend.media.application.MediaRepresentation;
import memory_map.backend.media.application.MediaUnavailableException;
import memory_map.backend.media.application.PhotoUploadUnavailableException;
import memory_map.backend.media.application.UploadPhotoCommand;
import memory_map.backend.media.application.UploadPhotoUseCase;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.image.InvalidImageReason;
import memory_map.backend.media.storage.StorageException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.io.ByteArrayInputStream;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(MediaController.class)
@AutoConfigureMockMvc
@Import({
        MediaApiExceptionHandler.class,
        MediaMultipartExceptionHandler.class,
        SecurityConfiguration.class,
        MediaControllerTest.MediaControllerTestConfiguration.class
})
class MediaControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeUploadPhotoUseCase uploadPhotoUseCase;

    @Autowired
    private FakeListMemoryMediaUseCase listMemoryMediaUseCase;

    @Autowired
    private FakeDownloadMediaUseCase downloadMediaUseCase;

    @Autowired
    private FakeDeleteMediaUseCase deleteMediaUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @Autowired
    private CountingClock clock;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final UUID CLIENT_SUPPLIED_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000099");
    private static final UUID SECOND_MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000032");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final String VALID_ACCESS_TOKEN = "valid-access-token";
    private static final String INVALID_ACCESS_TOKEN = "invalid-access-token";
    private static final byte[] PNG_BYTES = new byte[] {
            (byte) 0x89, 0x50, 0x4E, 0x47
    };
    private static final byte[] DISPLAY_BYTES = new byte[] {1, 2, 3, 4};
    private static final byte[] THUMBNAIL_BYTES = new byte[] {9, 8};

    @BeforeEach
    void resetFakes() {
        uploadPhotoUseCase.reset();
        listMemoryMediaUseCase.reset();
        downloadMediaUseCase.reset();
        deleteMediaUseCase.reset();
        currentAuthenticatedUserProvider.reset();
        clock.reset();
    }

    @Test
    void shouldUploadPhotoAndReturnSafeMediaResponse() throws Exception {
        String response = mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .file(file("photo.png", "image/png", PNG_BYTES))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isCreated())
                .andExpect(content().contentTypeCompatibleWith(
                        org.springframework.http.MediaType.APPLICATION_JSON
                ))
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.memoryId").value(MEMORY_ID.toString()))
                .andExpect(jsonPath("$.mediaType").value("PHOTO"))
                .andExpect(jsonPath("$.displayFileSize").value(1024))
                .andExpect(jsonPath("$.thumbnailFileSize").value(128))
                .andExpect(jsonPath("$.mimeType").value("image/jpeg"))
                .andExpect(jsonPath("$.createdAt").value(
                        "2026-01-10T10:00:00Z"
                ))
                .andExpect(jsonPath("$.thumbnailUrl").exists())
                .andExpect(jsonPath("$.displayUrl").exists())
                .andExpect(jsonPath("$.displayStorageKey").doesNotExist())
                .andExpect(jsonPath("$.thumbnailStorageKey").doesNotExist())
                .andExpect(jsonPath("$.storageKey").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        UploadPhotoCommand command = uploadPhotoUseCase.receivedCommand();

        assertThat(uploadPhotoUseCase.callCount()).isEqualTo(1);
        assertThat(currentAuthenticatedUserProvider.callCount()).isEqualTo(1);
        assertThat(clock.instantCallCount()).isEqualTo(1);
        assertThat(command.authenticatedUser()).isEqualTo(
                new AuthenticatedUser(USER_ID)
        );
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.mediaId()).isNotNull();
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(command.image().content()).containsExactly(PNG_BYTES);
        assertThat(command.image().declaredContentType()).isEqualTo("image/png");
        assertThat(response)
                .contains("/api/v1/media/%s/thumbnail".formatted(
                        command.mediaId()
                ))
                .contains("/api/v1/media/%s/display".formatted(
                        command.mediaId()
                ))
                .doesNotContain("displayStorageKey")
                .doesNotContain("thumbnailStorageKey")
                .doesNotContain("storageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio")
                .doesNotContain("memories/" + MEMORY_ID);
    }

    @Test
    void shouldIgnoreClientSuppliedServerOwnedMultipartFields()
            throws Exception {

        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .file(file("photo.png", "image/png", PNG_BYTES))
                        .param("mediaId", CLIENT_SUPPLIED_MEDIA_ID.toString())
                        .param("storyId", UUID.randomUUID().toString())
                        .param("userId", UUID.randomUUID().toString())
                        .param("role", "OWNER")
                        .param("displayStorageKey", "attacker-display")
                        .param("thumbnailStorageKey", "attacker-thumbnail")
                        .param("createdAt", "2000-01-01T00:00:00Z")
                        .param("mediaType", "VIDEO")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isCreated());

        UploadPhotoCommand command = uploadPhotoUseCase.receivedCommand();

        assertThat(command.mediaId()).isNotEqualTo(CLIENT_SUPPLIED_MEDIA_ID);
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.authenticatedUser().userId()).isEqualTo(USER_ID);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldAllowMissingDeclaredContentType() throws Exception {
        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .file(file("photo", null, PNG_BYTES))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isCreated());

        assertThat(uploadPhotoUseCase.receivedCommand()
                .image()
                .declaredContentType()).isNull();
    }

    @Test
    void shouldReturnNotFoundWhenUploadIsUnavailable() throws Exception {
        uploadPhotoUseCase.failWith(new PhotoUploadUnavailableException());

        String response = mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .file(file("photo.png", "image/png", PNG_BYTES))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value(
                        "Photo could not be uploaded"
                ))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("storage");
    }

    @Test
    void shouldReturnBadRequestForInvalidImage() throws Exception {
        uploadPhotoUseCase.failWith(new InvalidImageException(
                InvalidImageReason.INVALID_IMAGE
        ));

        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .file(file("photo.png", "image/png", PNG_BYTES))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Invalid photo request"));
    }

    @Test
    void shouldReturnBadRequestWhenFilePartIsMissing() throws Exception {
        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Invalid photo request"));

        assertThat(uploadPhotoUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForMalformedMemoryId() throws Exception {
        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        "not-a-uuid"
                )
                        .file(file("photo.png", "image/png", PNG_BYTES))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Invalid photo request"));

        assertThat(uploadPhotoUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForJsonRequestBody() throws Exception {
        mockMvc.perform(post(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .contentType(org.springframework.http.MediaType
                                .APPLICATION_JSON)
                        .content("{}")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Invalid photo request"));

        assertThat(uploadPhotoUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnInternalServerErrorForImageProcessingFailure()
            throws Exception {

        uploadPhotoUseCase.failWith(new ImageProcessingException());

        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .file(file("photo.png", "image/png", PNG_BYTES))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail").value("Photo upload failed"));
    }

    @Test
    void shouldReturnInternalServerErrorForStorageFailure() throws Exception {
        uploadPhotoUseCase.failWith(new StorageException());

        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .file(file("photo.png", "image/png", PNG_BYTES))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail").value("Photo upload failed"));
    }

    @Test
    void shouldListMediaWithBackendUrlsAndNoStorageDetails() throws Exception {
        String response = mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(commandMediaId().toString()))
                .andExpect(jsonPath("$[0].thumbnailUrl").value(
                        "/api/v1/media/%s/thumbnail".formatted(
                                commandMediaId()
                        )
                ))
                .andExpect(jsonPath("$[0].displayUrl").value(
                        "/api/v1/media/%s/display".formatted(
                                commandMediaId()
                        )
                ))
                .andExpect(jsonPath("$[1].id").value(SECOND_MEDIA_ID.toString()))
                .andExpect(jsonPath("$[0].displayStorageKey").doesNotExist())
                .andExpect(jsonPath("$[0].thumbnailStorageKey").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(listMemoryMediaUseCase.callCount()).isEqualTo(1);
        assertThat(listMemoryMediaUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(listMemoryMediaUseCase.receivedMemoryId())
                .isEqualTo(MEMORY_ID);
        assertThat(response)
                .doesNotContain("display-storage")
                .doesNotContain("thumbnail-storage")
                .doesNotContain("bucket")
                .doesNotContain("minio");
    }

    @Test
    void shouldReturnEmptyMediaList() throws Exception {
        listMemoryMediaUseCase.mediaFiles = List.of();

        mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(content().json("[]"));
    }

    @Test
    void shouldReturnNotFoundWhenMediaListIsUnavailable() throws Exception {
        listMemoryMediaUseCase.failWith(new MediaUnavailableException());

        String response = mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value(
                        "Media could not be found"
                ))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("storage");
        assertThat(downloadMediaUseCase.callCount()).isZero();
    }

    @Test
    void shouldDownloadThumbnailThroughBackend() throws Exception {
        downloadMediaUseCase.downloadedMedia = new DownloadedMedia(
                new ByteArrayInputStream(THUMBNAIL_BYTES),
                THUMBNAIL_BYTES.length,
                "image/jpeg"
        );

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/media/{mediaId}/thumbnail",
                        commandMediaId()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        byte[] response = mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk())
                .andExpect(content().contentType("image/jpeg"))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_LENGTH,
                        Long.toString(THUMBNAIL_BYTES.length)
                ))
                .andExpect(content().bytes(THUMBNAIL_BYTES))
                .andReturn()
                .getResponse()
                .getContentAsByteArray();

        assertThat(response).containsExactly(THUMBNAIL_BYTES);
        assertThat(downloadMediaUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(downloadMediaUseCase.receivedMediaId())
                .isEqualTo(commandMediaId());
        assertThat(downloadMediaUseCase.receivedRepresentation())
                .isEqualTo(MediaRepresentation.THUMBNAIL);
    }

    @Test
    void shouldDownloadDisplayThroughBackend() throws Exception {
        downloadMediaUseCase.downloadedMedia = new DownloadedMedia(
                new ByteArrayInputStream(DISPLAY_BYTES),
                DISPLAY_BYTES.length,
                "image/jpeg"
        );

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/media/{mediaId}/display",
                        commandMediaId()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk())
                .andExpect(content().contentType("image/jpeg"))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_LENGTH,
                        Long.toString(DISPLAY_BYTES.length)
                ))
                .andExpect(content().bytes(DISPLAY_BYTES));

        assertThat(downloadMediaUseCase.receivedRepresentation())
                .isEqualTo(MediaRepresentation.DISPLAY);
    }

    @Test
    void shouldReturnNotFoundWhenDownloadIsUnavailable() throws Exception {
        downloadMediaUseCase.failWith(new MediaUnavailableException());

        mockMvc.perform(get(
                        "/api/v1/media/{mediaId}/thumbnail",
                        commandMediaId()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value(
                        "Media could not be found"
                ));
    }

    @Test
    void shouldReturnTechnicalFailureForDownloadStorageFailure()
            throws Exception {

        downloadMediaUseCase.failWith(new StorageException());

        mockMvc.perform(get(
                        "/api/v1/media/{mediaId}/display",
                        commandMediaId()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail").value("Photo upload failed"));
    }

    @Test
    void shouldDeleteMediaAndReturnNoContent() throws Exception {
        mockMvc.perform(delete(
                        "/api/v1/media/{mediaId}",
                        commandMediaId()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        DeleteMediaCommand command = deleteMediaUseCase.receivedCommand();

        assertThat(deleteMediaUseCase.callCount()).isEqualTo(1);
        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.mediaId()).isEqualTo(commandMediaId());
        assertThat(currentAuthenticatedUserProvider.callCount()).isEqualTo(1);
    }

    @Test
    void shouldReturnNotFoundWhenDeleteIsUnavailable() throws Exception {
        deleteMediaUseCase.failWith(new MediaDeletionUnavailableException());

        String response = mockMvc.perform(delete(
                        "/api/v1/media/{mediaId}",
                        commandMediaId()
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value(
                        "Media could not be deleted"
                ))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(commandMediaId().toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("OWNER")
                .doesNotContain("storage")
                .doesNotContain("bucket")
                .doesNotContain("MinIO");
    }

    @Test
    void shouldReturnBadRequestForMalformedDeleteMediaId() throws Exception {
        mockMvc.perform(delete(
                        "/api/v1/media/{mediaId}",
                        "not-a-uuid"
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value(
                        "Invalid photo request"
                ));

        assertThat(deleteMediaUseCase.callCount()).isZero();
    }

    @Test
    void shouldRejectRequestWithoutBearerToken() throws Exception {
        mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                ).file(file("photo.png", "image/png", PNG_BYTES)))
                .andExpect(status().isUnauthorized());

        assertThat(uploadPhotoUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectUnauthenticatedListBeforeUseCase() throws Exception {
        mockMvc.perform(get(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(listMemoryMediaUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectUnauthenticatedDownloadBeforeUseCase() throws Exception {
        mockMvc.perform(get(
                        "/api/v1/media/{mediaId}/thumbnail",
                        commandMediaId()
                ))
                .andExpect(status().isUnauthorized());

        assertThat(downloadMediaUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectUnauthenticatedDeleteBeforeUseCase() throws Exception {
        mockMvc.perform(delete(
                        "/api/v1/media/{mediaId}",
                        commandMediaId()
                ))
                .andExpect(status().isUnauthorized());

        assertThat(deleteMediaUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectRequestWithInvalidBearerToken() throws Exception {
        String response = mockMvc.perform(multipart(
                        "/api/v1/memories/{memoryId}/media",
                        MEMORY_ID
                )
                        .file(file("photo.png", "image/png", PNG_BYTES))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + INVALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(uploadPhotoUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new MediaController(
                null,
                listMemoryMediaUseCase,
                downloadMediaUseCase,
                deleteMediaUseCase,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("uploadPhotoUseCase must not be null");

        assertThatThrownBy(() -> new MediaController(
                uploadPhotoUseCase,
                null,
                downloadMediaUseCase,
                deleteMediaUseCase,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("listMemoryMediaUseCase must not be null");

        assertThatThrownBy(() -> new MediaController(
                uploadPhotoUseCase,
                listMemoryMediaUseCase,
                null,
                deleteMediaUseCase,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("downloadMediaUseCase must not be null");

        assertThatThrownBy(() -> new MediaController(
                uploadPhotoUseCase,
                listMemoryMediaUseCase,
                downloadMediaUseCase,
                null,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("deleteMediaUseCase must not be null");

        assertThatThrownBy(() -> new MediaController(
                uploadPhotoUseCase,
                listMemoryMediaUseCase,
                downloadMediaUseCase,
                deleteMediaUseCase,
                null,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("currentAuthenticatedUserProvider must not be null");

        assertThatThrownBy(() -> new MediaController(
                uploadPhotoUseCase,
                listMemoryMediaUseCase,
                downloadMediaUseCase,
                deleteMediaUseCase,
                currentAuthenticatedUserProvider,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    private static MockMultipartFile file(
            String originalFilename,
            String contentType,
            byte[] content
    ) {
        return new MockMultipartFile(
                "file",
                originalFilename,
                contentType,
                content
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class MediaControllerTestConfiguration {

        @Bean
        MediaController mediaController(
                FakeUploadPhotoUseCase uploadPhotoUseCase,
                FakeListMemoryMediaUseCase listMemoryMediaUseCase,
                FakeDownloadMediaUseCase downloadMediaUseCase,
                FakeDeleteMediaUseCase deleteMediaUseCase,
                FakeCurrentAuthenticatedUserProvider
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
        CountingClock clock() {
            return new CountingClock();
        }

        @Bean
        FakeUploadPhotoUseCase uploadPhotoUseCase() {
            return new FakeUploadPhotoUseCase();
        }

        @Bean
        FakeListMemoryMediaUseCase listMemoryMediaUseCase() {
            return new FakeListMemoryMediaUseCase();
        }

        @Bean
        FakeDownloadMediaUseCase downloadMediaUseCase() {
            return new FakeDownloadMediaUseCase();
        }

        @Bean
        FakeDeleteMediaUseCase deleteMediaUseCase() {
            return new FakeDeleteMediaUseCase();
        }

        @Bean
        @Primary
        FakeCurrentAuthenticatedUserProvider
        fakeCurrentAuthenticatedUserProvider() {
            return new FakeCurrentAuthenticatedUserProvider();
        }

        @Bean
        JwtDecoder jwtDecoder() {
            return token -> {
                if (!VALID_ACCESS_TOKEN.equals(token)) {
                    throw new BadJwtException("Access token is invalid");
                }

                return Jwt.withTokenValue(token)
                        .headers(headers -> headers.putAll(Map.of(
                                "alg",
                                "none"
                        )))
                        .subject(USER_ID.toString())
                        .issuedAt(CURRENT_TIME)
                        .expiresAt(CURRENT_TIME.plusSeconds(900))
                        .build();
            };
        }
    }

    static final class FakeUploadPhotoUseCase implements UploadPhotoUseCase {

        private UploadPhotoCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public MediaFile uploadPhoto(UploadPhotoCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return new MediaFile(
                    command.mediaId(),
                    command.memoryId(),
                    MediaType.PHOTO,
                    "media/" + command.mediaId() + "/display",
                    1_024L,
                    "media/" + command.mediaId() + "/thumbnail",
                    128L,
                    "image/jpeg",
                    command.currentTime()
            );
        }

        private UploadPhotoCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedCommand = null;
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeListMemoryMediaUseCase
            implements ListMemoryMediaUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedMemoryId;
        private RuntimeException exception;
        private int callCount;
        private List<MediaFile> mediaFiles = List.of(
                mediaFile(commandMediaId()),
                mediaFile(SECOND_MEDIA_ID)
        );

        @Override
        public List<MediaFile> listMedia(
                AuthenticatedUser authenticatedUser,
                UUID memoryId
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedMemoryId = memoryId;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return mediaFiles;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private UUID receivedMemoryId() {
            return receivedMemoryId;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedMemoryId = null;
            exception = null;
            callCount = 0;
            mediaFiles = List.of(mediaFile(commandMediaId()), mediaFile(
                    SECOND_MEDIA_ID
            ));
        }
    }

    static final class FakeDownloadMediaUseCase
            implements DownloadMediaUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedMediaId;
        private MediaRepresentation receivedRepresentation;
        private RuntimeException exception;
        private int callCount;
        private DownloadedMedia downloadedMedia = new DownloadedMedia(
                new ByteArrayInputStream(DISPLAY_BYTES),
                DISPLAY_BYTES.length,
                "image/jpeg"
        );

        @Override
        public DownloadedMedia downloadMedia(
                AuthenticatedUser authenticatedUser,
                UUID mediaId,
                MediaRepresentation representation
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedMediaId = mediaId;
            receivedRepresentation = representation;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return downloadedMedia;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private UUID receivedMediaId() {
            return receivedMediaId;
        }

        private MediaRepresentation receivedRepresentation() {
            return receivedRepresentation;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedMediaId = null;
            receivedRepresentation = null;
            exception = null;
            callCount = 0;
            downloadedMedia = new DownloadedMedia(
                    new ByteArrayInputStream(DISPLAY_BYTES),
                    DISPLAY_BYTES.length,
                    "image/jpeg"
            );
        }
    }

    static final class FakeDeleteMediaUseCase implements DeleteMediaUseCase {

        private DeleteMediaCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public void deleteMedia(DeleteMediaCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }
        }

        private DeleteMediaCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedCommand = null;
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeCurrentAuthenticatedUserProvider
            implements CurrentAuthenticatedUserProvider {

        private int callCount;

        @Override
        public AuthenticatedUser getCurrentUser() {
            callCount++;

            return new AuthenticatedUser(USER_ID);
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            callCount = 0;
        }
    }

    static final class CountingClock extends Clock {

        private int instantCallCount;

        @Override
        public ZoneOffset getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            instantCallCount++;

            return CURRENT_TIME;
        }

        private int instantCallCount() {
            return instantCallCount;
        }

        private void reset() {
            instantCallCount = 0;
        }
    }

    private static UUID commandMediaId() {
        return MEDIA_ID;
    }

    private static MediaFile mediaFile(UUID id) {
        return new MediaFile(
                id,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-storage-" + id,
                1_024L,
                "thumbnail-storage-" + id,
                128L,
                "image/jpeg",
                CURRENT_TIME
        );
    }
}
