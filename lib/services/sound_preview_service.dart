import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for playing notification sound previews.
/// Supports both asset sounds (Web/Desktop) and system sounds (Android).
class SoundPreviewService {
  SoundPreviewService._() {
    _initializePlayerListeners();
  }
  static final SoundPreviewService instance = SoundPreviewService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _currentSoundId;

  // Stream for playback state changes
  final _stateController = StreamController<bool>.broadcast();
  Stream<bool> get isPlayingStream => _stateController.stream;

  bool get isPlaying => _isPlaying;
  String? get currentSoundId => _currentSoundId;

  // Cache for discovered sounds
  List<NotificationSound>? _cachedAssetSounds;
  bool _soundsLoaded = false;

  /// Default fallback sounds (used when asset manifest fails or on Web)
  static const List<NotificationSound> _defaultSounds = [
    NotificationSound(
      id: 'subtle_beep',
      name: 'Subtle Beep',
      assetPath: 'assets/sounds/subtle_beep.mp3',
      description: 'Minimal, clean notification',
    ),
    NotificationSound(
      id: 'cyber_pulse',
      name: 'Cyber Pulse',
      assetPath: 'assets/sounds/cyber_pulse.mp3',
      description: 'Short, punchy cyberpunk notification',
    ),
    NotificationSound(
      id: 'gentle_bell',
      name: 'Gentle Bell',
      assetPath: 'assets/sounds/gentle_bell.mp3',
      description: 'Soft, pleasant bell tone',
    ),
  ];

  /// Stream controller for sound list changes
  final _soundsChangedController = StreamController<void>.broadcast();
  Stream<void> get soundsChangedStream => _soundsChangedController.stream;

