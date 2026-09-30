# Notification Sound Files

Place the following sound files in this directory for Web/Desktop platforms:

- `cyber_pulse.mp3` - Short, punchy cyberpunk notification
- `alert_neon.mp3` - Bright, attention-grabbing alert
- `subtle_beep.mp3` - Minimal, clean notification
- `ambient_chime.mp3` - Soft, atmospheric chime
- `retro_8bit.mp3` - Nostalgic 8-bit style

## Usage
These sounds are registered in `pubspec.yaml` under `flutter.assets`:
```yaml
flutter:
  assets:
    - assets/sounds/cyber_pulse.mp3
    - assets/sounds/alert_neon.mp3
    - assets/sounds/subtle_beep.mp3
    - assets/sounds/ambient_chime.mp3
    - assets/sounds/retro_8bit.mp3
```

Sounds are used by `SoundPreviewService` for preview and by the notification system.