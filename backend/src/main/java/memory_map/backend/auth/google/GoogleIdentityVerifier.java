package memory_map.backend.auth.google;

import memory_map.backend.auth.domain.GoogleIdentity;

public interface GoogleIdentityVerifier {

    GoogleIdentity verify(String idToken);

}
