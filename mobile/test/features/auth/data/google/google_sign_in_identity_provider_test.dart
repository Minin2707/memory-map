import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/data/google/google_sign_in_client.dart';
import 'package:memory_map/features/auth/data/google/google_sign_in_identity_provider.dart';
import 'package:memory_map/features/auth/domain/google_identity_exception.dart';

void main() {
  group('GoogleSignInIdentityProvider', () {
    test('shouldInitializeClientWithServerClientId', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(client: client);

      await provider.requestIdToken();

      expect(client.initializeCalls, 1);
      expect(client.lastServerClientId, kServerClientId);
    });

    test('shouldPassIosClientIdWhenConfigured', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(
        client: client,
        iosClientId: kIosClientId,
      );

      await provider.requestIdToken();

      expect(client.lastClientId, kIosClientId);
    });

    test('shouldConvertBlankIosClientIdToNull', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(
        client: client,
        iosClientId: '   ',
      );

      await provider.requestIdToken();

      expect(client.lastClientId, isNull);
    });

    test('shouldRequestInteractiveAuthentication', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(client: client);

      await provider.requestIdToken();

      expect(client.authenticateCalls, 1);
    });

    test('shouldReturnGoogleIdToken', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(client: client);

      final idToken = await provider.requestIdToken();

      expect(idToken, 'raw-google-id-token');
    });

    test('shouldRejectMissingServerClientId', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(
        client: client,
        serverClientId: '',
      );

      await expectLater(
        provider.requestIdToken(),
        throwsA(isA<GoogleIdentityUnavailableException>()),
      );
      expect(client.initializeCalls, 0);
      expect(client.authenticateCalls, 0);
    });

    test('shouldRejectBlankServerClientId', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(
        client: client,
        serverClientId: '   ',
      );

      await expectLater(
        provider.requestIdToken(),
        throwsA(isA<GoogleIdentityUnavailableException>()),
      );
      expect(client.initializeCalls, 0);
      expect(client.authenticateCalls, 0);
    });

    test('shouldRejectNullIdToken', () async {
      final client = FakeGoogleSignInClient()..idToken = null;
      final provider = createProvider(client: client);

      await expectLater(
        provider.requestIdToken(),
        throwsA(isA<GoogleIdentityAuthenticationException>()),
      );
    });

    test('shouldRejectBlankIdToken', () async {
      final client = FakeGoogleSignInClient()..idToken = '   ';
      final provider = createProvider(client: client);

      await expectLater(
        provider.requestIdToken(),
        throwsA(isA<GoogleIdentityAuthenticationException>()),
      );
    });

    test('shouldMapCancelledClientFailure', () async {
      final client = FakeGoogleSignInClient()
        ..authenticateFailure = const GoogleSignInClientException(
          GoogleSignInClientFailureCode.cancelled,
        );
      final provider = createProvider(client: client);

      await expectLater(
        provider.requestIdToken(),
        throwsA(isA<GoogleIdentityCancelledException>()),
      );
    });

    test('shouldMapUnavailableClientFailure', () async {
      final client = FakeGoogleSignInClient()
        ..authenticateFailure = const GoogleSignInClientException(
          GoogleSignInClientFailureCode.unavailable,
        );
      final provider = createProvider(client: client);

      await expectLater(
        provider.requestIdToken(),
        throwsA(isA<GoogleIdentityUnavailableException>()),
      );
    });

    test('shouldMapFailedClientFailure', () async {
      final client = FakeGoogleSignInClient()
        ..authenticateFailure = const GoogleSignInClientException(
          GoogleSignInClientFailureCode.failed,
        );
      final provider = createProvider(client: client);

      await expectLater(
        provider.requestIdToken(),
        throwsA(isA<GoogleIdentityAuthenticationException>()),
      );
    });

    test('shouldNotAuthenticateWhenInitializationFails', () async {
      final client = FakeGoogleSignInClient()
        ..initializeFailure = const GoogleSignInClientException(
          GoogleSignInClientFailureCode.unavailable,
        );
      final provider = createProvider(client: client);

      await expectLater(
        provider.requestIdToken(),
        throwsA(isA<GoogleIdentityUnavailableException>()),
      );
      expect(client.authenticateCalls, 0);
    });

    test('shouldNotExposeIdTokenInExceptions', () async {
      final client = FakeGoogleSignInClient()
        ..idToken = 'raw-google-id-token'
        ..authenticateFailure = const GoogleSignInClientException(
          GoogleSignInClientFailureCode.failed,
        );
      final provider = createProvider(client: client);

      try {
        await provider.requestIdToken();
        fail('Expected Google identity exception');
      } on GoogleIdentityException catch (error) {
        expect(error.toString(), isNot(contains('raw-google-id-token')));
      expect(error.toString(), isNot(contains(kServerClientId)));
      }
    });

    test('shouldNotCallBackendOrStorage', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(client: client);

      final idToken = await provider.requestIdToken();

      expect(idToken, 'raw-google-id-token');
      expect(client.initializeCalls, 1);
      expect(client.authenticateCalls, 1);
    });

    test('shouldUseOneInitializationForSequentialRequests', () async {
      final client = FakeGoogleSignInClient();
      final provider = createProvider(client: client);

      await provider.requestIdToken();
      await provider.requestIdToken();

      expect(client.initializeCalls, 1);
      expect(client.authenticateCalls, 2);
    });

    test('shouldShareInitializationForConcurrentRequests', () async {
      final client = FakeGoogleSignInClient();
      final initialization = Completer<void>();
      client.initializationCompleter = initialization;
      final provider = createProvider(client: client);

      final first = provider.requestIdToken();
      final second = provider.requestIdToken();
      await pumpEventQueue();

      expect(client.initializeCalls, 1);

      initialization.complete();

      await expectLater(
        Future.wait(<Future<String>>[first, second]),
        completion(<String>[
          'raw-google-id-token',
          'raw-google-id-token',
        ]),
      );
      expect(client.authenticateCalls, 2);
    });
  });
}

const String kServerClientId = 'web-client-id.apps.googleusercontent.com';
const String kIosClientId = 'ios-client-id.apps.googleusercontent.com';

GoogleSignInIdentityProvider createProvider({
  required FakeGoogleSignInClient client,
  String serverClientId = kServerClientId,
  String? iosClientId,
}) {
  return GoogleSignInIdentityProvider(
    client: client,
    serverClientId: serverClientId,
    iosClientId: iosClientId,
  );
}

final class FakeGoogleSignInClient implements GoogleSignInClient {
  int initializeCalls = 0;
  int authenticateCalls = 0;

  String? lastServerClientId;
  String? lastClientId;

  bool supportsAuthentication = true;
  String? idToken = 'raw-google-id-token';
  Object? initializeFailure;
  Object? authenticateFailure;
  Completer<void>? initializationCompleter;

  @override
  Future<void> initialize({
    required String serverClientId,
    String? clientId,
  }) async {
    initializeCalls += 1;
    lastServerClientId = serverClientId;
    lastClientId = clientId;

    final failure = initializeFailure;
    if (failure != null) {
      throw failure;
    }

    final completer = initializationCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  bool supportsAuthenticate() {
    return supportsAuthentication;
  }

  @override
  Future<String?> authenticateAndGetIdToken() async {
    authenticateCalls += 1;

    final failure = authenticateFailure;
    if (failure != null) {
      throw failure;
    }

    return idToken;
  }
}
