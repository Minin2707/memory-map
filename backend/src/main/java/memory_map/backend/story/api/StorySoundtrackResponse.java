package memory_map.backend.story.api;

import memory_map.backend.music.api.MusicTrackResponse;
import memory_map.backend.music.application.StorySoundtrack;

import java.util.Objects;

public record StorySoundtrackResponse(

        MusicTrackResponse selectedSoundtrack,

        MusicTrackResponse effectiveSoundtrack

) {
    public static StorySoundtrackResponse from(
            StorySoundtrack storySoundtrack
    ) {
        Objects.requireNonNull(
                storySoundtrack,
                "storySoundtrack must not be null"
        );

        return new StorySoundtrackResponse(
                storySoundtrack.selectedSoundtrack() == null
                        ? null
                        : MusicTrackResponse.from(
                                storySoundtrack.selectedSoundtrack()
                        ),
                storySoundtrack.effectiveSoundtrack() == null
                        ? null
                        : MusicTrackResponse.from(
                                storySoundtrack.effectiveSoundtrack()
                        )
        );
    }
}
