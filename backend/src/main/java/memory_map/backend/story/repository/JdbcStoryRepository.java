package memory_map.backend.story.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcStoryRepository implements StoryRepository {

    private static final String INSERT_SQL = """
            INSERT INTO stories (
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                cover_display_storage_key,
                cover_display_file_size,
                cover_thumbnail_storage_key,
                cover_thumbnail_file_size,
                cover_mime_type,
                cover_updated_at,
                created_at,
                updated_at
            )
            VALUES (
                :id,
                :ownerId,
                :title,
                :description,
                :soundtrackId,
                :coverDisplayStorageKey,
                :coverDisplayFileSize,
                :coverThumbnailStorageKey,
                :coverThumbnailFileSize,
                :coverMimeType,
                :coverUpdatedAt,
                :createdAt,
                :updatedAt
            )
            RETURNING
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                cover_display_storage_key,
                cover_display_file_size,
                cover_thumbnail_storage_key,
                cover_thumbnail_file_size,
                cover_mime_type,
                cover_updated_at,
                created_at,
                updated_at
            """;

    private static final String FIND_BY_ID_SQL = """
            SELECT
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                cover_display_storage_key,
                cover_display_file_size,
                cover_thumbnail_storage_key,
                cover_thumbnail_file_size,
                cover_mime_type,
                cover_updated_at,
                created_at,
                updated_at
            FROM stories
            WHERE id = :id
            """;

    private static final String LOCK_BY_ID_SQL = """
            SELECT id
            FROM stories
            WHERE id = :id
            FOR UPDATE
            """;

    private static final String FIND_BY_ID_FOR_UPDATE_SQL = """
            SELECT
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                cover_display_storage_key,
                cover_display_file_size,
                cover_thumbnail_storage_key,
                cover_thumbnail_file_size,
                cover_mime_type,
                cover_updated_at,
                created_at,
                updated_at
            FROM stories
            WHERE id = :id
            FOR UPDATE
            """;

    private static final String UPDATE_SQL = """
            UPDATE stories
            SET title = :title,
                description = :description,
                soundtrack_id = :soundtrackId,
                updated_at = :updatedAt
            WHERE id = :id
            RETURNING
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                cover_display_storage_key,
                cover_display_file_size,
                cover_thumbnail_storage_key,
                cover_thumbnail_file_size,
                cover_mime_type,
                cover_updated_at,
                created_at,
                updated_at
            """;

    private static final String UPDATE_COVER_SQL = """
            UPDATE stories
            SET cover_display_storage_key = :coverDisplayStorageKey,
                cover_display_file_size = :coverDisplayFileSize,
                cover_thumbnail_storage_key = :coverThumbnailStorageKey,
                cover_thumbnail_file_size = :coverThumbnailFileSize,
                cover_mime_type = :coverMimeType,
                cover_updated_at = :coverUpdatedAt
            WHERE id = :id
            RETURNING
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                cover_display_storage_key,
                cover_display_file_size,
                cover_thumbnail_storage_key,
                cover_thumbnail_file_size,
                cover_mime_type,
                cover_updated_at,
                created_at,
                updated_at
            """;

    private static final String CLEAR_COVER_SQL = """
            UPDATE stories
            SET cover_display_storage_key = NULL,
                cover_display_file_size = NULL,
                cover_thumbnail_storage_key = NULL,
                cover_thumbnail_file_size = NULL,
                cover_mime_type = NULL,
                cover_updated_at = NULL
            WHERE id = :id
            RETURNING
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                cover_display_storage_key,
                cover_display_file_size,
                cover_thumbnail_storage_key,
                cover_thumbnail_file_size,
                cover_mime_type,
                cover_updated_at,
                created_at,
                updated_at
            """;

    private static final String FIND_BY_OWNER_ID_SQL = """
            SELECT
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                cover_display_storage_key,
                cover_display_file_size,
                cover_thumbnail_storage_key,
                cover_thumbnail_file_size,
                cover_mime_type,
                cover_updated_at,
                created_at,
                updated_at
            FROM stories
            WHERE owner_id = :ownerId
            ORDER BY created_at DESC
            """;

    private final JdbcClient jdbcClient;
    private final StoryRowMapper rowMapper;

    public JdbcStoryRepository(
            JdbcClient jdbcClient,
            StoryRowMapper rowMapper
    ) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = rowMapper;
    }

    @Override
    public Story save(Story story) {

        return jdbcClient.sql(INSERT_SQL)
                .param("id", story.id())
                .param("ownerId", story.ownerId())
                .param("title", story.title())
                .param("description", story.description())
                .param("soundtrackId", story.soundtrackId())
                .param(
                        "coverDisplayStorageKey",
                        coverDisplayStorageKey(story.cover())
                )
                .param(
                        "coverDisplayFileSize",
                        coverDisplayFileSize(story.cover())
                )
                .param(
                        "coverThumbnailStorageKey",
                        coverThumbnailStorageKey(story.cover())
                )
                .param(
                        "coverThumbnailFileSize",
                        coverThumbnailFileSize(story.cover())
                )
                .param("coverMimeType", coverMimeType(story.cover()))
                .param(
                        "coverUpdatedAt",
                        toOffsetDateTime(coverUpdatedAt(story.cover()))
                )
                .param(
                        "createdAt",
                        DatabaseTimestamps.toOffsetDateTime(story.createdAt())
                )
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(story.updatedAt())
                )
                .query(rowMapper)
                .single();
    }

    @Override
    public Story update(Story story) {

        return jdbcClient.sql(UPDATE_SQL)
                .param("id", story.id())
                .param("title", story.title())
                .param("description", story.description())
                .param("soundtrackId", story.soundtrackId())
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(story.updatedAt())
                )
                .query(rowMapper)
                .single();
    }

    @Override
    public Optional<Story> findById(UUID id) {

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public Optional<Story> findByIdForUpdate(UUID id) {

        Objects.requireNonNull(id, "id must not be null");

        return jdbcClient.sql(FIND_BY_ID_FOR_UPDATE_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public boolean lockById(UUID id) {

        Objects.requireNonNull(id, "id must not be null");

        return jdbcClient.sql(LOCK_BY_ID_SQL)
                .param("id", id)
                .query(UUID.class)
                .optional()
                .isPresent();
    }

    @Override
    public Story updateCover(UUID id, StoryCoverMetadata cover) {

        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(cover, "cover must not be null");

        return jdbcClient.sql(UPDATE_COVER_SQL)
                .param("id", id)
                .param("coverDisplayStorageKey", cover.displayStorageKey())
                .param("coverDisplayFileSize", cover.displayFileSize())
                .param(
                        "coverThumbnailStorageKey",
                        cover.thumbnailStorageKey()
                )
                .param("coverThumbnailFileSize", cover.thumbnailFileSize())
                .param("coverMimeType", cover.mimeType())
                .param(
                        "coverUpdatedAt",
                        DatabaseTimestamps.toOffsetDateTime(cover.updatedAt())
                )
                .query(rowMapper)
                .single();
    }

    @Override
    public Story clearCover(UUID id) {

        Objects.requireNonNull(id, "id must not be null");

        return jdbcClient.sql(CLEAR_COVER_SQL)
                .param("id", id)
                .query(rowMapper)
                .single();
    }

    @Override
    public List<Story> findByOwnerId(UUID ownerId) {

        return jdbcClient.sql(FIND_BY_OWNER_ID_SQL)
                .param("ownerId", ownerId)
                .query(rowMapper)
                .list();
    }

    private static String coverDisplayStorageKey(
            StoryCoverMetadata cover
    ) {
        return cover == null ? null : cover.displayStorageKey();
    }

    private static Long coverDisplayFileSize(StoryCoverMetadata cover) {
        return cover == null ? null : cover.displayFileSize();
    }

    private static String coverThumbnailStorageKey(
            StoryCoverMetadata cover
    ) {
        return cover == null ? null : cover.thumbnailStorageKey();
    }

    private static Long coverThumbnailFileSize(StoryCoverMetadata cover) {
        return cover == null ? null : cover.thumbnailFileSize();
    }

    private static String coverMimeType(StoryCoverMetadata cover) {
        return cover == null ? null : cover.mimeType();
    }

    private static java.time.Instant coverUpdatedAt(StoryCoverMetadata cover) {
        return cover == null ? null : cover.updatedAt();
    }

    private static java.time.OffsetDateTime toOffsetDateTime(
            java.time.Instant instant
    ) {
        return instant == null
                ? null
                : DatabaseTimestamps.toOffsetDateTime(instant);
    }
}
