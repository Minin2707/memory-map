package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageException;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.music.application.GetStorySoundtrackAudioUseCase;
import memory_map.backend.music.application.InvalidStorySoundtrackAudioRangeException;
import memory_map.backend.music.application.RemoveStorySoundtrackCommand;
import memory_map.backend.music.application.RemoveStorySoundtrackUseCase;
import memory_map.backend.music.application.ResolveStorySoundtrackUseCase;
import memory_map.backend.music.application.SetStorySoundtrackCommand;
import memory_map.backend.music.application.SetStorySoundtrackUseCase;
import memory_map.backend.music.application.StorySoundtrack;
import memory_map.backend.music.application.StorySoundtrackAudio;
import memory_map.backend.music.application.StorySoundtrackAudioRange;
import memory_map.backend.music.application.StorySoundtrackAudioUnavailableException;
import memory_map.backend.music.application.StorySoundtrackUnavailableException;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.story.application.StoryNotFoundException;
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
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(StorySoundtrackController.class)
@AutoConfigureMockMvc
@Import({
        StorySoundtrackApiExceptionHandler.class,
        SecurityConfiguration.class,
        StorySoundtrackControllerTest.StorySoundtrackControllerTestConfiguration.class
})
class StorySoundtrackControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeResolveStorySoundtrackUseCase
            resolveStorySoundtrackUseCase;

    @Autowired
    private FakeSetStorySoundtrackUseCase setStorySoundtrackUseCase;

    @Autowired
    private FakeRemoveStorySoundtrackUseCase removeStorySoundtrackUseCase;

    @Autowired
    private FakeGetStorySoundtrackAudioUseCase
            getStorySoundtrackAudioUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @Autowired
    private Clock clock;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final String VALID_ACCESS_TOKEN = "valid-access-token";
    private static final String INVALID_ACCESS_TOKEN = "invalid-access-token";
    private static final byte[] AUDIO_BYTES = new byte[] {1, 2, 3, 4};
    private static final byte[] RANGED_AUDIO_BYTES = new byte[] {2, 3};

    @BeforeEach
    void resetFakes() {
        resolveStorySoundtrackUseCase.reset();
        setStorySoundtrackUseCase.reset();
        removeStorySoundtrackUseCase.reset();
        getStorySoundtrackAudioUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldGetActiveStorySoundtrack() throws Exception {
        resolveStorySoundtrackUseCase.storySoundtrack(
                StorySoundtrack.selected(activeTrack())
        );

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack",
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
                .andExpect(jsonPath("$.selectedSoundtrack.id")
                        .value(TRACK_ID.toString()))
                .andExpect(jsonPath("$.selectedSoundtrack.title")
                        .value("Calm Piano"))
                .andExpect(jsonPath("$.selectedSoundtrack.artist")
                        .value("Memory Story"))
                .andExpect(jsonPath("$.selectedSoundtrack.durationSeconds")
                        .value(180))
                .andExpect(jsonPath("$.effectiveSoundtrack.id")
                        .value(TRACK_ID.toString()))
                .andExpect(jsonPath("$.selectedSoundtrack.status")
                        .doesNotExist())
                .andExpect(jsonPath("$.selectedSoundtrack.storageKey")
                        .doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(resolveStorySoundtrackUseCase.callCount()).isEqualTo(1);
        assertThat(resolveStorySoundtrackUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(resolveStorySoundtrackUseCase.receivedStoryId())
                .isEqualTo(STORY_ID);
        assertSafeResponse(response);
    }

    @Test
    void shouldGetNoMusicStorySoundtrack() throws Exception {
        resolveStorySoundtrackUseCase.storySoundtrack(
                StorySoundtrack.noMusic()
        );

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.selectedSoundtrack")
                        .value((Object) null))
                .andExpect(jsonPath("$.effectiveSoundtrack")
                        .value((Object) null));
    }

    @Test
    void shouldGetDisabledSelectedStorySoundtrackWithoutEffectiveTrack()
            throws Exception {

        resolveStorySoundtrackUseCase.storySoundtrack(
                StorySoundtrack.selected(disabledTrack())
        );

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.selectedSoundtrack.id")
                        .value(TRACK_ID.toString()))
                .andExpect(jsonPath("$.effectiveSoundtrack")
                        .value((Object) null))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain("DISABLED")
                .doesNotContain("status");
        assertSafeResponse(response);
    }

    @Test
    void shouldStreamFullStorySoundtrackAudio() throws Exception {
        getStorySoundtrackAudioUseCase.audio(fullAudio());

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk())
                .andExpect(content().contentType("audio/mpeg"))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_LENGTH,
                        Long.toString(AUDIO_BYTES.length)
                ))
                .andExpect(header().string("Accept-Ranges", "bytes"))
                .andExpect(header().string(
                        HttpHeaders.CACHE_CONTROL,
                        "private, no-store"
                ))
                .andExpect(header().doesNotExist(
                        HttpHeaders.CONTENT_DISPOSITION
                ))
                .andExpect(content().bytes(AUDIO_BYTES));

        assertThat(getStorySoundtrackAudioUseCase.callCount()).isEqualTo(1);
        assertThat(getStorySoundtrackAudioUseCase.receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(getStorySoundtrackAudioUseCase.receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(getStorySoundtrackAudioUseCase.receivedRange()).isNull();
    }

    @Test
    void shouldStreamStartEndStorySoundtrackAudioRange() throws Exception {
        getStorySoundtrackAudioUseCase.audio(rangedAudio(
                new StorageByteRange(1L, 2L)
        ));

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(HttpHeaders.RANGE, "bytes=1-2")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isPartialContent())
                .andExpect(content().contentType("audio/mpeg"))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_LENGTH,
                        Long.toString(RANGED_AUDIO_BYTES.length)
                ))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_RANGE,
                        "bytes 1-2/4"
                ))
                .andExpect(header().string("Accept-Ranges", "bytes"))
                .andExpect(header().string(
                        HttpHeaders.CACHE_CONTROL,
                        "private, no-store"
                ))
                .andExpect(header().doesNotExist(
                        HttpHeaders.CONTENT_DISPOSITION
                ))
                .andExpect(content().bytes(RANGED_AUDIO_BYTES));

        assertThat(getStorySoundtrackAudioUseCase.receivedRange())
                .isEqualTo(StorySoundtrackAudioRange.startEnd(1L, 2L));
    }

    @Test
    void shouldStreamOpenEndedStorySoundtrackAudioRange() throws Exception {
        getStorySoundtrackAudioUseCase.audio(rangedAudio(
                new StorageByteRange(2L, 2L)
        ));

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(HttpHeaders.RANGE, "bytes=2-")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isPartialContent())
                .andExpect(header().string(
                        HttpHeaders.CONTENT_RANGE,
                        "bytes 2-3/4"
                ))
                .andExpect(content().bytes(RANGED_AUDIO_BYTES));

        assertThat(getStorySoundtrackAudioUseCase.receivedRange())
                .isEqualTo(StorySoundtrackAudioRange.openEnded(2L));
    }

    @Test
    void shouldStreamSuffixStorySoundtrackAudioRange() throws Exception {
        getStorySoundtrackAudioUseCase.audio(rangedAudio(
                new StorageByteRange(2L, 2L)
        ));

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(HttpHeaders.RANGE, "bytes=-2")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isPartialContent())
                .andExpect(header().string(
                        HttpHeaders.CONTENT_RANGE,
                        "bytes 2-3/4"
                ))
                .andExpect(content().bytes(RANGED_AUDIO_BYTES));

        assertThat(getStorySoundtrackAudioUseCase.receivedRange())
                .isEqualTo(StorySoundtrackAudioRange.suffix(2L));
    }

    @Test
    void shouldStreamClampedStorySoundtrackAudioRange() throws Exception {
        getStorySoundtrackAudioUseCase.audio(rangedAudio(
                new StorageByteRange(2L, 2L)
        ));

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(HttpHeaders.RANGE, "bytes=2-99")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isPartialContent())
                .andExpect(header().string(
                        HttpHeaders.CONTENT_RANGE,
                        "bytes 2-3/4"
                ))
                .andExpect(content().bytes(RANGED_AUDIO_BYTES));

        assertThat(getStorySoundtrackAudioUseCase.receivedRange())
                .isEqualTo(StorySoundtrackAudioRange.startEnd(2L, 99L));
    }

    @Test
    void shouldReturnBadRequestForMalformedAudioRange() throws Exception {
        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(HttpHeaders.RANGE, "nonsense")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Story soundtrack audio range is invalid"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(getStorySoundtrackAudioUseCase.callCount()).isZero();
        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain("storageKey")
                .doesNotContain("bytes=");
    }

    @Test
    void shouldReturnBadRequestForMultipleAudioRanges() throws Exception {
        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(HttpHeaders.RANGE, "bytes=0-1,2-3")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Story soundtrack audio range is invalid"));

        assertThat(getStorySoundtrackAudioUseCase.callCount()).isZero();
    }

    @Test
    void shouldReturnRangeNotSatisfiableForUnsatisfiableAudioRange()
            throws Exception {

        getStorySoundtrackAudioUseCase.failWith(
                new InvalidStorySoundtrackAudioRangeException(4L)
        );

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(HttpHeaders.RANGE, "bytes=99-")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().is(416))
                .andExpect(header().string(
                        HttpHeaders.CONTENT_RANGE,
                        "bytes */4"
                ))
                .andExpect(jsonPath("$.detail")
                        .value(
                                "Story soundtrack audio range is not "
                                        + "satisfiable"
                        ))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain("storageKey");
    }

    @Test
    void shouldReturnNotFoundWhenStorySoundtrackAudioIsUnavailable()
            throws Exception {

        getStorySoundtrackAudioUseCase.failWith(
                new StorySoundtrackAudioUnavailableException()
        );

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story soundtrack audio could not be found"));
    }

    @Test
    void shouldMapDeniedAudioToSafeStoryNotFound() throws Exception {
        getStorySoundtrackAudioUseCase.failWith(new StoryNotFoundException());

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story was not found"));
    }

    @Test
    void shouldMapMissingAudioStorageObjectToSafeNotFound()
            throws Exception {

        getStorySoundtrackAudioUseCase.failWith(
                new StorageObjectNotFoundException()
        );

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story soundtrack audio could not be found"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain("StorageObjectNotFoundException")
                .doesNotContain("storageKey")
                .doesNotContain("minio");
    }

    @Test
    void shouldReturnTechnicalFailureForAudioStorageFailure()
            throws Exception {

        getStorySoundtrackAudioUseCase.failWith(new StorageException());

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail")
                        .value(
                                "Story soundtrack audio could not be streamed"
                        ))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain("StorageException")
                .doesNotContain("storageKey")
                .doesNotContain("minio");
    }

    @Test
    void shouldCloseAudioStreamAfterStreaming() throws Exception {
        CloseTrackingInputStream stream =
                new CloseTrackingInputStream(AUDIO_BYTES);
        getStorySoundtrackAudioUseCase.audio(new StorySoundtrackAudio(
                stream,
                "audio/mpeg",
                AUDIO_BYTES.length,
                AUDIO_BYTES.length,
                null
        ));

        MvcResult result = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk())
                .andExpect(content().bytes(AUDIO_BYTES));

        assertThat(stream.closed()).isTrue();
    }

    @Test
    void shouldReturnNotFoundWhenStorySoundtrackIsUnavailable()
            throws Exception {

        resolveStorySoundtrackUseCase.failWith(new StoryNotFoundException());

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(content().contentTypeCompatibleWith(
                        MediaType.APPLICATION_PROBLEM_JSON
                ))
                .andExpect(jsonPath("$.title").value("Not Found"))
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.detail")
                        .value("Story was not found"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/stories/soundtrack"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("forbidden")
                .doesNotContain("access denied")
                .doesNotContain("StoryNotFoundException")
                .doesNotContain("stackTrace")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc")
                .doesNotContain("repository");
    }

    @Test
    void shouldReturnInternalServerErrorForBrokenSelectedReference()
            throws Exception {

        resolveStorySoundtrackUseCase.failWith(new IllegalStateException(
                "Selected Story soundtrack could not be resolved"
        ));

        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.detail")
                        .value("Story soundtrack could not be resolved"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain("Selected Story soundtrack")
                .doesNotContain("IllegalStateException")
                .doesNotContain("stackTrace");
    }

    @Test
    void shouldSetStorySoundtrack() throws Exception {
        setStorySoundtrackUseCase.storySoundtrack(
                StorySoundtrack.selected(activeTrack())
        );

        String response = mockMvc.perform(put(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "musicTrackId": "%s"
                                }
                                """.formatted(TRACK_ID))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.selectedSoundtrack.id")
                        .value(TRACK_ID.toString()))
                .andExpect(jsonPath("$.effectiveSoundtrack.id")
                        .value(TRACK_ID.toString()))
                .andReturn()
                .getResponse()
                .getContentAsString();

        SetStorySoundtrackCommand command =
                setStorySoundtrackUseCase.receivedCommand();
        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.musicTrackId()).isEqualTo(TRACK_ID);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertSafeResponse(response);
    }

    @Test
    void shouldReturnOkForIdempotentSetStorySoundtrack() throws Exception {
        setStorySoundtrackUseCase.storySoundtrack(
                StorySoundtrack.selected(activeTrack())
        );

        mockMvc.perform(put(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "musicTrackId": "%s"
                                }
                                """.formatted(TRACK_ID))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.selectedSoundtrack.id")
                        .value(TRACK_ID.toString()))
                .andExpect(jsonPath("$.effectiveSoundtrack.id")
                        .value(TRACK_ID.toString()));
    }

    @Test
    void shouldMapUnavailableOrDisabledTrackToSafeNotFound()
            throws Exception {

        setStorySoundtrackUseCase.failWith(
                new StorySoundtrackUnavailableException()
        );

        String response = mockMvc.perform(put(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "musicTrackId": "%s"
                                }
                                """.formatted(TRACK_ID))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story soundtrack could not be updated"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(TRACK_ID.toString())
                .doesNotContain("DISABLED")
                .doesNotContain("missing");
    }

    @Test
    void shouldMapDeniedSetToSafeStoryNotFound() throws Exception {
        setStorySoundtrackUseCase.failWith(new StoryNotFoundException());

        mockMvc.perform(put(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "musicTrackId": "%s"
                                }
                                """.formatted(TRACK_ID))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story was not found"));
    }

    @Test
    void shouldRejectNullMusicTrackIdRequest() throws Exception {
        mockMvc.perform(put(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "musicTrackId": null
                                }
                                """)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail")
                        .value("Invalid story soundtrack request"));

        assertThat(setStorySoundtrackUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectMalformedSetRequest() throws Exception {
        mockMvc.perform(put(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "musicTrackId": "%s",
                                }
                                """.formatted(TRACK_ID))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(setStorySoundtrackUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectMalformedStoryIdBeforeUseCase() throws Exception {
        mockMvc.perform(put("/api/v1/stories/not-a-uuid/soundtrack")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "musicTrackId": "%s"
                                }
                                """.formatted(TRACK_ID))
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isBadRequest());

        assertThat(setStorySoundtrackUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRemoveStorySoundtrack() throws Exception {
        removeStorySoundtrackUseCase.storySoundtrack(
                StorySoundtrack.noMusic()
        );

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.selectedSoundtrack")
                        .value((Object) null))
                .andExpect(jsonPath("$.effectiveSoundtrack")
                        .value((Object) null));

        RemoveStorySoundtrackCommand command =
                removeStorySoundtrackUseCase.receivedCommand();
        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnOkForAlreadyNoMusicRemove() throws Exception {
        removeStorySoundtrackUseCase.storySoundtrack(
                StorySoundtrack.noMusic()
        );

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.selectedSoundtrack")
                        .value((Object) null))
                .andExpect(jsonPath("$.effectiveSoundtrack")
                        .value((Object) null));
    }

    @Test
    void shouldRemoveDisabledSelectedTrackThroughApplicationResult()
            throws Exception {

        removeStorySoundtrackUseCase.storySoundtrack(
                StorySoundtrack.noMusic()
        );

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.selectedSoundtrack")
                        .value((Object) null))
                .andExpect(jsonPath("$.effectiveSoundtrack")
                        .value((Object) null));

        assertThat(removeStorySoundtrackUseCase.callCount()).isEqualTo(1);
    }

    @Test
    void shouldMapDeniedRemoveToSafeStoryNotFound() throws Exception {
        removeStorySoundtrackUseCase.failWith(new StoryNotFoundException());

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail")
                        .value("Story was not found"));
    }

    @Test
    void shouldRequireAuthenticationForAllEndpoints() throws Exception {
        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack/audio",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(put(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "musicTrackId": "%s"
                                }
                                """.formatted(TRACK_ID)))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(delete(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
                ))
                .andExpect(status().isUnauthorized());

        assertThat(resolveStorySoundtrackUseCase.callCount()).isZero();
        assertThat(getStorySoundtrackAudioUseCase.callCount()).isZero();
        assertThat(setStorySoundtrackUseCase.callCount()).isZero();
        assertThat(removeStorySoundtrackUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectInvalidBearerTokenBeforeUseCase() throws Exception {
        String response = mockMvc.perform(get(
                        "/api/v1/stories/{storyId}/soundtrack",
                        STORY_ID
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
        assertThat(resolveStorySoundtrackUseCase.callCount()).isZero();
        assertThat(getStorySoundtrackAudioUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new StorySoundtrackController(
                null,
                setStorySoundtrackUseCase,
                removeStorySoundtrackUseCase,
                getStorySoundtrackAudioUseCase,
                currentAuthenticatedUserProvider,
                clock
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("resolveStorySoundtrackUseCase must not be null");

        assertThatThrownBy(() -> new StorySoundtrackController(
                resolveStorySoundtrackUseCase,
                null,
                removeStorySoundtrackUseCase,
                getStorySoundtrackAudioUseCase,
                currentAuthenticatedUserProvider,
                clock
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("setStorySoundtrackUseCase must not be null");

        assertThatThrownBy(() -> new StorySoundtrackController(
                resolveStorySoundtrackUseCase,
                setStorySoundtrackUseCase,
                null,
                getStorySoundtrackAudioUseCase,
                currentAuthenticatedUserProvider,
                clock
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("removeStorySoundtrackUseCase must not be null");

        assertThatThrownBy(() -> new StorySoundtrackController(
                resolveStorySoundtrackUseCase,
                setStorySoundtrackUseCase,
                removeStorySoundtrackUseCase,
                null,
                currentAuthenticatedUserProvider,
                clock
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("getStorySoundtrackAudioUseCase must not be null");

        assertThatThrownBy(() -> new StorySoundtrackController(
                resolveStorySoundtrackUseCase,
                setStorySoundtrackUseCase,
                removeStorySoundtrackUseCase,
                getStorySoundtrackAudioUseCase,
                null,
                clock
        )).isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "currentAuthenticatedUserProvider must not be null"
                );

        assertThatThrownBy(() -> new StorySoundtrackController(
                resolveStorySoundtrackUseCase,
                setStorySoundtrackUseCase,
                removeStorySoundtrackUseCase,
                getStorySoundtrackAudioUseCase,
                currentAuthenticatedUserProvider,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    private static void assertSafeResponse(String response) {
        assertThat(response)
                .doesNotContain("status")
                .doesNotContain("sortOrder")
                .doesNotContain("storageKey")
                .doesNotContain("music/calm-piano.mp3")
                .doesNotContain("mimeType")
                .doesNotContain("audio/mpeg")
                .doesNotContain("fileSize")
                .doesNotContain("4096")
                .doesNotContain("createdAt")
                .doesNotContain("updatedAt")
                .doesNotContain("bucket")
                .doesNotContain("minio")
                .doesNotContain("provider");
    }

    private static MusicTrack activeTrack() {
        return musicTrack(MusicTrackStatus.ACTIVE);
    }

    private static MusicTrack disabledTrack() {
        return musicTrack(MusicTrackStatus.DISABLED);
    }

    private static MusicTrack musicTrack(MusicTrackStatus status) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                status,
                7,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    private static StorySoundtrackAudio fullAudio() {
        return new StorySoundtrackAudio(
                new ByteArrayInputStream(AUDIO_BYTES),
                "audio/mpeg",
                AUDIO_BYTES.length,
                AUDIO_BYTES.length,
                null
        );
    }

    private static StorySoundtrackAudio rangedAudio(StorageByteRange range) {
        return new StorySoundtrackAudio(
                new ByteArrayInputStream(RANGED_AUDIO_BYTES),
                "audio/mpeg",
                RANGED_AUDIO_BYTES.length,
                AUDIO_BYTES.length,
                range
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class StorySoundtrackControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(CURRENT_TIME, ZoneOffset.UTC);
        }

        @Bean
        FakeResolveStorySoundtrackUseCase resolveStorySoundtrackUseCase() {
            return new FakeResolveStorySoundtrackUseCase();
        }

        @Bean
        FakeSetStorySoundtrackUseCase setStorySoundtrackUseCase() {
            return new FakeSetStorySoundtrackUseCase();
        }

        @Bean
        FakeRemoveStorySoundtrackUseCase removeStorySoundtrackUseCase() {
            return new FakeRemoveStorySoundtrackUseCase();
        }

        @Bean
        FakeGetStorySoundtrackAudioUseCase getStorySoundtrackAudioUseCase() {
            return new FakeGetStorySoundtrackAudioUseCase();
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

    static final class FakeResolveStorySoundtrackUseCase
            implements ResolveStorySoundtrackUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedStoryId;
        private StorySoundtrack storySoundtrack = StorySoundtrack.noMusic();
        private RuntimeException exception;
        private int callCount;

        @Override
        public StorySoundtrack resolveStorySoundtrack(
                AuthenticatedUser authenticatedUser,
                UUID storyId
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedStoryId = storyId;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return storySoundtrack;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private int callCount() {
            return callCount;
        }

        private void storySoundtrack(StorySoundtrack storySoundtrack) {
            this.storySoundtrack = storySoundtrack;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedStoryId = null;
            storySoundtrack = StorySoundtrack.noMusic();
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeSetStorySoundtrackUseCase
            implements SetStorySoundtrackUseCase {

        private SetStorySoundtrackCommand receivedCommand;
        private StorySoundtrack storySoundtrack = StorySoundtrack.noMusic();
        private RuntimeException exception;
        private int callCount;

        @Override
        public StorySoundtrack setStorySoundtrack(
                SetStorySoundtrackCommand command
        ) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return storySoundtrack;
        }

        private SetStorySoundtrackCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void storySoundtrack(StorySoundtrack storySoundtrack) {
            this.storySoundtrack = storySoundtrack;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedCommand = null;
            storySoundtrack = StorySoundtrack.noMusic();
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeRemoveStorySoundtrackUseCase
            implements RemoveStorySoundtrackUseCase {

        private RemoveStorySoundtrackCommand receivedCommand;
        private StorySoundtrack storySoundtrack = StorySoundtrack.noMusic();
        private RuntimeException exception;
        private int callCount;

        @Override
        public StorySoundtrack removeStorySoundtrack(
                RemoveStorySoundtrackCommand command
        ) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return storySoundtrack;
        }

        private RemoveStorySoundtrackCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void storySoundtrack(StorySoundtrack storySoundtrack) {
            this.storySoundtrack = storySoundtrack;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedCommand = null;
            storySoundtrack = StorySoundtrack.noMusic();
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeGetStorySoundtrackAudioUseCase
            implements GetStorySoundtrackAudioUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private UUID receivedStoryId;
        private StorySoundtrackAudioRange receivedRange;
        private StorySoundtrackAudio audio = fullAudio();
        private RuntimeException exception;
        private int callCount;

        @Override
        public StorySoundtrackAudio getStorySoundtrackAudio(
                AuthenticatedUser authenticatedUser,
                UUID storyId,
                StorySoundtrackAudioRange range
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            receivedStoryId = storyId;
            receivedRange = range;
            callCount++;

            if (exception != null) {
                throw exception;
            }

            return audio;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private StorySoundtrackAudioRange receivedRange() {
            return receivedRange;
        }

        private int callCount() {
            return callCount;
        }

        private void audio(StorySoundtrackAudio audio) {
            this.audio = audio;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            receivedStoryId = null;
            receivedRange = null;
            audio = fullAudio();
            exception = null;
            callCount = 0;
        }
    }

    static final class CloseTrackingInputStream extends ByteArrayInputStream {

        private boolean closed;

        private CloseTrackingInputStream(byte[] content) {
            super(content);
        }

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }

        private boolean closed() {
            return closed;
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
