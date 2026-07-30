package memory_map.backend.auth.google;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;

import java.io.IOException;
import java.security.GeneralSecurityException;

interface GoogleSdkTokenVerifier {

    GoogleIdToken.Payload verify(String idToken)
            throws GeneralSecurityException, IOException;

}
