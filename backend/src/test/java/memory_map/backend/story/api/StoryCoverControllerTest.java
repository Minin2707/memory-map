package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.story.application.DownloadStoryCoverUseCase;
import memory_map.backend.story.application.DownloadedStoryCover;
import memory_map.backend.story.application.StoryCoverRepresentation;
import memory_map.backend.story.application.StoryNotFoundException;
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
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @BeforeEach
    void resetFakes() {
        downloadStoryCoverUseCase.reset();
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
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new StoryCoverController(
                null,
                currentAuthenticatedUserProvider
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("downloadStoryCoverUseCase must not be null");
        assertThatThrownBy(() -> new StoryCoverController(
                downloadStoryCoverUseCase,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "currentAuthenticatedUserProvider must not be null"
                );
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

    @TestConfiguration(proxyBeanMethods = false)
    static class StoryCoverControllerTestConfiguration {

        @Bean
        FakeDownloadStoryCoverUseCase downloadStoryCoverUseCase() {
            return new FakeDownloadStoryCoverUseCase();
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
