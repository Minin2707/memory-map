package memory_map.backend.notification.repository;

import memory_map.backend.notification.application.NotificationActorView;
import memory_map.backend.notification.application.NotificationMemoryView;
import memory_map.backend.notification.application.NotificationReadModel;
import memory_map.backend.notification.application.NotificationStoryView;
import memory_map.backend.notification.domain.NotificationType;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.UUID;

public class NotificationReadModelRowMapper
        implements RowMapper<NotificationReadModel> {

    @Override
    public NotificationReadModel mapRow(ResultSet rs, int rowNum)
            throws SQLException {

        UUID memoryId = rs.getObject("memory_id", UUID.class);
        OffsetDateTime readAt = rs.getObject(
                "read_at",
                OffsetDateTime.class
        );

        return new NotificationReadModel(
                rs.getObject("id", UUID.class),
                NotificationType.valueOf(rs.getString("type")),
                new NotificationActorView(
                        rs.getObject("actor_user_id", UUID.class),
                        rs.getString("actor_display_name"),
                        rs.getString("actor_avatar_url")
                ),
                new NotificationStoryView(
                        rs.getObject("story_id", UUID.class),
                        rs.getString("story_title")
                ),
                memoryId == null
                        ? null
                        : new NotificationMemoryView(
                                memoryId,
                                rs.getString("memory_title")
                        ),
                rs.getObject("created_at", OffsetDateTime.class).toInstant(),
                readAt == null ? null : readAt.toInstant()
        );
    }
}
