import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/core/config/app_config.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/playback/application/audio/just_audio_playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_orchestrator.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_provider.dart';

import 'just_audio_playback_audio_controller_test.dart';

void main() {
  group('playbackAudioControllerProvider', () {
    test('shouldCreateIndependentControllerPerStoryProviderKey', () {
      final factory = FakeJustAudioPlayerPortFactory();
      final container = createProviderContainer(factory);
      addTearDown(container.dispose);

      final first = container.read(playbackAudioControllerProvider('story-1'));
      final second = container.read(playbackAudioControllerProvider('story-2'));

      expect(first, isNot(same(second)));
      expect(factory.players.length, 2);
    });

    test('shouldDisposeOwnedPlayerWhenProviderIsDisposed', () async {
      final factory = FakeJustAudioPlayerPortFactory();
      final container = createProviderContainer(factory);
      final subscription = container.listen(
        playbackAudioControllerProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      final player = factory.players.single;

      subscription.close();
      await pumpEventQueue();
      container.dispose();

      expect(player.disposeCalls, 1);
    });

    test('shouldKeepControllerAliveThroughOrchestratorProvider', () async {
      final factory = FakeJustAudioPlayerPortFactory();
      final container = createProviderContainer(factory);
      final subscription = container.listen(
        playbackAudioOrchestratorProvider('story-1'),
        (previous, next) {},
        fireImmediately: true,
      );

      expect(
        container.read(playbackAudioOrchestratorProvider('story-1')),
        isA<PlaybackAudioOrchestrator>(),
      );
      expect(factory.players.length, 1);

      final player = factory.players.single;
      subscription.close();
      await pumpEventQueue();
      container.dispose();

      expect(player.disposeCalls, 1);
    });
  });
}

ProviderContainer createProviderContainer(
  FakeJustAudioPlayerPortFactory factory,
) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(apiBaseUrl: 'https://api.example.test'),
      ),
      authorizedSessionManagerProvider.overrideWithValue(
        FakeAuthorizedSessionManager(),
      ),
      storySoundtrackRepositoryProvider.overrideWithValue(
        FakeStorySoundtrackRepository(),
      ),
      justAudioPlayerPortFactoryProvider.overrideWithValue(factory.call),
    ],
  );
}

final class FakeJustAudioPlayerPortFactory {
  final List<FakeJustAudioPlayerPort> players = <FakeJustAudioPlayerPort>[];

  JustAudioPlayerPort call() {
    final player = FakeJustAudioPlayerPort();
    players.add(player);
    return player;
  }
}

final class FakeStorySoundtrackRepository
    implements StorySoundtrackRepository {
  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    return StorySoundtrack.noMusic();
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) {
    throw UnimplementedError();
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  ) {
    throw UnimplementedError();
  }
}
