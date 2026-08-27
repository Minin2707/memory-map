package memory_map.backend.media.repository;

import memory_map.backend.media.application.MediaDownloadReadModel;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcAuthorizedMediaDownloadRepository
        implements AuthorizedMediaDownloadRepository {

    private static final String FIND_AUTHORIZED_DOWNLOAD_SQL = """
            SELECT
                mf.display_storage_key,
                mf.display_file_size,
                mf.thumbnail_storage_key,
                mf.thumbnail_file_size,
                mf.mime_type
            FROM media_files mf
            JOIN memories m
              ON m.id = mf.memory_id
            JOIN story_participants sp
              ON sp.story_id = m.story_id
             AND sp.user_id = :requesterUserId
            WHERE mf.id = :mediaId
            """;

    private final JdbcClient jdbcClient;

    public JdbcAuthorizedMediaDownloadRepository(JdbcClient jdbcClient) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
    }

    @Override
    public Optional<MediaDownloadReadModel> findAuthorizedDownload(
            UUID mediaId,
            UUID requesterUserId
    ) {
        Objects.requireNonNull(mediaId, "mediaId must not be null");
        Objects.requireNonNull(
                requesterUserId,
                "requesterUserId must not be null"
        );

        return jdbcClient.sql(FIND_AUTHORIZED_DOWNLOAD_SQL)
                .param("mediaId", mediaId)
                .param("requesterUserId", requesterUserId)
                .query(this::mapReadModel)
                .optional();
    }

    private MediaDownloadReadModel mapReadModel(
            ResultSet rs,
            int rowNum
    ) throws SQLException {
        return new MediaDownloadReadModel(
                rs.getString("display_storage_key"),
                rs.getLong("display_file_size"),
                rs.getString("thumbnail_storage_key"),
                rs.getLong("thumbnail_file_size"),
                rs.getString("mime_type")
        );
    }
}
