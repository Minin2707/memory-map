package memory_map.backend.music.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.auth.security.SecurityConfiguration;
import memory_map.backend.music.application.ListAvailableMusicTracksUseCase;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
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
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(MusicController.class)
@AutoConfigureMockMvc
@Import({
        SecurityConfiguration.class,
        MusicControllerTest.MusicControllerTestConfiguration.class
})
class MusicControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeListAvailableMusicTracksUseCase
            listAvailableMusicTracksUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID FIRST_TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID SECOND_TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000022");
    private static final Instant TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final String VALID_ACCESS_TOKEN = "valid-access-token";
    private static final String INVALID_ACCESS_TOKEN = "invalid-access-token";

    @BeforeEach
    void resetFakes() {
        listAvailableMusicTracksUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldReturnAuthenticatedActiveCatalogWithSafeFields()
            throws Exception {

        String response = mockMvc.perform(get("/api/v1/music/tracks")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(
                        org.springframework.http.MediaType.APPLICATION_JSON
                ))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id")
                        .value(FIRST_TRACK_ID.toString()))
                .andExpect(jsonPath("$[0].title").value("Calm Piano"))
                .andExpect(jsonPath("$[0].artist").value("Memory Story"))
                .andExpect(jsonPath("$[0].durationSeconds").value(180))
                .andExpect(jsonPath("$[0].status").doesNotExist())
                .andExpect(jsonPath("$[0].sortOrder").doesNotExist())
                .andExpect(jsonPath("$[0].storageKey").doesNotExist())
                .andExpect(jsonPath("$[0].mimeType").doesNotExist())
                .andExpect(jsonPath("$[0].fileSize").doesNotExist())
                .andExpect(jsonPath("$[0].createdAt").doesNotExist())
                .andExpect(jsonPath("$[0].updatedAt").doesNotExist())
                .andExpect(jsonPath("$[1].id")
                        .value(SECOND_TRACK_ID.toString()))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(listAvailableMusicTracksUseCase.callCount())
                .isEqualTo(1);
        assertThat(listAvailableMusicTracksUseCase
                .receivedAuthenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(response)
                .doesNotContain("ACTIVE")
                .doesNotContain("DISABLED")
                .doesNotContain("sortOrder")
                .doesNotContain("music/calm-piano.mp3")
                .doesNotContain("audio/mpeg")
                .doesNotContain("4096")
                .doesNotContain("storage")
                .doesNotContain("bucket")
                .doesNotContain("minio")
                .doesNotContain("provider");
    }

    @Test
    void shouldPreserveApplicationOrder() throws Exception {
        mockMvc.perform(get("/api/v1/music/tracks")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id")
                        .value(FIRST_TRACK_ID.toString()))
                .andExpect(jsonPath("$[1].id")
                        .value(SECOND_TRACK_ID.toString()));
    }

    @Test
    void shouldReturnEmptyCatalog() throws Exception {
        listAvailableMusicTracksUseCase.tracks(List.of());

        mockMvc.perform(get("/api/v1/music/tracks")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + VALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isOk())
                .andExpect(content().string("[]"));
    }

    @Test
    void shouldRejectUnauthenticatedCatalogRequest() throws Exception {
        mockMvc.perform(get("/api/v1/music/tracks"))
                .andExpect(status().isUnauthorized());

        assertThat(listAvailableMusicTracksUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectInvalidBearerToken() throws Exception {
        String response = mockMvc.perform(get("/api/v1/music/tracks")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + INVALID_ACCESS_TOKEN
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response).doesNotContain(INVALID_ACCESS_TOKEN);
        assertThat(listAvailableMusicTracksUseCase.callCount()).isZero();
        assertThat(currentAuthenticatedUserProvider.callCount()).isZero();
    }

    @Test
    void shouldRejectNullDependencies() {
        assertThatThrownBy(() -> new MusicController(
                null,
                currentAuthenticatedUserProvider
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("listAvailableMusicTracksUseCase must not be null");

        assertThatThrownBy(() -> new MusicController(
                listAvailableMusicTracksUseCase,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "currentAuthenticatedUserProvider must not be null"
                );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class MusicControllerTestConfiguration {

        @Bean
        FakeListAvailableMusicTracksUseCase
        listAvailableMusicTracksUseCase() {
            return new FakeListAvailableMusicTracksUseCase();
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
                        .issuedAt(TIME)
                        .expiresAt(TIME.plusSeconds(900))
                        .build();
            };
        }
    }

    static final class FakeListAvailableMusicTracksUseCase
            implements ListAvailableMusicTracksUseCase {

        private AuthenticatedUser receivedAuthenticatedUser;
        private int callCount;
        private List<MusicTrack> tracks = List.of(
                musicTrack(FIRST_TRACK_ID, "Calm Piano", 0),
                musicTrack(SECOND_TRACK_ID, "Soft Rain", 1)
        );

        @Override
        public List<MusicTrack> listAvailableMusicTracks(
                AuthenticatedUser authenticatedUser
        ) {
            receivedAuthenticatedUser = authenticatedUser;
            callCount++;

            return tracks;
        }

        private AuthenticatedUser receivedAuthenticatedUser() {
            return receivedAuthenticatedUser;
        }

        private int callCount() {
            return callCount;
        }

        private void tracks(List<MusicTrack> tracks) {
            this.tracks = Objects.requireNonNull(tracks);
        }

        private void reset() {
            receivedAuthenticatedUser = null;
            callCount = 0;
            tracks = List.of(
                    musicTrack(FIRST_TRACK_ID, "Calm Piano", 0),
                    musicTrack(SECOND_TRACK_ID, "Soft Rain", 1)
            );
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

    private static MusicTrack musicTrack(
            UUID id,
            String title,
            int sortOrder
    ) {
        return new MusicTrack(
                id,
                title,
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                sortOrder,
                "music/" + title.toLowerCase().replace(" ", "-") + ".mp3",
                "audio/mpeg",
                4_096L,
                TIME,
                TIME
        );
    }
}
