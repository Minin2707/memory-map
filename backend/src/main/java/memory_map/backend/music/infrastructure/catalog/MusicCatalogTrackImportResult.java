package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.music.domain.MusicTrackStatus;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public record MusicCatalogTrackImportResult(

        UUID id,

        String title,

        MusicTrackStatus plannedStatus,

        List<MusicCatalogImportAction> actions,

        String verification,

        String result

) {
    public MusicCatalogTrackImportResult {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(
                plannedStatus,
                "plannedStatus must not be null"
        );
        Objects.requireNonNull(actions, "actions must not be null");
        Objects.requireNonNull(verification, "verification must not be null");
        Objects.requireNonNull(result, "result must not be null");

        actions = List.copyOf(actions);
    }
}
