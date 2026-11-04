import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:palturo/services/preferences_service.dart';

/// Short, non-looping UI sounds. Reuses the existing PalTuro assets and
/// respects the user's Sound preference and app lifecycle.
enum AppSound { message, match, success, undo }

class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  AudioPlayer? _player;
  Future<void>? _initFuture;
  AppSound? _lastSound;
  DateTime? _lastPlayed;

  Future<void> init() {
    final existing = _initFuture;
    if (existing != null) return existing;
    _player = AudioPlayer();
    final future = _configurePlayer();
    _initFuture = future;
    return future;
  }

  Future<void> _configurePlayer() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(respectSilence: true).build(),
      );
    } catch (_) {
      // Audio context is best-effort; playback still works on most surfaces.
    }
    try {
      await _player?.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
  }

  Future<void> play(AppSound sound) async {
    if (!PreferencesService.instance.soundEnabled) return;
    if (PreferencesService.instance.isQuietHoursNow) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    await init();

    final now = DateTime.now();
    if (_lastSound == sound &&
        _lastPlayed != null &&
        now.difference(_lastPlayed!) < const Duration(milliseconds: 150)) {
      return;
    }
    _lastSound = sound;
    _lastPlayed = now;

    final asset = _assetFor(sound);
    if (asset == null) return;
    final player = _player ??= AudioPlayer();
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: _volumeFor(sound));
    } catch (_) {
      // A failed feedback sound must never interrupt the interaction.
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> preview() => play(AppSound.match);

  @visibleForTesting
  String? assetFor(AppSound sound) => _assetFor(sound);

  @visibleForTesting
  double volumeFor(AppSound sound) => _volumeFor(sound);

  String? _assetFor(AppSound sound) {
    switch (sound) {
      case AppSound.message:
        return 'sounds/messages.wav';
      case AppSound.match:
        return 'sounds/newmatch.wav';
      case AppSound.success:
      case AppSound.undo:
        return 'sounds/splash.wav';
    }
  }

  double _volumeFor(AppSound sound) {
    switch (sound) {
      case AppSound.message:
        return 0.8;
      case AppSound.match:
        return 0.9;
      case AppSound.success:
        return 0.55;
      case AppSound.undo:
        return 0.4;
    }
  }
}
