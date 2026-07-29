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
        Long fileSize = rs.getObject("file_size", Long.class);
        String mimeType = rs.getString("mime_type");
        String storageKey = rs.getString("storage_key");
        OffsetDateTime createdAt = rs.getObject("created_at", OffsetDateTime.class);

        return new MediaFile(
                id,
                memoryId,
                type,
                fileSize,
                mimeType,
                storageKey,
                createdAt.toInstant()
        );
    }

}
