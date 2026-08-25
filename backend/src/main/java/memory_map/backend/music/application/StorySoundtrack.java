package memory_map.backend.music.application;

import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;

import java.util.Objects;

public record StorySoundtrack(

        MusicTrack selectedSoundtrack,

        MusicTrack effectiveSoundtrack

) {
    public StorySoundtrack {
        if (effectiveSoundtrack != null) {
            Objects.requireNonNull(
                    selectedSoundtrack,
                    "selectedSoundtrack must not be null when effectiveSoundtrack is provided"
            );

            if (!selectedSoundtrack.equals(effectiveSoundtrack)) {
                throw new IllegalArgumentException(
                        "effectiveSoundtrack must match selectedSoundtrack"
                );
            }

            if (effectiveSoundtrack.status() != MusicTrackStatus.ACTIVE) {
                throw new IllegalArgumentException(
                        "effectiveSoundtrack must be active"
                );
            }
        }

        if (selectedSoundtrack != null
                && selectedSoundtrack.status() == MusicTrackStatus.ACTIVE
                && effectiveSoundtrack == null) {
            throw new IllegalArgumentException(
                    "active selectedSoundtrack must also be effective"
            );
        }
    }

    public static StorySoundtrack noMusic() {
        return new StorySoundtrack(null, null);
    }

    public static StorySoundtrack selected(MusicTrack musicTrack) {
        Objects.requireNonNull(musicTrack, "musicTrack must not be null");

        if (musicTrack.status() == MusicTrackStatus.ACTIVE) {
            return new StorySoundtrack(musicTrack, musicTrack);
        }

        return new StorySoundtrack(musicTrack, null);
    }
}
