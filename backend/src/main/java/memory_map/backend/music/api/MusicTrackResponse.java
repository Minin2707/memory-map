package memory_map.backend.music.api;

import memory_map.backend.music.domain.MusicTrack;

import java.util.Objects;
import java.util.UUID;

public record MusicTrackResponse(

        UUID id,

        String title,

        String artist,

        int durationSeconds

) {
    public static MusicTrackResponse from(MusicTrack musicTrack) {
        Objects.requireNonNull(musicTrack, "musicTrack must not be null");

        return new MusicTrackResponse(
                musicTrack.id(),
                musicTrack.title(),
                musicTrack.artist(),
                musicTrack.durationSeconds()
        );
    }
}
