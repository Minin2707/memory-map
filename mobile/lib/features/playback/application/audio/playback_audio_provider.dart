import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/core/config/app_config.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/playback/application/audio/just_audio_playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_controller.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_orchestrator.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';

final justAudioPlayerPortFactoryProvider =
    Provider<JustAudioPlayerPortFactory>((_) {
  return () => DefaultJustAudioPlayerPort();
});

final playbackAudioControllerProvider =
    Provider.autoDispose.family<PlaybackAudioController, String>((ref, _) {
  final controller = JustAudioPlaybackAudioController(
    appConfig: ref.watch(appConfigProvider),
    authorizedSessionManager: ref.watch(authorizedSessionManagerProvider),
    player: ref.watch(justAudioPlayerPortFactoryProvider)(),
  );
  ref.onDispose(() {
    unawaited(controller.dispose());
  });

  return controller;
});

final playbackAudioOrchestratorProvider = Provider.autoDispose
    .family<PlaybackAudioSessionOrchestrator, String>((ref, storyId) {
  final orchestrator = PlaybackAudioOrchestrator(
    storySoundtrackRepository: ref.watch(storySoundtrackRepositoryProvider),
    audioController: ref.watch(playbackAudioControllerProvider(storyId)),
  );
  ref.onDispose(() {
    unawaited(orchestrator.dispose());
  });

  return orchestrator;
});
