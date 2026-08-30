package memory_map.backend.story.repository;

import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.UUID;

@Component
public class StoryRowMapper implements RowMapper<Story> {

    @Override
    public Story mapRow(ResultSet rs, int rowNum) throws SQLException {
        return new Story(
                rs.getObject("id", UUID.class),
                rs.getObject("owner_id", UUID.class),
                rs.getString("title"),
                rs.getString("description"),
                rs.getObject("soundtrack_id", UUID.class),
                coverMetadata(rs),
                rs.getObject("created_at", OffsetDateTime.class).toInstant(),
                rs.getObject("updated_at", OffsetDateTime.class).toInstant()
        );
    }

    private static StoryCoverMetadata coverMetadata(ResultSet rs)
            throws SQLException {
        if (!hasCoverMetadataColumns(rs)) {
            return null;
        }

        String displayStorageKey = rs.getString("cover_display_storage_key");
        Long displayFileSize = nullableLong(rs, "cover_display_file_size");
        String thumbnailStorageKey =
                rs.getString("cover_thumbnail_storage_key");
        Long thumbnailFileSize = nullableLong(
                rs,
                "cover_thumbnail_file_size"
        );
        String mimeType = rs.getString("cover_mime_type");
        OffsetDateTime coverUpdatedAt =
                rs.getObject("cover_updated_at", OffsetDateTime.class);

        boolean allAbsent = displayStorageKey == null
                && displayFileSize == null
                && thumbnailStorageKey == null
                && thumbnailFileSize == null
                && mimeType == null
                && coverUpdatedAt == null;
        if (allAbsent) {
            return null;
        }

        boolean allPresent = displayStorageKey != null
                && displayFileSize != null
                && thumbnailStorageKey != null
                && thumbnailFileSize != null
                && mimeType != null
                && coverUpdatedAt != null;
        if (!allPresent) {
            throw new SQLException("Partial story cover metadata");
        }

        return new StoryCoverMetadata(
                displayStorageKey,
                displayFileSize,
                thumbnailStorageKey,
                thumbnailFileSize,
                mimeType,
                coverUpdatedAt.toInstant()
        );
    }

    private static boolean hasCoverMetadataColumns(ResultSet rs)
            throws SQLException {
        ResultSetMetaData metaData = rs.getMetaData();
        boolean hasAnyCoverColumn = false;
        boolean hasAllCoverColumns = true;
        for (String columnName : new String[]{
                "cover_display_storage_key",
                "cover_display_file_size",
                "cover_thumbnail_storage_key",
                "cover_thumbnail_file_size",
                "cover_mime_type",
                "cover_updated_at"
        }) {
            boolean hasColumn = hasColumn(metaData, columnName);
            hasAnyCoverColumn = hasAnyCoverColumn || hasColumn;
            hasAllCoverColumns = hasAllCoverColumns && hasColumn;
        }

        if (hasAnyCoverColumn && !hasAllCoverColumns) {
            throw new SQLException("Incomplete story cover metadata projection");
        }

        return hasAllCoverColumns;
    }

    private static boolean hasColumn(
            ResultSetMetaData metaData,
            String columnName
    ) throws SQLException {
        for (int columnIndex = 1;
             columnIndex <= metaData.getColumnCount();
             columnIndex++
        ) {
            if (columnName.equalsIgnoreCase(
                    metaData.getColumnLabel(columnIndex)
            )) {
                return true;
            }
        }
        return false;
    }

    private static Long nullableLong(ResultSet rs, String columnName)
            throws SQLException {
        long value = rs.getLong(columnName);
        return rs.wasNull() ? null : value;
    }

}
