import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:memory_map/core/config/app_config.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/playback/application/audio/just_audio_playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_orchestrator.dart';
import 'package:memory_map/features/playback/application/playback_scheduler_provider.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';

final justAudioPlayerPortFactoryProvider =
    Provider<JustAudioPlayerPortFactory>((_) {
  return () => DefaultJustAudioPlayerPort();
});

typedef PlaybackAudioControllerFactory = PlaybackAudioController Function(
  String storyId,
);

final playbackAudioControllerFactoryProvider =
    Provider<PlaybackAudioControllerFactory>((ref) {
  final appConfig = ref.watch(appConfigProvider);
  final authorizedSessionManager = ref.watch(authorizedSessionManagerProvider);
  final playerFactory = ref.watch(justAudioPlayerPortFactoryProvider);

  return (_) => JustAudioPlaybackAudioController(
        appConfig: appConfig,
        authorizedSessionManager: authorizedSessionManager,
        player: playerFactory(),
      );
});

final playbackAudioControllerProvider =
    Provider.autoDispose.family<PlaybackAudioController, String>((ref, storyId) {
  final controller = ref.watch(playbackAudioControllerFactoryProvider)(storyId);
  ref.onDispose(() {
    unawaited(controller.dispose());
  });

  return controller;
});

final playbackAudioOrchestratorProvider = Provider.autoDispose
    .family<PlaybackAudioSessionOrchestrator, String>((ref, storyId) {
  KeepAliveLink? activeSessionLink;

  void retainActiveSession() {
    activeSessionLink ??= ref.keepAlive();
  }

  void releaseActiveSession() {
    final link = activeSessionLink;
    if (link == null) {
      return;
    }

    activeSessionLink = null;
    link.close();
  }

  final audioController =
      ref.watch(playbackAudioControllerFactoryProvider)(storyId);
  final orchestrator = PlaybackAudioOrchestrator(
    storySoundtrackRepository: ref.watch(storySoundtrackRepositoryProvider),
    audioController: audioController,
    envelopeScheduler: ref.watch(playbackSchedulerProvider),
    retainSessionLifetime: retainActiveSession,
    releaseSessionLifetime: releaseActiveSession,
  );
  ref.onDispose(() {
    releaseActiveSession();
    unawaited(orchestrator.dispose());
  });

  return orchestrator;
});
