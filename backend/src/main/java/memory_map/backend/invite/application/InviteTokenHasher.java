package memory_map.backend.invite.application;

public interface InviteTokenHasher {

    String hash(String rawToken);

}
