package memory_map.backend.user.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.user.domain.User;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcUserRepository implements UserRepository {

    private static final String SELECT_COLUMNS_SQL = """
            SELECT
                id,
                google_subject,
                display_name,
                display_name_customized,
                avatar_url,
                custom_avatar_storage_key,
                custom_avatar_updated_at,
                created_at,
                updated_at,
                deleted_at
            FROM users
            """;

    private static final String INSERT_SQL = """
            INSERT INTO users (
                id,
                google_subject,
                display_name,
                display_name_customized,
                avatar_url,
                custom_avatar_storage_key,
                custom_avatar_updated_at,
                created_at,
                updated_at
            )
            VALUES (
                :id,
                :googleSubject,
                :displayName,
                :displayNameCustomized,
                :avatarUrl,
                :customAvatarStorageKey,
                :customAvatarUpdatedAt,
                :createdAt,
                :updatedAt
            )
            RETURNING
                id,
                google_subject,
                display_name,
                display_name_customized,
                avatar_url,
                custom_avatar_storage_key,
                custom_avatar_updated_at,
                created_at,
                updated_at,
                deleted_at
            """;

    private static final String FIND_BY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE id = :id
            """;

    private static final String FIND_ACTIVE_BY_ID_FOR_UPDATE_SQL =
            SELECT_COLUMNS_SQL + """
            WHERE id = :id
              AND deleted_at IS NULL
            FOR UPDATE
            """;

    private static final String EXISTS_ACTIVE_BY_ID_SQL = """
            SELECT EXISTS (
                SELECT 1
                FROM users
                WHERE id = :id
                  AND deleted_at IS NULL
            )
            """;

    private static final String FIND_BY_GOOGLE_SUBJECT_SQL = SELECT_COLUMNS_SQL + """
            WHERE google_subject = :googleSubject
              AND deleted_at IS NULL
            """;

    private static final String TOMBSTONE_BY_ID_SQL = """
            UPDATE users
            SET google_subject = NULL,
                display_name = 'Deleted user',
                display_name_customized = FALSE,
                avatar_url = NULL,
                custom_avatar_storage_key = NULL,
                custom_avatar_updated_at = NULL,
                deleted_at = :deletedAt,
                updated_at = :deletedAt
            WHERE id = :id
              AND deleted_at IS NULL
            """;

    private static final String UPDATE_GOOGLE_AVATAR_URL_SQL = """
            UPDATE users
            SET avatar_url = :avatarUrl,
                updated_at = :updatedAt
            WHERE id = :id
              AND deleted_at IS NULL
            RETURNING
                id,
                google_subject,
                display_name,
                display_name_customized,
                avatar_url,
                custom_avatar_storage_key,
                custom_avatar_updated_at,
                created_at,
                updated_at,
                deleted_at
            """;

    private static final String UPDATE_GOOGLE_PROFILE_FALLBACK_SQL = """
            UPDATE users
            SET display_name = :displayName,
                avatar_url = :avatarUrl,
                updated_at = :updatedAt
            WHERE id = :id
              AND deleted_at IS NULL
              AND display_name_customized = FALSE
            RETURNING
                id,
                google_subject,
                display_name,
                display_name_customized,
                avatar_url,
                custom_avatar_storage_key,
                custom_avatar_updated_at,
                created_at,
                updated_at,
                deleted_at
            """;

    private static final String UPDATE_DISPLAY_NAME_SQL = """
            UPDATE users
            SET display_name = :displayName,
                display_name_customized = TRUE,
                updated_at = :updatedAt
            WHERE id = :id
              AND deleted_at IS NULL
            RETURNING
                id,
                google_subject,
                display_name,
                display_name_customized,
                avatar_url,
                custom_avatar_storage_key,
                custom_avatar_updated_at,
                created_at,
                updated_at,
                deleted_at
            """;

    private static final String UPDATE_CUSTOM_AVATAR_SQL = """
            UPDATE users
            SET custom_avatar_storage_key = :storageKey,
                custom_avatar_updated_at = :updatedAt,
                updated_at = :updatedAt
            WHERE id = :id
              AND deleted_at IS NULL
            RETURNING
                id,
                google_subject,
                display_name,
                display_name_customized,
                avatar_url,
                custom_avatar_storage_key,
                custom_avatar_updated_at,
                created_at,
                updated_at,
                deleted_at
            """;

    private static final String CLEAR_CUSTOM_AVATAR_SQL = """
            UPDATE users
            SET custom_avatar_storage_key = NULL,
                custom_avatar_updated_at = NULL,
                updated_at = :updatedAt
            WHERE id = :id
              AND deleted_at IS NULL
            RETURNING
                id,
                google_subject,
                display_name,
                display_name_customized,
                avatar_url,
                custom_avatar_storage_key,
                custom_avatar_updated_at,
                created_at,
                updated_at,
                deleted_at
            """;

    private final JdbcClient jdbcClient;
    private final UserRowMapper rowMapper;

    public JdbcUserRepository(
            JdbcClient jdbcClient,
            UserRowMapper rowMapper
    ) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = rowMapper;
    }

    @Override
    public User save(User user) {

        return jdbcClient.sql(INSERT_SQL)
                .param("id", user.id())
                .param("googleSubject", user.googleSubject())
                .param("displayName", user.displayName())
                .param("displayNameCustomized", user.displayNameCustomized())
                .param("avatarUrl", user.avatarUrl())
                .param("customAvatarStorageKey", user.customAvatarStorageKey())
                .param(
                        "customAvatarUpdatedAt",
                        user.customAvatarUpdatedAt() == null
                                ? null
                                : DatabaseTimestamps.toOffsetDateTime(
                                        user.customAvatarUpdatedAt()
                                )
                )
                .param("createdAt", DatabaseTimestamps.toOffsetDateTime(user.createdAt()))
                .param("updatedAt", DatabaseTimestamps.toOffsetDateTime(user.updatedAt()))
                .query(rowMapper)
                .single();
    }

    @Override
    public Optional<User> findById(UUID id) {

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public Optional<User> findActiveByIdForUpdate(UUID id) {

        return jdbcClient.sql(FIND_ACTIVE_BY_ID_FOR_UPDATE_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public boolean existsActiveById(UUID id) {

        return jdbcClient.sql(EXISTS_ACTIVE_BY_ID_SQL)
                .param("id", id)
                .query(Boolean.class)
                .single();
    }

    @Override
    public Optional<User> findByGoogleSubject(String googleSubject) {

        return jdbcClient.sql(FIND_BY_GOOGLE_SUBJECT_SQL)
                .param("googleSubject", googleSubject)
                .query(rowMapper)
                .optional();
    }

    @Override
    public User updateGoogleAvatarUrl(
            UUID id,
            String avatarUrl,
            Instant updatedAt
    ) {
        return jdbcClient.sql(UPDATE_GOOGLE_AVATAR_URL_SQL)
                .param("id", id)
                .param("avatarUrl", avatarUrl)
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(updatedAt)
                )
                .query(rowMapper)
                .single();
    }

    @Override
    public User updateGoogleProfileFallback(
            UUID id,
            String displayName,
            String avatarUrl,
            Instant updatedAt
    ) {
        return jdbcClient.sql(UPDATE_GOOGLE_PROFILE_FALLBACK_SQL)
                .param("id", id)
                .param("displayName", displayName)
                .param("avatarUrl", avatarUrl)
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(updatedAt)
                )
                .query(rowMapper)
                .single();
    }

    @Override
    public User updateDisplayName(
            UUID id,
            String displayName,
            Instant updatedAt
    ) {
        return jdbcClient.sql(UPDATE_DISPLAY_NAME_SQL)
                .param("id", id)
                .param("displayName", displayName)
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(updatedAt)
                )
                .query(rowMapper)
                .single();
    }

    @Override
    public User updateCustomAvatar(
            UUID id,
            String storageKey,
            Instant updatedAt
    ) {
        return jdbcClient.sql(UPDATE_CUSTOM_AVATAR_SQL)
                .param("id", id)
                .param("storageKey", storageKey)
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(updatedAt)
                )
                .query(rowMapper)
                .single();
    }

    @Override
    public User clearCustomAvatar(UUID id, Instant updatedAt) {
        return jdbcClient.sql(CLEAR_CUSTOM_AVATAR_SQL)
                .param("id", id)
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(updatedAt)
                )
                .query(rowMapper)
                .single();
    }

    @Override
    public boolean tombstoneById(UUID id, Instant deletedAt) {

        int updatedRows = jdbcClient.sql(TOMBSTONE_BY_ID_SQL)
                .param("id", id)
                .param("deletedAt", DatabaseTimestamps.toOffsetDateTime(deletedAt))
                .update();

        return updatedRows == 1;
    }

}
