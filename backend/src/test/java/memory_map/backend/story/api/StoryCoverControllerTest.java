package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.image.InvalidImageReason;
import memory_map.backend.story.application.DownloadStoryCoverUseCase;
import memory_map.backend.story.application.DownloadedStoryCover;
import memory_map.backend.story.application.RemoveStoryCoverCommand;
import memory_map.backend.story.application.RemoveStoryCoverUseCase;
import memory_map.backend.story.application.StoryPhotoPreview;
import memory_map.backend.story.application.StoryCoverRepresentation;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.UploadStoryCoverCommand;
import memory_map.backend.story.application.UploadStoryCoverUseCase;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.MockMvcPrint;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.io.ByteArrayInputStream;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(StoryCoverController.class)
@AutoConfigureMockMvc(print = MockMvcPrint.NONE)
@TestPropertySource(properties = "app.storage.minio.enabled=true")
@Import({
        StoryCoverApiExceptionHandler.class,
        SecurityConfiguration.class,
        StoryCoverControllerTest.StoryCoverControllerTestConfiguration.class
})
class StoryCoverControllerTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final String VALID_ACCESS_TOKEN = "valid-access-token";
    private static final String INVALID_ACCESS_TOKEN = "invalid-access-token";
    private static final byte[] DISPLAY_BYTES = new byte[] {1, 2, 3, 4};
    private static final byte[] THUMBNAIL_BYTES = new byte[] {9, 8};

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeDownloadStoryCoverUseCase downloadStoryCoverUseCase;

    @Autowired
    private FakeUploadStoryCoverUseCase uploadStoryCoverUseCase;

    @Autowired
    private FakeRemoveStoryCoverUseCase removeStoryCoverUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @BeforeEach
    void resetFakes() {
        downloadStoryCoverUseCase.reset();
        uploadStoryCoverUseCase.reset();
        removeStoryCoverUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldDownloadDisplayStoryCoverWithPrivateHeaders()
            throws Exception {
        downloadStoryCoverUseCase.content = DISPLAY_BYTES;
        downloadStoryCoverUseCase.contentLength = 2_048L;

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/cover/display/{version}",
                        STORY_ID,
                        1768039200000L
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk())
                .andExpect(content().bytes(DISPLAY_BYTES))
                .andExpect(content().contentTypeCompatibleWith("image/jpeg"))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_LENGTH,
                        "2048"
                ))
                .andExpect(header().string(
                        HttpHeaders.CACHE_CONTROL,
                        "private, no-store"
                ))
                .andExpect(header().doesNotExist(
                        HttpHeaders.CONTENT_DISPOSITION
                ));

        assertThat(downloadStoryCoverUseCase.receivedAuthenticatedUser)
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(downloadStoryCoverUseCase.receivedStoryIds)
                .containsExactly(STORY_ID);
        assertThat(downloadStoryCoverUseCase.receivedRepresentations)
                .containsExactly(StoryCoverRepresentation.DISPLAY);
        assertThat(currentAuthenticatedUserProvider.callCount()).isEqualTo(1);
    }

    @Test
    void shouldDownloadThumbnailStoryCoverWithPrivateHeaders()
            throws Exception {
        downloadStoryCoverUseCase.content = THUMBNAIL_BYTES;
        downloadStoryCoverUseCase.contentLength = 360L;

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/cover/thumbnail/{version}",
                        STORY_ID,
                        1768039200000L
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk())
                .andExpect(content().bytes(THUMBNAIL_BYTES))
                .andExpect(content().contentTypeCompatibleWith("image/jpeg"))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_LENGTH,
                        "360"
                ))
                .andExpect(header().string(
                        HttpHeaders.CACHE_CONTROL,
                        "private, no-store"
                ));

        assertThat(downloadStoryCoverUseCase.receivedRepresentations)
                .containsExactly(StoryCoverRepresentation.THUMBNAIL);
    }

    @Test
    void shouldIgnoreVersionForStorageSelection() throws Exception {
        performSuccessfulGet(
                "/api/v1/stories/{storyId}/cover/display/{version}",
                1L
        );
        performSuccessfulGet(
                "/api/v1/stories/{storyId}/cover/display/{version}",
                999L
        );

        assertThat(downloadStoryCoverUseCase.receivedStoryIds)
                .containsExactly(STORY_ID, STORY_ID);
        assertThat(downloadStoryCoverUseCase.receivedRepresentations)
                .containsExactly(
                        StoryCoverRepresentation.DISPLAY,
                        StoryCoverRepresentation.DISPLAY
                );
    }

    @Test
    void shouldReturnNotFoundForMissingStoryNonParticipantOrNoExplicitCover()
            throws Exception {
        downloadStoryCoverUseCase.failWith(new StoryNotFoundException());

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/cover/display/{version}",
                        STORY_ID,
                        1L
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story cover could not be found"));
    }

    @Test
    void shouldReturnTechnicalFailureForMissingStorageObject()
            throws Exception {
        downloadStoryCoverUseCase.failWith(
                new StorageObjectNotFoundException()
        );

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/cover/display/{version}",
                        STORY_ID,
                        1L
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail")
                        .value("Story cover could not be streamed"));
    }

    @Test
    void shouldReturnTechnicalFailureForStorageFailure() throws Exception {
        downloadStoryCoverUseCase.failWith(new StorageException());

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/cover/thumbnail/{version}",
                        STORY_ID,
                        1L
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail")
                        .value("Story cover could not be streamed"));
    }

    @Test
    void shouldReturnBadRequestForMalformedVersion() throws Exception {
        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/cover/display/{version}",
                        STORY_ID,
                        "not-a-version"
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Invalid story cover request"));

        assertThat(downloadStoryCoverUseCase.callCount()).isZero();
    }

    @Test
    void shouldRequireAuthenticationForCoverReads() throws Exception {
        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/cover/display/{version}",
                        STORY_ID,
                        1L
                ))
                .andExpect(status().isUnauthorized());

        assertThat(downloadStoryCoverUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectInvalidBearerTokenBeforeUseCase() throws Exception {
        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/cover/display/{version}",
                        STORY_ID,
                        1L
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + INVALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
        assertThat(downloadStoryCoverUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldUploadStoryCoverAndReturnAuthoritativeStory() throws Exception {
        String response = mockMvc.perform(multipart(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .file(file("cover.png", "image/png", DISPLAY_BYTES))
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        })
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(
                        MediaType.APPLICATION_JSON
                ))
                .andExpect(jsonPath("$.id").value(STORY_ID.toString()))
                .andExpect(jsonPath("$.title").value("Returned Story"))
                .andExpect(jsonPath("$.role").value("OWNER"))
                .andExpect(jsonPath("$.previewPhoto.thumbnailUrl").value(
                        "/api/v1/stories/%s/cover/thumbnail/1768039200000"
                                .formatted(STORY_ID)
                ))
                .andExpect(jsonPath("$.previewPhoto.displayUrl").value(
                        "/api/v1/stories/%s/cover/display/1768039200000"
                                .formatted(STORY_ID)
                ))
                .andExpect(jsonPath("$.storageKey").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        UploadStoryCoverCommand command =
                uploadStoryCoverUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.coverObjectId()).isNotNull();
        assertThat(command.image().content()).containsExactly(DISPLAY_BYTES);
        assertThat(command.image().declaredContentType())
                .isEqualTo("image/png");
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(currentAuthenticatedUserProvider.callCount()).isEqualTo(1);
        assertThat(uploadStoryCoverUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain("storageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio");
    }

    @Test
    void shouldReturnNotFoundWhenUploadIsUnavailable() throws Exception {
        uploadStoryCoverUseCase.failWith(new StoryNotFoundException());

        mockMvc.perform(multipart(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .file(file("cover.png", "image/png", DISPLAY_BYTES))
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        })
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story cover could not be found"));
    }

    @Test
    void shouldReturnBadRequestForEmptyCoverUpload() throws Exception {
        mockMvc.perform(multipart(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .file(file("cover.png", "image/png", new byte[0]))
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        })
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Invalid story cover request"));

        assertThat(uploadStoryCoverUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestWhenCoverFilePartIsMissing() throws Exception {
        mockMvc.perform(multipart(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        })
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Invalid story cover request"));

        assertThat(uploadStoryCoverUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnBadRequestForInvalidImage() throws Exception {
        uploadStoryCoverUseCase.failWith(new InvalidImageException(
                InvalidImageReason.INVALID_IMAGE
        ));

        mockMvc.perform(multipart(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .file(file("cover.png", "image/png", DISPLAY_BYTES))
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        })
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Invalid story cover request"));
    }

    @Test
    void shouldReturnTechnicalFailureForImageProcessingFailure()
            throws Exception {
        uploadStoryCoverUseCase.failWith(new ImageProcessingException());

        mockMvc.perform(multipart(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .file(file("cover.png", "image/png", DISPLAY_BYTES))
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        })
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail")
                        .value("Story cover upload failed"));
    }

    @Test
    void shouldReturnTechnicalFailureForUploadStorageFailure()
            throws Exception {
        uploadStoryCoverUseCase.failWith(new StorageException());

        mockMvc.perform(multipart(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .file(file("cover.png", "image/png", DISPLAY_BYTES))
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        })
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail")
                        .value("Story cover could not be streamed"));
    }

    @Test
    void shouldRequireAuthenticationForCoverUpload() throws Exception {
        mockMvc.perform(multipart(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .file(file("cover.png", "image/png", DISPLAY_BYTES))
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        }))
                .andExpect(status().isUnauthorized());

        assertThat(uploadStoryCoverUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRemoveStoryCoverAndReturnAuthoritativeFallbackStory()
            throws Exception {
        removeStoryCoverUseCase.previewPhoto = new StoryPhotoPreview(
                "/api/v1/media/media-1/thumbnail",
                "/api/v1/media/media-1/display"
        );

        String response = mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(
                        MediaType.APPLICATION_JSON
                ))
                .andExpect(jsonPath("$.id").value(STORY_ID.toString()))
                .andExpect(jsonPath("$.title").value("Returned Story"))
                .andExpect(jsonPath("$.role").value("OWNER"))
                .andExpect(jsonPath("$.previewPhoto.thumbnailUrl").value(
                        "/api/v1/media/media-1/thumbnail"
                ))
                .andExpect(jsonPath("$.previewPhoto.displayUrl").value(
                        "/api/v1/media/media-1/display"
                ))
                .andExpect(jsonPath("$.storageKey").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        RemoveStoryCoverCommand command =
                removeStoryCoverUseCase.receivedCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(currentAuthenticatedUserProvider.callCount()).isEqualTo(1);
        assertThat(removeStoryCoverUseCase.callCount()).isEqualTo(1);
        assertThat(response)
                .doesNotContain("storageKey")
                .doesNotContain("bucket")
                .doesNotContain("minio");
    }

    @Test
    void shouldRemoveStoryCoverAndReturnAuthoritativeNoPhotoStory()
            throws Exception {
        removeStoryCoverUseCase.previewPhoto = null;

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.previewPhoto").value(nullValue()));
    }

    @Test
    void shouldReturnNotFoundWhenCoverRemovalIsUnavailable()
            throws Exception {
        removeStoryCoverUseCase.failWith(new StoryNotFoundException());

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story cover could not be found"));
    }

    @Test
    void shouldRequireAuthenticationForCoverRemoval() throws Exception {
        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/cover",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(removeStoryCoverUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new StoryCoverController(
                null,
                uploadStoryCoverUseCase,
                removeStoryCoverUseCase,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("downloadStoryCoverUseCase must not be null");
        assertThatThrownBy(() -> new StoryCoverController(
                downloadStoryCoverUseCase,
                null,
                removeStoryCoverUseCase,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("uploadStoryCoverUseCase must not be null");
        assertThatThrownBy(() -> new StoryCoverController(
                downloadStoryCoverUseCase,
                uploadStoryCoverUseCase,
                null,
                currentAuthenticatedUserProvider,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("removeStoryCoverUseCase must not be null");
        assertThatThrownBy(() -> new StoryCoverController(
                downloadStoryCoverUseCase,
                uploadStoryCoverUseCase,
                removeStoryCoverUseCase,
                null,
                Clock.fixed(CURRENT_TIME, ZoneOffset.UTC)
        )).isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "currentAuthenticatedUserProvider must not be null"
                );
        assertThatThrownBy(() -> new StoryCoverController(
                downloadStoryCoverUseCase,
                uploadStoryCoverUseCase,
                removeStoryCoverUseCase,
                currentAuthenticatedUserProvider,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    private void performSuccessfulGet(String path, long version)
            throws Exception {
        MvcResult result = mockMvc.perform(get(path, STORY_ID, version)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk());
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
    static class StoryCoverControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(CURRENT_TIME, ZoneOffset.UTC);
        }

        @Bean
        FakeDownloadStoryCoverUseCase downloadStoryCoverUseCase() {
            return new FakeDownloadStoryCoverUseCase();
        }

        @Bean
        FakeUploadStoryCoverUseCase uploadStoryCoverUseCase() {
            return new FakeUploadStoryCoverUseCase();
        }

        @Bean
        FakeRemoveStoryCoverUseCase removeStoryCoverUseCase() {
            return new FakeRemoveStoryCoverUseCase();
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

    static final class FakeRemoveStoryCoverUseCase
            implements RemoveStoryCoverUseCase {

        private RemoveStoryCoverCommand receivedCommand;
        private RuntimeException exception;
        private StoryPhotoPreview previewPhoto = new StoryPhotoPreview(
                "/api/v1/media/media-1/thumbnail",
                "/api/v1/media/media-1/display"
        );
        private int callCount;

        @Override
        public UserStory removeStoryCover(RemoveStoryCoverCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return userStory(previewPhoto);
        }

        private RemoveStoryCoverCommand receivedCommand() {
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
            previewPhoto = new StoryPhotoPreview(
                    "/api/v1/media/media-1/thumbnail",
                    "/api/v1/media/media-1/display"
            );
            callCount = 0;
        }
    }

    static final class FakeUploadStoryCoverUseCase
            implements UploadStoryCoverUseCase {

        private UploadStoryCoverCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public UserStory uploadStoryCover(UploadStoryCoverCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return userStory(new StoryPhotoPreview(
                    "/api/v1/stories/%s/cover/thumbnail/%d"
                            .formatted(
                                    STORY_ID,
                                    CURRENT_TIME.toEpochMilli()
                            ),
                    "/api/v1/stories/%s/cover/display/%d"
                            .formatted(
                                    STORY_ID,
                                    CURRENT_TIME.toEpochMilli()
                            )
            ));
        }

        private UploadStoryCoverCommand receivedCommand() {
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

    private static UserStory userStory(StoryPhotoPreview previewPhoto) {
        return new UserStory(
                new Story(
                        STORY_ID,
                        USER_ID,
                        "Returned Story",
                        "Returned description",
                        null,
                        CURRENT_TIME,
                        CURRENT_TIME
                ),
                StoryRole.OWNER,
                3,
                2,
                previewPhoto
        );
    }

    static final class FakeDownloadStoryCoverUseCase
            implements DownloadStoryCoverUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private final List<UUID> receivedStoryIds = new ArrayList<>();
        private final List<StoryCoverRepresentation> receivedRepresentations =
                new ArrayList<>();
        private byte[] content = DISPLAY_BYTES;
        private long contentLength = DISPLAY_BYTES.length;
        private RuntimeException exception;
        private int callCount;

        @Override
        public DownloadedStoryCover downloadStoryCover(
                AuthenticatedUser authenticatedUser,
                UUID storyId,
                StoryCoverRepresentation representation
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedStoryIds.add(storyId);
            receivedRepresentations.add(representation);
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return new DownloadedStoryCover(
                    new ByteArrayInputStream(content),
                    contentLength,
                    "image/jpeg"
            );
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedStoryIds.clear();
            receivedRepresentations.clear();
            content = DISPLAY_BYTES;
            contentLength = DISPLAY_BYTES.length;
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
}
