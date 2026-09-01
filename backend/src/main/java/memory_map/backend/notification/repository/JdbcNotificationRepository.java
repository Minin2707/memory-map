package memory_map.backend.notification.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.notification.application.NotificationReadModel;
import memory_map.backend.notification.domain.Notification;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@Repository
public class JdbcNotificationRepository implements NotificationRepository {

    private static final String INSERT_SQL = """
            INSERT INTO notifications (
                id,
                recipient_user_id,
                type,
                actor_user_id,
                story_id,
                memory_id,
                created_at,
                read_at
            )
            VALUES (
                :id,
                :recipientUserId,
                :type,
                :actorUserId,
                :storyId,
                :memoryId,
                :createdAt,
                :readAt
            )
            """;

    private static final String FIND_BY_RECIPIENT_USER_ID_SQL = """
            SELECT
                n.id,
                n.type,
                n.actor_user_id,
                actor.display_name AS actor_display_name,
                CASE
                    WHEN actor.custom_avatar_storage_key IS NOT NULL
                        AND n.story_id IS NOT NULL THEN
                        '/api/v1/stories/' || n.story_id ||
                        '/participants/' || n.actor_user_id ||
                        '/avatar/' ||
                        FLOOR(EXTRACT(EPOCH FROM actor.custom_avatar_updated_at)
                                * 1000)::BIGINT
                    ELSE actor.avatar_url
                END AS actor_avatar_url,
                n.story_id,
                s.title AS story_title,
                n.memory_id,
                m.title AS memory_title,
                n.created_at,
                n.read_at
            FROM notifications n
            JOIN users actor
              ON actor.id = n.actor_user_id
            LEFT JOIN stories s
              ON s.id = n.story_id
            LEFT JOIN memories m
              ON m.id = n.memory_id
            WHERE n.recipient_user_id = :recipientUserId
            ORDER BY n.created_at DESC, n.id DESC
            LIMIT :limit
            """;

    private static final String COUNT_UNREAD_BY_RECIPIENT_USER_ID_SQL = """
            SELECT COUNT(*)
            FROM notifications
            WHERE recipient_user_id = :recipientUserId
              AND read_at IS NULL
            """;

    private static final String MARK_READ_SQL = """
            UPDATE notifications
            SET read_at = COALESCE(read_at, :readAt)
            WHERE id = :notificationId
              AND recipient_user_id = :recipientUserId
            """;

    private static final String MARK_ALL_READ_SQL = """
            UPDATE notifications
            SET read_at = :readAt
            WHERE recipient_user_id = :recipientUserId
              AND read_at IS NULL
            """;

    private final JdbcClient jdbcClient;
    private final NotificationReadModelRowMapper rowMapper;

    public JdbcNotificationRepository(JdbcClient jdbcClient) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
        this.rowMapper = new NotificationReadModelRowMapper();
    }

    @Override
    public void save(Notification notification) {
        Objects.requireNonNull(notification, "notification must not be null");

        jdbcClient.sql(INSERT_SQL)
                .param("id", notification.id())
                .param("recipientUserId", notification.recipientUserId())
                .param("type", notification.type().name())
                .param("actorUserId", notification.actorUserId())
                .param("storyId", notification.storyId())
                .param("memoryId", notification.memoryId())
                .param(
                        "createdAt",
                        DatabaseTimestamps.toOffsetDateTime(
                                notification.createdAt()
                        )
                )
                .param(
                        "readAt",
                        notification.readAt() == null
                                ? null
                                : DatabaseTimestamps.toOffsetDateTime(
                                        notification.readAt()
                                )
                )
                .update();
    }

    @Override
    public List<NotificationReadModel> findByRecipientUserId(
            UUID recipientUserId,
            int limit
    ) {
        Objects.requireNonNull(
                recipientUserId,
                "recipientUserId must not be null"
        );

        return jdbcClient.sql(FIND_BY_RECIPIENT_USER_ID_SQL)
                .param("recipientUserId", recipientUserId)
                .param("limit", limit)
                .query(rowMapper)
                .list();
    }

    @Override
    public long countUnreadByRecipientUserId(UUID recipientUserId) {
        Objects.requireNonNull(
                recipientUserId,
                "recipientUserId must not be null"
        );

        return jdbcClient.sql(COUNT_UNREAD_BY_RECIPIENT_USER_ID_SQL)
                .param("recipientUserId", recipientUserId)
                .query(Long.class)
                .single();
    }

    @Override
    public boolean markRead(
            UUID recipientUserId,
            UUID notificationId,
            Instant readAt
    ) {
        Objects.requireNonNull(
                recipientUserId,
                "recipientUserId must not be null"
        );
        Objects.requireNonNull(notificationId, "notificationId must not be null");
        Objects.requireNonNull(readAt, "readAt must not be null");

        int updatedRows = jdbcClient.sql(MARK_READ_SQL)
                .param("recipientUserId", recipientUserId)
                .param("notificationId", notificationId)
                .param("readAt", DatabaseTimestamps.toOffsetDateTime(readAt))
                .update();

        return updatedRows == 1;
    }

    @Override
    public void markAllRead(UUID recipientUserId, Instant readAt) {
        Objects.requireNonNull(
                recipientUserId,
                "recipientUserId must not be null"
        );
        Objects.requireNonNull(readAt, "readAt must not be null");

        jdbcClient.sql(MARK_ALL_READ_SQL)
                .param("recipientUserId", recipientUserId)
                .param("readAt", DatabaseTimestamps.toOffsetDateTime(readAt))
                .update();
    }
}
