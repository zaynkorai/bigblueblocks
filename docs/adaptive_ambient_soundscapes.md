# Adaptive Ambient Soundscapes Plan

This document outlines the design, architecture, and step-by-step integration process for implementing dynamic, adaptive background music that reacts to the live state of the game in Big Blue Blocks.

## Target Experience
1. **Normal Play**: Play soft, soothing looping music at standard speed/pitch.
2. **80% Grid Fill warning**: Increase tempo/tension dynamically (e.g. increase playback speed to `1.25x`) when the grid is 80% or more full, alerting the player of danger.
3. **Combo Momentum**: Increase the music pitch starting at a combo level of 2 (`comboCount >= 2`) by `+5%` per combo tier to heighten the sense of reward and momentum.
4. **App Lifecycle & Game Over**: Pause BGM when the app moves to the background; stop/fade BGM when a Game Over screen appears.

---

## Integration Checklist
- [ ] **Step 1: Add Dependency & Assets** (Register `just_audio` and prepare looping audio assets)
- [ ] **Step 2: Create Ambient Audio Service** (Implement a custom singleton audio controller)
- [ ] **Step 3: Initialize Service in Main App State** (Wire up lifecycle observers and config loading)
- [ ] **Step 4: Hook State Updates** (Invoke state callbacks on moves, clears, and restarts)
- [ ] **Step 5: Settings Dialog Update** (Provide clean controls for the soundtrack volume/toggles)

---

## 1. Add Dependency & Assets

Add the `just_audio` package to `app/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  just_audio: ^0.9.38
```

Register the new audio assets folder:

```yaml
flutter:
  assets:
    - assets/icon.png
    - assets/audio/
```

> **Note**: Place your looping theme (e.g., `ambient_normal.mp3`) under `app/assets/audio/`.

---

## 2. Create Ambient Audio Service

Create the file `app/lib/services/ambient_audio_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AmbientAudioService {
  static final AmbientAudioService _instance = AmbientAudioService._internal();
  factory AmbientAudioService() => _instance;
  AmbientAudioService._internal();

  AudioPlayer? _player;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _soundEnabled = true;

  double _currentSpeed = 1.0;
  double _currentPitch = 1.0;

  Future<void> initialize({required bool soundEnabled}) async {
    _soundEnabled = soundEnabled;
    try {
      _player = AudioPlayer();
      await _player!.setAsset('assets/audio/ambient_normal.mp3');
      await _player!.setLoopMode(LoopMode.one);
      _initialized = true;
      if (_soundEnabled) {
        await play();
      }
    } catch (e) {
      debugPrint('Failed to initialize AmbientAudioService: $e');
    }
  }

  Future<void> play() async {
    if (!_initialized || _player == null) return;
    _isPlaying = true;
    try {
      await _player!.play();
    } catch (e) {
      debugPrint('Error playing ambient audio: $e');
    }
  }

  Future<void> pause() async {
    if (!_initialized || _player == null) return;
    _isPlaying = false;
    try {
      await _player!.pause();
    } catch (e) {
      debugPrint('Error pausing ambient audio: $e');
    }
  }

  Future<void> stop() async {
    if (!_initialized || _player == null) return;
    _isPlaying = false;
    try {
      await _player!.stop();
    } catch (e) {
      debugPrint('Error stopping ambient audio: $e');
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
      debugPrint('Error updating ambient speed/pitch: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _initialized = false;
  }
}
```

---

## 3. Initialize Service in Main App State

In `app/lib/main.dart`:

1. **Import the Service**:
   ```dart
   import 'services/ambient_audio_service.dart';
   ```

2. **Initialize after Settings Load**:
   Inside `_loadSettings()` once the async settings have been parsed:
   ```dart
   AmbientAudioService().initialize(soundEnabled: _soundEnabled);
   ```

3. **Handle App Lifecycle Lifecycle Transitions**:
   Extend `didChangeAppLifecycleState(AppLifecycleState state)` to pause BGM when application focus is lost:
   ```dart
   if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
     AmbientAudioService().pause();
   }
   if (state == AppLifecycleState.resumed && _soundEnabled) {
     AmbientAudioService().play();
   }
   ```

4. **Settings Syncing**:
   Ensure `onSoundChanged` callback triggers state synchronization on the service:
   ```dart
   onSoundChanged: (v) {
     setState(() => _soundEnabled = v);
     _saveSettings();
     AmbientAudioService().setSoundEnabled(v);
   }
   ```

---

## 4. Hook State Updates

Create a state update method in `_GameScreenState` of `app/lib/main.dart` to calculate board density and notify the audio controller:

```dart
void _updateAudioState() {
  final filledCount = grid.expand((row) => row).where((cell) => cell != 0).length;
  final fillPercent = filledCount / (gridSize * gridSize);
  AmbientAudioService().updateGameState(
    fillPercentage: fillPercent,
    comboCount: comboCount,
    gameState: gameState,
  );
}
```

Call `_updateAudioState()` inside:
- `initGame()`: At the end of the method, setting the starting pitch and volume.
- `_tryCompletePlacement()`: After performing lines cleared checks, checking perfect clears, and verifying if any pieces can fit (the game over condition check).

---

## 5. Verification Plan

- Run tests to check compilation validity:
  ```bash
  flutter test
  ```
- Test normal loop functionality and setting mutability.
- Minimize/resume the app and check pause states.
- Force board cells to fill up to 80% to verify playback speed increases.
- Trigger combo chains to verify pitch rises.
