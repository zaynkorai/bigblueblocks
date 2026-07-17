import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;
  AudioPlayer? _placePlayer;
  AudioPlayer? _clearPlayer;
  AudioPlayer? _comboPlayer;
  AudioPlayer? _gameOverPlayer;
  AudioPlayer? _levelUpPlayer;
  AudioPlayer? _perfectClearPlayer;
  AudioPlayer? _highScorePlayer;
  AudioPlayer? _revivePlayer;

  bool _initialized = false;
  bool _isPlaying = false;
  bool _soundEnabled = true;

  double _currentSpeed = 1.0;
  double _currentPitch = 1.0;

  Future<void> initialize({required bool soundEnabled}) async {
    _soundEnabled = soundEnabled;
    try {
      _player = AudioPlayer();
      await _player!.setAsset('assets/audio/normal.wav');
      await _player!.setLoopMode(LoopMode.one);

      _placePlayer = AudioPlayer();
      await _placePlayer!.setAsset('assets/audio/place.wav');

      _clearPlayer = AudioPlayer();
      await _clearPlayer!.setAsset('assets/audio/clear.wav');

      _comboPlayer = AudioPlayer();
      await _comboPlayer!.setAsset('assets/audio/combo.wav');

      _gameOverPlayer = AudioPlayer();
      await _gameOverPlayer!.setAsset('assets/audio/game_over.wav');

      _levelUpPlayer = AudioPlayer();
      await _levelUpPlayer!.setAsset('assets/audio/level_up.wav');

      _perfectClearPlayer = AudioPlayer();
      await _perfectClearPlayer!.setAsset('assets/audio/perfect_clear.wav');

      _highScorePlayer = AudioPlayer();
      await _highScorePlayer!.setAsset('assets/audio/high_score.wav');

      _revivePlayer = AudioPlayer();
      await _revivePlayer!.setAsset('assets/audio/revive.wav');

      _initialized = true;
      if (_soundEnabled) {
        await play();
      }
    } catch (e) {
      debugPrint('Failed to initialize AudioService: $e');
    }
  }

  Future<void> play() async {
    if (!_initialized || _player == null) return;
    _isPlaying = true;
    try {
      await _player!.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    if (!_initialized || _player == null) return;
    _isPlaying = false;
    try {
      await _player!.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  Future<void> stop() async {
    if (!_initialized || _player == null) return;
    _isPlaying = false;
    try {
      await _player!.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    if (enabled) {
      if (!_isPlaying) {
        await play();
      }
    } else {
      await pause();
    }
  }

  Future<void> playPlaceSFX() async {
    if (!_initialized || !_soundEnabled) return;
    try {
      await _placePlayer?.seek(Duration.zero);
      await _placePlayer?.play();
    } catch (e) {
      debugPrint('Error playing place SFX: $e');
    }
  }

  Future<void> playClearSFX() async {
    if (!_initialized || !_soundEnabled) return;
    try {
      await _clearPlayer?.seek(Duration.zero);
      await _clearPlayer?.play();
    } catch (e) {
      debugPrint('Error playing clear SFX: $e');
    }
  }

  Future<void> playComboSFX() async {
    if (!_initialized || !_soundEnabled) return;
    try {
      await _comboPlayer?.seek(Duration.zero);
      await _comboPlayer?.play();
    } catch (e) {
      debugPrint('Error playing combo SFX: $e');
    }
  }

  Future<void> playGameOverSFX() async {
    if (!_initialized || !_soundEnabled) return;
    try {
      await _gameOverPlayer?.seek(Duration.zero);
      await _gameOverPlayer?.play();
    } catch (e) {
      debugPrint('Error playing game over SFX: $e');
    }
  }

  Future<void> playLevelUpSFX() async {
    if (!_initialized || !_soundEnabled) return;
    try {
      await _levelUpPlayer?.seek(Duration.zero);
      await _levelUpPlayer?.play();
    } catch (e) {
      debugPrint('Error playing level up SFX: $e');
    }
  }

  Future<void> playPerfectClearSFX() async {
    if (!_initialized || !_soundEnabled) return;
    try {
      await _perfectClearPlayer?.seek(Duration.zero);
      await _perfectClearPlayer?.play();
    } catch (e) {
      debugPrint('Error playing perfect clear SFX: $e');
    }
  }

  Future<void> playHighScoreSFX() async {
    if (!_initialized || !_soundEnabled) return;
    try {
      await _highScorePlayer?.seek(Duration.zero);
      await _highScorePlayer?.play();
    } catch (e) {
      debugPrint('Error playing high score SFX: $e');
    }
  }

  Future<void> playReviveSFX() async {
    if (!_initialized || !_soundEnabled) return;
    try {
      await _revivePlayer?.seek(Duration.zero);
      await _revivePlayer?.play();
    } catch (e) {
      debugPrint('Error playing revive SFX: $e');
    }
  }

  /// React to real-time grid fullness, combo counts, and overall game state.
  Future<void> updateGameState({
    required double fillPercentage,
    required int comboCount,
    required String gameState,
  }) async {
    if (!_initialized || _player == null) return;

    // 1. Silent BGM on Game Over or Stuck Screen
    if (gameState == 'END' || gameState == 'STUCK') {
      await _player!.setVolume(0.0);
      await pause();
      return;
    }

    // Play if enabled and was paused
    if (_soundEnabled && !_isPlaying && gameState == 'PLAY') {
      await _player!.setVolume(1.0);
      await play();
    }

    // 2. Grid density tempo calculation:
    // Speed increases subtly from 1.0x to 1.1x at 60%, and rises to 1.25x at 80% fullness
    double targetSpeed = 1.0;
    if (fillPercentage >= 0.8) {
      targetSpeed = 1.25;
    } else if (fillPercentage >= 0.6) {
      targetSpeed = 1.1;
    }

    // 3. Combo momentum pitch calculation:
    // Pitch rises by 5% per combo level starting at combo >= 2, capped at 1.25x
    double targetPitch = 1.0;
    if (comboCount >= 2) {
      targetPitch = 1.0 + (comboCount - 1) * 0.05;
      if (targetPitch > 1.25) targetPitch = 1.25;
    }

    try {
      if (targetSpeed != _currentSpeed) {
        _currentSpeed = targetSpeed;
        await _player!.setSpeed(_currentSpeed);
      }
      if (targetPitch != _currentPitch) {
        _currentPitch = targetPitch;
        await _player!.setPitch(_currentPitch);
      }
    } catch (e) {
      debugPrint('Error updating speed/pitch: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _placePlayer?.dispose();
    _placePlayer = null;
    _clearPlayer?.dispose();
    _clearPlayer = null;
    _comboPlayer?.dispose();
    _comboPlayer = null;
    _gameOverPlayer?.dispose();
    _gameOverPlayer = null;
    _levelUpPlayer?.dispose();
    _levelUpPlayer = null;
    _perfectClearPlayer?.dispose();
    _perfectClearPlayer = null;
    _highScorePlayer?.dispose();
    _highScorePlayer = null;
    _revivePlayer?.dispose();
    _revivePlayer = null;
    _initialized = false;
  }
}
