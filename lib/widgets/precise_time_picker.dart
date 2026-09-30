import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Returns a local time carrying hour, minute, and second from structured selection.
Future<DateTime?> showPreciseTimePicker({
  required BuildContext context,
  required DateTime initialTime,
  required String label,
}) =>
    showDialog<DateTime>(
      context: context,
      builder: (_) =>
          _PreciseTimeDialog(initialTime: initialTime, label: label),
    );

class _PreciseTimeDialog extends StatefulWidget {
  const _PreciseTimeDialog({required this.initialTime, required this.label});

  final DateTime initialTime;
  final String label;

  @override
  State<_PreciseTimeDialog> createState() => _PreciseTimeDialogState();
}

class _PreciseTimeDialogState extends State<_PreciseTimeDialog> {
  late int _hour; // 0-23
  late int _minute; // 0-59
  late int _second; // 0-59
  late bool _isPm;

  @override
  void initState() {
    super.initState();
    _isPm = widget.initialTime.hour >= 12;
    final hour12 = widget.initialTime.hour % 12;
    _hour = hour12 == 0 ? 12 : hour12; // 1-12 for display
    _minute = widget.initialTime.minute;
    _second = widget.initialTime.second;
  }

  int get _hour24 => _hour % 12 + (_isPm ? 12 : 0);

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.cyan),
        ),
        title: Text(widget.label, style: const TextStyle(color: AppTheme.cyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _selector(
                  'Hour',
                  List<int>.generate(12, (i) => i + 1), // 1-12
                  _hour,
                  (v) => setState(() => _hour = v),
                ),
                const SizedBox(width: 8),
                _selector(
                  'Minute',
                  List<int>.generate(60, (i) => i), // 0-59
                  _minute,
                  (v) => setState(() => _minute = v),
                ),
                const SizedBox(width: 8),
                _selector(
                  'Second',
                  List<int>.generate(60, (i) => i), // 0-59
                  _second,
                  (v) => setState(() => _second = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('AM')),
                ButtonSegment(value: true, label: Text('PM')),
              ],
              selected: {_isPm},
              onSelectionChanged: (selection) =>
                  setState(() => _isPm = selection.single),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                  context,
                  DateTime(
                    widget.initialTime.year,
                    widget.initialTime.month,
                    widget.initialTime.day,
                    _hour24,
                    _minute,
                    _second,
                  ));
            },
            child: const Text('Set time'),
          ),
        ],
      );

  Widget _selector<T>(
    String label,
    List<T> options,
    T value,
    void Function(T) onChanged,
  ) =>
      SizedBox(
        width: 90,
        child: DropdownButtonFormField<T>(
          key: ValueKey('select-$label'),
          value: value,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: AppTheme.background,
          ),
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          items: options
              .map(
                (opt) => DropdownMenuItem(
                  value: opt,
                  child: Text(
                    opt is int ? opt.toString().padLeft(2, '0') : opt.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      );
}
