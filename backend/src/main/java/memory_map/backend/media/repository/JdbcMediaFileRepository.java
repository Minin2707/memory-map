package memory_map.backend.media.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.media.domain.MediaFile;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcMediaFileRepository implements MediaFileRepository {

    private static final String SELECT_COLUMNS_SQL = """
            SELECT
                id,
                memory_id,
                media_type,
                display_storage_key,
                display_file_size,
                thumbnail_storage_key,
                thumbnail_file_size,
                mime_type,
                created_at
            FROM media_files
            """;

    private static final String FIND_BY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE id = :id
            """;

    private static final String FIND_BY_MEMORY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE memory_id = :memoryId
            ORDER BY created_at ASC, id ASC
            """;

    private static final String INSERT_SQL = """
            INSERT INTO media_files (
                id,
                memory_id,
                media_type,
                display_storage_key,
                display_file_size,
                thumbnail_storage_key,
                thumbnail_file_size,
                mime_type,
                created_at
            )
            VALUES (
                :id,
                :memoryId,
                :mediaType,
                :displayStorageKey,
                :displayFileSize,
                :thumbnailStorageKey,
                :thumbnailFileSize,
                :mimeType,
                :createdAt
            )
            """;

    private static final String DELETE_SQL = """
            DELETE FROM media_files
            WHERE id = :id
            """;

    private final JdbcClient jdbcClient;
    private final MediaFileRowMapper rowMapper;

    public JdbcMediaFileRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = new MediaFileRowMapper();
    }

    @Override
    public Optional<MediaFile> findById(UUID id) {

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public List<MediaFile> findByMemoryId(UUID memoryId) {

        return jdbcClient.sql(FIND_BY_MEMORY_ID_SQL)
                .param("memoryId", memoryId)
                .query(rowMapper)
                .list();
    }

    @Override
    public void save(MediaFile mediaFile) {

        jdbcClient.sql(INSERT_SQL)
                .param("id", mediaFile.id())
                .param("memoryId", mediaFile.memoryId())
                .param("mediaType", mediaFile.type().name())
                .param("displayStorageKey", mediaFile.displayStorageKey())
                .param("displayFileSize", mediaFile.displayFileSize())
                .param("thumbnailStorageKey", mediaFile.thumbnailStorageKey())
                .param("thumbnailFileSize", mediaFile.thumbnailFileSize())
                .param("mimeType", mediaFile.mimeType())
                .param("createdAt", DatabaseTimestamps.toOffsetDateTime(mediaFile.createdAt()))
                .update();
    }

    @Override
    public void delete(UUID id) {

        jdbcClient.sql(DELETE_SQL)
                .param("id", id)
                .update();
    }

}