  void _initializePlayerListeners() {
    // Listen to player state changes to auto-reset on completion
    _player.onPlayerComplete.listen((_) {
      _handlePlaybackEnded();
    });

    // Use PlayerState stream to handle completion/buffering/disposed
    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.disposed) {
        _handlePlaybackEnded();
      }
    });
  }

  void _handlePlaybackEnded() {
    if (_isPlaying) {
      _isPlaying = false;
      _currentSoundId = null;
      _stateController.add(false);
      debugPrint('SoundPreviewService: Playback ended naturally, state reset');
    }
  }

  /// Load sounds dynamically from the asset manifest with timeout and fallback
  Future<List<NotificationSound>> _loadAssetSounds() async {
    if (_soundsLoaded && _cachedAssetSounds != null) {
      return _cachedAssetSounds!;
    }

    // Try to load from asset manifest with 2-second timeout
    List<NotificationSound>? loadedSounds;
    try {
      loadedSounds = await _loadFromManifestWithTimeout();
    } catch (e) {
      debugPrint('SoundPreviewService: Asset manifest loading failed: $e');
    }

    // If loading failed or returned empty, use fallback
    if (loadedSounds == null || loadedSounds.isEmpty) {
      debugPrint('SoundPreviewService: Using fallback sound list');
      _cachedAssetSounds = _defaultSounds;
      _soundsLoaded = true;
      return _defaultSounds;
    }

    // Deduplicate by ID (keep first occurrence)
    final seenIds = <String>{};
    final deduplicated = loadedSounds.where((s) => seenIds.add(s.id)).toList();
    if (deduplicated.length != loadedSounds.length) {
      debugPrint('SoundPreviewService: Removed ${loadedSounds.length - deduplicated.length} duplicate sound(s)');
    }

    _cachedAssetSounds = deduplicated;
    _soundsLoaded = true;
    debugPrint('SoundPreviewService: Loaded ${deduplicated.length} sounds from asset manifest');
    _notifySoundsChanged();
    return deduplicated;
  }

  /// Notify listeners that sounds have changed
  void _notifySoundsChanged() {
    _soundsChangedController.add(null);
  }

  /// Public method to refresh the sound cache (e.g., when sounds are added/removed)
  Future<void> refreshSounds() async {
    _soundsLoaded = false;
    _cachedAssetSounds = null;
    await _loadAssetSounds();
  }

  /// Get all available sound IDs for validation
  Future<Set<String>> getAvailableSoundIds() async {
    final sounds = await _loadAssetSounds();
    return sounds.map((s) => s.id).toSet();
  }

  /// Validate and correct a sound ID against available sounds.
  /// Returns a valid sound ID (first available) or null if no sounds available.
  Future<String?> validateSoundId(String? soundId) async {
    if (soundId == null || soundId.isEmpty) return null;
    
    final sounds = await _loadAssetSounds();
    if (sounds.isEmpty) return null;
    
    // Check if the sound ID exists
    final exists = sounds.any((s) => s.id == soundId);
    if (exists) return soundId;
    
    // Fallback to first available sound
    debugPrint('SoundPreviewService: Sound ID "$soundId" not found, falling back to "${sounds.first.id}"');
    return sounds.first.id;
  }

  /// Get a valid sound ID for the given ID, or fallback to default
  Future<String> getValidSoundIdOrDefault(String? soundId) async {
    final validated = await validateSoundId(soundId);
    return validated ?? _defaultSounds.first.id;
  }

  /// Load sounds from AssetManifest with 2-second timeout
  Future<List<NotificationSound>?> _loadFromManifestWithTimeout() async {
    try {
      // Use the modern AssetManifest API with 2-second timeout
      final manifestFuture = AssetManifest.loadFromAssetBundle(rootBundle);
      final manifest = await manifestFuture.timeout(const Duration(seconds: 2));

      final soundAssets = manifest.listAssets()
          .where((key) =>
              key.startsWith('assets/sounds/') &&
              (key.endsWith('.mp3') ||
                  key.endsWith('.wav') ||
                  key.endsWith('.ogg')))
          .toList();

      if (soundAssets.isEmpty) {
        debugPrint('SoundPreviewService: No sound assets found in manifest');
        return null;
      }

      final sounds = soundAssets.map((path) {
        final fileName = path.split('/').last;
        final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        final displayName = _toDisplayName(nameWithoutExt);
        final id = nameWithoutExt.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

        return NotificationSound(
          id: id,
          name: displayName,
          assetPath: path,
          description: _generateDescription(nameWithoutExt),
        );
      }).toList();

      sounds.sort((a, b) => a.name.compareTo(b.name));
      return sounds;
    } on TimeoutException {
      debugPrint('SoundPreviewService: Asset manifest loading timed out after 2 seconds');
      return null;
    } catch (e) {
      debugPrint('SoundPreviewService: Error loading from AssetManifest: $e');
      return null;
    }
  }

  /// Convert snake_case or kebab-case filename to Title Case display name
  String _toDisplayName(String name) {
    return name
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Generate a description based on the sound name
  String _generateDescription(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('cyber') || lower.contains('pulse')) {
      return 'Short, punchy cyberpunk notification';
    }
    if (lower.contains('alert') || lower.contains('neon')) {
      return 'Bright, attention-grabbing alert';
    }
    if (lower.contains('subtle') || lower.contains('beep')) {
      return 'Minimal, clean notification';
    }
    if (lower.contains('ambient') || lower.contains('chime')) {
      return 'Soft, atmospheric chime';
    }
    if (lower.contains('retro') || lower.contains('8bit') || lower.contains('8_bit')) {
      return 'Nostalgic 8-bit style';
    }
    if (lower.contains('gentle') || lower.contains('bell')) {
      return 'Soft, pleasant bell tone';
    }
    return 'Custom notification sound';
  }

  /// Get all available asset sounds (loads on first call)
  Future<List<NotificationSound>> getAssetSounds() async {
    return _loadAssetSounds();
  }

  /// Clean asset path by removing leading 'assets/' prefixes
  String _cleanAssetPath(String path) {
    String cleanPath = path;
    while (cleanPath.startsWith('assets/')) {
      cleanPath = cleanPath.substring(7);
    }
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    return cleanPath;
  }

  /// Play a sound by ID
  Future<void> playSound(String soundId, {String? customUri}) async {
    try {
      await _player.stop();

      if (customUri != null && customUri.isNotEmpty) {
        // Android system sound (ringtone/notification URI)
        if (kIsWeb) {
          debugPrint('SoundPreviewService: Cannot play system URI on Web');
          return;
        }
        await _player.play(DeviceFileSource(customUri));
      } else {
        // Find asset sound
        final sounds = await _loadAssetSounds();
        if (sounds.isEmpty) {
          debugPrint('SoundPreviewService: No sounds available');
          return;
        }
        final sound = sounds.firstWhere(
          (s) => s.id == soundId,
          orElse: () => sounds.first,
        );

        // Clean the asset path to remove leading 'assets/' prefixes
        final cleanPath = _cleanAssetPath(sound.assetPath);

        if (kIsWeb) {
          await _player.play(AssetSource(cleanPath));
        } else {
          // On Android/Windows, try asset first
          await _player.play(AssetSource(cleanPath));
        }

        _isPlaying = true;
        _currentSoundId = soundId;
        _stateController.add(true);
        debugPrint('SoundPreviewService: Playing $soundId (clean path: $cleanPath)');
      }
    } catch (e) {
      debugPrint('SoundPreviewService: Error playing sound: $e');
      _isPlaying = false;
      _stateController.add(false);
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _currentSoundId = null;
      _stateController.add(false);
      debugPrint('SoundPreviewService: Stopped');
    } catch (e) {
      debugPrint('SoundPreviewService: Error stopping: $e');
    }
  }

  /// Toggle play/stop for a sound
  Future<void> toggle(String soundId, {String? customUri}) async {
    if (_isPlaying && _currentSoundId == soundId) {
      await stop();
    } else {
      await playSound(soundId, customUri: customUri);
    }
  }

  /// Get all available sounds for current platform
  Future<List<NotificationSound>> getAvailableSounds({String? customSystemSoundUri}) async {
    final assetSounds = await _loadAssetSounds();

    if (kIsWeb) {
      return assetSounds;
    }
    if (!kIsWeb && Platform.isAndroid) {
      // On Android, include asset sounds + option for system picker
      final sounds = List<NotificationSound>.from(assetSounds);
      if (customSystemSoundUri != null && customSystemSoundUri.isNotEmpty) {
        sounds.insert(0, NotificationSound(
          id: 'system_custom',
          name: 'Custom System Sound',
          assetPath: '',
          description: 'Selected from system ringtone picker',
          isSystemSound: true,
          systemUri: customSystemSoundUri,
        ));
      } else {
        sounds.insert(0, NotificationSound(
          id: 'system_picker',
          name: 'Pick from System…',
          assetPath: '',
          description: 'Open system ringtone picker',
          isSystemSound: true,
          isPicker: true,
        ));
      }
      return sounds;
    }
    // Windows/Linux/macOS
    return assetSounds;
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
  }
}

/// Represents a notification sound option
class NotificationSound {
  const NotificationSound({
    required this.id,
    required this.name,
    required this.assetPath,
    this.description = '',
    this.isSystemSound = false,
    this.isPicker = false,
    this.systemUri,
  });

  final String id;
  final String name;
  final String assetPath; // Empty for system sounds
  final String description;
  final bool isSystemSound;
  final bool isPicker;
  final String? systemUri;
}