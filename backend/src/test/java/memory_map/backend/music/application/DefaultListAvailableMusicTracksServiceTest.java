package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.music.repository.MusicTrackRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultListAvailableMusicTracksServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldReturnRepositoryActiveTracks() {
        FakeMusicTrackRepository repository = new FakeMusicTrackRepository();
        List<MusicTrack> tracks = List.of(
                musicTrack("00000000-0000-0000-0000-000000000011", 0),
                musicTrack("00000000-0000-0000-0000-000000000012", 1)
        );
        repository.activeTracks = tracks;

        List<MusicTrack> result = new DefaultListAvailableMusicTracksService(
                repository
        ).listAvailableMusicTracks(new AuthenticatedUser(USER_ID));

        assertThat(result).isSameAs(tracks);
        assertThat(repository.findActiveCallCount).isEqualTo(1);
    }

    @Test
    void shouldPreserveRepositoryOrdering() {
        FakeMusicTrackRepository repository = new FakeMusicTrackRepository();
        MusicTrack second = musicTrack(
                "00000000-0000-0000-0000-000000000012",
                1
        );
        MusicTrack first = musicTrack(
                "00000000-0000-0000-0000-000000000011",
                0
        );
        repository.activeTracks = List.of(first, second);

        List<MusicTrack> result = new DefaultListAvailableMusicTracksService(
                repository
        ).listAvailableMusicTracks(new AuthenticatedUser(USER_ID));

        assertThat(result).containsExactly(first, second);
    }

    @Test
    void shouldSupportEmptyCatalog() {
        FakeMusicTrackRepository repository = new FakeMusicTrackRepository();
        repository.activeTracks = List.of();

        List<MusicTrack> result = new DefaultListAvailableMusicTracksService(
                repository
        ).listAvailableMusicTracks(new AuthenticatedUser(USER_ID));

        assertThat(result).isEmpty();
    }

    @Test
    void shouldRejectNullDependency() {
        assertThatThrownBy(() -> new DefaultListAvailableMusicTracksService(
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrackRepository must not be null");
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {
        assertThatThrownBy(() -> new DefaultListAvailableMusicTracksService(
                new FakeMusicTrackRepository()
        ).listAvailableMusicTracks(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    private static MusicTrack musicTrack(String id, int sortOrder) {
        return new MusicTrack(
                UUID.fromString(id),
                "Track " + sortOrder,
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                sortOrder,
                "music/" + id + ".mp3",
                "audio/mpeg",
                4_096L,
                TIME,
                TIME
        );
    }

    private static final class FakeMusicTrackRepository
            implements MusicTrackRepository {

        private List<MusicTrack> activeTracks = new ArrayList<>();
        private int findActiveCallCount;

        @Override
        public Optional<MusicTrack> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<MusicTrack> findActive() {
            findActiveCallCount++;
            return activeTracks;
        }
    }
}
