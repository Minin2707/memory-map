package memory_map.backend.invite.repository;

import memory_map.backend.invite.domain.Invite;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface InviteRepository {

    Optional<Invite> findById(UUID id);

    Optional<Invite> findByTokenHash(String tokenHash);

    Optional<Invite> findByTokenHashForUpdate(String tokenHash);

    List<Invite> findByStoryId(UUID storyId);

    void save(Invite invite);

    boolean markUsedIfUnused(UUID inviteId, Instant usedAt);

    void delete(UUID id);

}
