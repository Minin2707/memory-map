package memory_map.backend.invite.repository;

import memory_map.backend.invite.domain.Invite;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface InviteRepository {

    Optional<Invite> findById(UUID id);

    Optional<Invite> findByTokenHash(String tokenHash);

    List<Invite> findByStoryId(UUID storyId);

    void save(Invite invite);

    void update(Invite invite);

    void delete(UUID id);

}
