package memory_map.backend.auth.google;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Objects;

class GoogleApiIdTokenVerifier implements GoogleSdkTokenVerifier {

    private final GoogleIdTokenVerifier verifier;

    GoogleApiIdTokenVerifier(GoogleIdTokenVerifier verifier) {
        this.verifier = Objects.requireNonNull(verifier);
    }

    @Override
    public GoogleIdToken.Payload verify(String idToken)
            throws GeneralSecurityException, IOException {

        GoogleIdToken token = verifier.verify(idToken);

        return token == null ? null : token.getPayload();
    }
}
