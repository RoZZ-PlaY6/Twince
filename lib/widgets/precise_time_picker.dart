import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Returns the selected hour and minute, retaining existing stored seconds.
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
  late int _hour; // 1-12
  late int _minute; // 0-59
  late bool _isPm;

  @override
  void initState() {
    super.initState();
    _isPm = widget.initialTime.hour >= 12;
    final hour12 = widget.initialTime.hour % 12;
    _hour = hour12 == 0 ? 12 : hour12; // 1-12 for display
    _minute = widget.initialTime.minute;
  }

  int get _hour24 => _hour % 12 + (_isPm ? 12 : 0);

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1734),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AppTheme.cyan.withValues(alpha: 0.75),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.purple, AppTheme.cyan],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                _selector(
                  'Hour',
                  List<int>.generate(12, (i) => i + 1), // 1-12
                  _hour,
                  (v) => setState(() => _hour = v),
                ),
                _selector(
                  'Minute',
                  List<int>.generate(60, (i) => i), // 0-59
                  _minute,
                  (v) => setState(() => _minute = v),
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
                    widget.initialTime.second,
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
        width: 104,
        child: DropdownButtonFormField<T>(
          key: ValueKey('select-$label'),
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppTheme.blue.withValues(alpha: 0.55),
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: const Color(0xA814264B),
          ),
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          items: options
              .map(
                (opt) => DropdownMenuItem(
                  value: opt,
                  child: Text(
                    opt is int
                        ? opt.toString().padLeft(2, '0')
                        : opt.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      );
}
