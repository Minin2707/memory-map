package memory_map.backend.music.repository;

import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.UUID;

public class MusicTrackRowMapper implements RowMapper<MusicTrack> {

    @Override
    public MusicTrack mapRow(ResultSet rs, int rowNum) throws SQLException {

        UUID id = rs.getObject("id", UUID.class);
        String title = rs.getString("title");
        String artist = rs.getString("artist");
        int durationSeconds = rs.getInt("duration_seconds");
        MusicTrackStatus status =
                MusicTrackStatus.valueOf(rs.getString("status"));
        int sortOrder = rs.getInt("sort_order");
        String storageKey = rs.getString("storage_key");
        String mimeType = rs.getString("mime_type");
        long fileSize = rs.getLong("file_size");
        OffsetDateTime createdAt =
                rs.getObject("created_at", OffsetDateTime.class);
        OffsetDateTime updatedAt =
                rs.getObject("updated_at", OffsetDateTime.class);

        return new MusicTrack(
                id,
                title,
                artist,
                durationSeconds,
                status,
                sortOrder,
                storageKey,
                mimeType,
                fileSize,
                createdAt.toInstant(),
                updatedAt.toInstant()
        );
    }
}
