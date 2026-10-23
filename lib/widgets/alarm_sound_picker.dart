import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/alarm_service.dart';
import '../services/sound_preview_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';

class AlarmSoundPicker extends StatelessWidget {
  const AlarmSoundPicker({
    super.key,
    required this.type,
    required this.soundId,
    required this.soundUri,
    required this.onChanged,
  });

  final AlarmSoundType type;
  final String soundId;
  final String? soundUri;
  final void Function(AlarmSoundType type, String soundId, String? uri)
      onChanged;

  static const builtInSounds = builtInAlarmSounds;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Alarm sound source',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('System'),
                avatar: const Icon(Icons.alarm_rounded, size: 17),
                selected: type == AlarmSoundType.system,
                selectedColor: AppTheme.purple.withValues(alpha: 0.5),
                side: BorderSide(
                  color: type == AlarmSoundType.system
                      ? AppTheme.cyan
                      : AppTheme.blue.withValues(alpha: 0.35),
                ),
                onSelected: (_) =>
                    onChanged(AlarmSoundType.system, soundId, soundUri),
              ),
              ChoiceChip(
                label: const Text('App'),
                avatar: const Icon(Icons.music_note_rounded, size: 17),
                selected: type == AlarmSoundType.builtIn,
                selectedColor: AppTheme.purple.withValues(alpha: 0.5),
                side: BorderSide(
                  color: type == AlarmSoundType.builtIn
                      ? AppTheme.cyan
                      : AppTheme.blue.withValues(alpha: 0.35),
                ),
                onSelected: (_) =>
                    onChanged(AlarmSoundType.builtIn, soundId, soundUri),
              ),
              ChoiceChip(
                label: const Text('File'),
                avatar: const Icon(Icons.audio_file_rounded, size: 17),
                selected: type == AlarmSoundType.customFile,
                selectedColor: AppTheme.purple.withValues(alpha: 0.5),
                side: BorderSide(
                  color: type == AlarmSoundType.customFile
                      ? AppTheme.cyan
                      : AppTheme.blue.withValues(alpha: 0.35),
                ),
                onSelected: (_) =>
                    onChanged(AlarmSoundType.customFile, soundId, soundUri),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (type == AlarmSoundType.builtIn)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xA814264B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.blue.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(soundId),
                      initialValue: builtInSounds.containsKey(soundId)
                          ? soundId
                          : builtInSounds.keys.first,
                      decoration:
                          const InputDecoration(labelText: 'Built-in sound'),
                      items: [
                        for (final entry in builtInSounds.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onChanged(AlarmSoundType.builtIn, value, null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Preview',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.purple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        SoundPreviewService.instance.toggle(soundId),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xA814264B),
                foregroundColor: Colors.white,
                side: BorderSide(color: AppTheme.blue.withValues(alpha: 0.55)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
              icon: Icon(type == AlarmSoundType.system
                  ? Icons.library_music_outlined
                  : Icons.folder_open_outlined),
              label: Text(
                soundUri == null
                    ? type == AlarmSoundType.system
                        ? 'Choose system alarm'
                        : 'Choose audio file'
                    : type == AlarmSoundType.system
                        ? 'System alarm selected'
                        : 'Custom audio selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () async {
                final selection = type == AlarmSoundType.system
                    ? await AlarmService.instance.pickSystemSound()
                    : await AlarmService.instance.pickCustomAudio();
                if (selection != null) {
                  onChanged(type, selection.label, selection.uri);
                }
              },
            ),
        ],
      );
}
