import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/alarm_service.dart';
import '../services/sound_preview_service.dart';
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

  static const _builtInSounds = <String, String>{
    'cyber_pulse': 'Cyber Pulse',
    'gentle_bell': 'Gentle Bell',
    'subtle_beep': 'Subtle Beep',
  };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Alarm sound',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<AlarmSoundType>(
            segments: const [
              ButtonSegment(
                value: AlarmSoundType.system,
                label: Text('System'),
                icon: Icon(Icons.alarm),
              ),
              ButtonSegment(
                value: AlarmSoundType.builtIn,
                label: Text('App'),
                icon: Icon(Icons.music_note),
              ),
              ButtonSegment(
                value: AlarmSoundType.customFile,
                label: Text('File'),
                icon: Icon(Icons.audio_file),
              ),
            ],
            selected: {type},
            onSelectionChanged: (selection) =>
                onChanged(selection.first, soundId, soundUri),
          ),
          const SizedBox(height: 10),
          if (type == AlarmSoundType.builtIn)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(soundId),
                    initialValue: _builtInSounds.containsKey(soundId)
                        ? soundId
                        : _builtInSounds.keys.first,
                    decoration:
                        const InputDecoration(labelText: 'Built-in sound'),
                    items: [
                      for (final entry in _builtInSounds.entries)
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
                IconButton(
                  tooltip: 'Preview',
                  color: AppTheme.cyan,
                  onPressed: () => SoundPreviewService.instance.toggle(soundId),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              icon: Icon(type == AlarmSoundType.system
                  ? Icons.library_music_outlined
                  : Icons.folder_open_outlined),
              label: Text(soundUri == null
                  ? type == AlarmSoundType.system
                      ? 'Choose system alarm'
                      : 'Choose audio file'
                  : type == AlarmSoundType.system
                      ? 'System alarm selected'
                      : 'Custom audio selected'),
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
