package memory_map.backend.music.infrastructure.catalog;

import java.util.List;
import java.util.Objects;

public record MusicCatalogImportReport(

        boolean dryRun,

        List<MusicCatalogTrackImportResult> tracks

) {
    public MusicCatalogImportReport {
        Objects.requireNonNull(tracks, "tracks must not be null");

        tracks = List.copyOf(tracks);
    }

    public String toOperatorText() {
        StringBuilder builder = new StringBuilder();
        builder.append("Music catalog import ")
                .append(dryRun ? "dry-run" : "run")
                .append(System.lineSeparator());

        for (MusicCatalogTrackImportResult track : tracks) {
            builder.append("- ")
                    .append(track.id())
                    .append(" | ")
                    .append(track.title())
                    .append(" | planned=")
                    .append(track.plannedStatus())
                    .append(" | actions=")
                    .append(track.actions())
                    .append(" | verification=")
                    .append(track.verification())
                    .append(" | result=")
                    .append(track.result())
                    .append(System.lineSeparator());
        }

        return builder.toString();
    }
}
