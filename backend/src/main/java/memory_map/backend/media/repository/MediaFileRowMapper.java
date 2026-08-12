package memory_map.backend.media.repository;

import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.UUID;

public class MediaFileRowMapper implements RowMapper<MediaFile> {

    @Override
    public MediaFile mapRow(ResultSet rs, int rowNum) throws SQLException {

        UUID id = rs.getObject("id", UUID.class);
        UUID memoryId = rs.getObject("memory_id", UUID.class);
        MediaType type = MediaType.valueOf(rs.getString("media_type"));
        String displayStorageKey = rs.getString("display_storage_key");
        long displayFileSize = rs.getLong("display_file_size");
        String thumbnailStorageKey = rs.getString("thumbnail_storage_key");
        long thumbnailFileSize = rs.getLong("thumbnail_file_size");
        String mimeType = rs.getString("mime_type");
        OffsetDateTime createdAt = rs.getObject("created_at", OffsetDateTime.class);

        return new MediaFile(
                id,
                memoryId,
                type,
                displayStorageKey,
                displayFileSize,
                thumbnailStorageKey,
                thumbnailFileSize,
                mimeType,
                createdAt.toInstant()
        );
    }

}
