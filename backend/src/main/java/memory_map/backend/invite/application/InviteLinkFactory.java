package memory_map.backend.invite.application;

import java.net.URI;

public interface InviteLinkFactory {

    URI create(String rawToken);

}
