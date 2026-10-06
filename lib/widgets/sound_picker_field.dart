import 'package:flutter/material.dart';
import 'dart:async';

import '../../theme/app_theme.dart';
import '../../services/sound_preview_service.dart';

/// A reusable sound picker field with preview capability.
/// Uses ValueNotifier for localized state updates to avoid parent rebuilds.
class SoundPickerField extends StatefulWidget {
  const SoundPickerField({
    super.key,
    required this.label,
    required this.selectedSoundId,
    this.customSystemSoundUri,
    this.onChanged,
    this.onPickSystemSound,
    this.hintText,
    this.validator,
  });

  final String label;
  final String selectedSoundId;
  final String? customSystemSoundUri;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onPickSystemSound;
  final String? hintText;
  final FormFieldValidator<String>? validator;

  @override
  State<SoundPickerField> createState() => _SoundPickerFieldState();
}

class _SoundPickerFieldState extends State<SoundPickerField> {
  final SoundPreviewService _soundService = SoundPreviewService.instance;
  late StreamSubscription<bool> _playingSubscription;

  // Use ValueNotifier for localized rebuilds of the play button only
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _playingSoundIdNotifier =
      ValueNotifier<String?>(null);

  // Cache sounds to avoid reloading on every build
  List<NotificationSound> _availableSounds = [];
  bool _soundsLoaded = false;
  String? _validatedSoundId;

  @override
  void initState() {
    super.initState();
    _playingSubscription = _soundService.isPlayingStream.listen((playing) {
      _isPlayingNotifier.value = playing;
      _playingSoundIdNotifier.value =
          playing ? _soundService.currentSoundId : null;
    });
    _loadAndValidateSounds();
  }

  Future<void> _loadAndValidateSounds() async {
    if (_soundsLoaded) return;

    // First, validate and correct the selected sound ID
    _validatedSoundId =
        await _soundService.validateSoundId(widget.selectedSoundId);

    final sounds = await _soundService.getAvailableSounds(
      customSystemSoundUri: widget.customSystemSoundUri,
    );
    if (mounted) {
      setState(() {
        _availableSounds = sounds;
        _soundsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _playingSubscription.cancel();
    _isPlayingNotifier.dispose();
    _playingSoundIdNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the validated sound ID for the form field
    final effectiveSoundId = _validatedSoundId ?? widget.selectedSoundId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        if (!_soundsLoaded)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          FormField<String>(
            initialValue: effectiveSoundId,
            validator: widget.validator,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dropdown with sound selection
                DropdownButtonFormField<String>(
                  value: effectiveSoundId,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppTheme.cyan, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  isExpanded: true,
                  items: _availableSounds.map((sound) {
                    return DropdownMenuItem<String>(
                      value: sound.id,
                      child: Row(
                        children: [
                          if (sound.isPicker)
                            const Icon(
                              Icons.library_music_outlined,
                              size: 20,
                              color: AppTheme.purple,
                            )
                          else
                            const Icon(
                              Icons.music_note_outlined,
                              size: 20,
                              color: AppTheme.cyan,
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  sound.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (sound.description.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      sound.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white38,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    final sound =
                        _availableSounds.firstWhere((s) => s.id == value);

                    if (sound.isPicker) {
                      // Trigger system picker
                      widget.onPickSystemSound?.call();
                      // Reset to previous value since picker is async
                      Future.delayed(const Duration(milliseconds: 100), () {
                        field.didChange(widget.selectedSoundId);
                      });
                    } else {
                      field.didChange(value);
                      _validatedSoundId = value; // Update validated sound ID
                      widget.onChanged?.call(value);
                    }
                  },
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 12),
                    child: Text(
                      field.errorText!,
                      style: TextStyle(
                        color: AppTheme.failed,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Preview player row - uses ValueListenableBuilder for isolated rebuilds
                _buildPreviewPlayer(effectiveSoundId),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewPlayer(String effectiveSoundId) {
    if (_availableSounds.isEmpty) return const SizedBox.shrink();

    final currentSound = _availableSounds.firstWhere(
      (s) => s.id == effectiveSoundId,
      orElse: () => _availableSounds.first,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: _isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: _playingSoundIdNotifier,
          builder: (context, playingSoundId, _) {
            final isCurrentPlaying =
                isPlaying && playingSoundId == effectiveSoundId;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrentPlaying
                      ? AppTheme.cyan.withOpacity(0.5)
                      : AppTheme.purple.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  // Sound info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Preview: ${currentSound.name}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color:
                                isCurrentPlaying ? AppTheme.cyan : Colors.white,
                          ),
                        ),
                        if (currentSound.description.isNotEmpty)
                          Flexible(
                            child: Text(
                              currentSound.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white38,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Play/Stop button with glow effect - isolated rebuild
                  // Play/Stop button with glow effect - isolated rebuild
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPlayingNotifier,
                    builder: (context, _, __) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: _playingSoundIdNotifier,
                        builder: (context, playingSoundId, __) {
                          final isCurrentPlaying = _isPlayingNotifier.value &&
                              playingSoundId == effectiveSoundId;
                          return _GlowingPlayButton(
                            isPlaying: isCurrentPlaying,
                            color: isCurrentPlaying
                                ? AppTheme.cyan
                                : AppTheme.purple,
                            onPressed: () async {
                              if (isCurrentPlaying) {
                                await _soundService.stop();
                              } else {
                                if (currentSound.isSystemSound &&
                                    currentSound.systemUri != null) {
                                  await _soundService.playSound(
                                    effectiveSoundId,
                                    customUri: currentSound.systemUri,
                                  );
                                } else {
                                  await _soundService
                                      .playSound(effectiveSoundId);
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Glowing circular play/stop button with cyberpunk aesthetic
class _GlowingPlayButton extends StatefulWidget {
  const _GlowingPlayButton({
    required this.isPlaying,
    required this.color,
    required this.onPressed,
  });

  final bool isPlaying;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_GlowingPlayButton> createState() => _GlowingPlayButtonState();
}

class _GlowingPlayButtonState extends State<_GlowingPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              if (widget.isPlaying)
                BoxShadow(
                  color: widget.color.withOpacity(0.4 * _pulseAnimation.value),
                  blurRadius: 20 * _pulseAnimation.value,
                  spreadRadius: 2 * _pulseAnimation.value,
                ),
              BoxShadow(
                color: widget.color.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onPressed,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withOpacity(0.9),
                      widget.color,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: widget.color.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  widget.isPlaying
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
