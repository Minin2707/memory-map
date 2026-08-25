package memory_map.backend.music.application;

public interface RemoveStorySoundtrackUseCase {

    StorySoundtrack removeStorySoundtrack(
            RemoveStorySoundtrackCommand command
    );
}
