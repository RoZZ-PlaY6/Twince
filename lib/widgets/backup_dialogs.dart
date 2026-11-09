import 'package:flutter/material.dart';

import '../services/backup_library.dart';
import '../services/backup_policy.dart';
import '../theme/app_theme.dart';

enum BackupSaveChoice { current, fresh }

Future<BackupSaveChoice?> showBackupSaveDialog(
  BuildContext context, {
  required ActiveBackup? active,
}) {
  return showDialog<BackupSaveChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF0A1734),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.cyan.withValues(alpha: 0.7)),
      ),
      title: const Text('Save backup'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            active == null
                ? 'Choose a new backup file. You can keep updating it after this.'
                : 'Active file: ${active.name}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: active == null || !active.canUpdate
                ? null
                : () => Navigator.pop(dialogContext, BackupSaveChoice.current),
            child: const Text('Save to current backup file'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, BackupSaveChoice.fresh),
            child: const Text('Create a new backup file'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> showBackupNameDialog(
  BuildContext context, {
  required String initialName,
  required String title,
  required String action,
}) async {
  final controller = TextEditingController(text: initialName);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF0A1734),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.purple.withValues(alpha: 0.7)),
      ),
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Backup file name',
          hintText: 'twince_backup.json',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(action),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<void> showBackupManagerSheet(
  BuildContext context, {
  required Future<void> Function() onImport,
  required Future<void> Function() onSaveCurrent,
  required Future<void> Function() onCreateNew,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _backupNight,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _BackupManagerSheet(
      onImport: () async {
        Navigator.pop(sheetContext);
        await onImport();
      },
      onSaveCurrent: () async {
        Navigator.pop(sheetContext);
        await onSaveCurrent();
      },
      onCreateNew: () async {
        Navigator.pop(sheetContext);
        await onCreateNew();
      },
    ),
  );
}

class _BackupManagerSheet extends StatefulWidget {
  const _BackupManagerSheet({
    required this.onImport,
    required this.onSaveCurrent,
    required this.onCreateNew,
  });

  final Future<void> Function() onImport;
  final Future<void> Function() onSaveCurrent;
  final Future<void> Function() onCreateNew;

  @override
  State<_BackupManagerSheet> createState() => _BackupManagerSheetState();
}

class _BackupManagerSheetState extends State<_BackupManagerSheet> {
  ActiveBackup? _active;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final active = await BackupLibrary.instance.current();
    if (!mounted) return;
    setState(() {
      _active = active;
      _loading = false;
    });
  }

  Future<void> _rename() async {
    final active = _active;
    if (active == null) {
      setState(() => _error = 'There is no backup file to rename.');
      return;
    }
    final requested = await showBackupNameDialog(
      context,
      initialName: active.name,
      title: 'Rename backup file',
      action: 'Rename',
    );
    if (requested == null || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final renamed = await BackupLibrary.instance.rename(requested);
      if (!mounted) return;
      setState(() => _active = renamed);
    } on BackupNameException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not rename the backup file.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final canSave = !_saving && _active != null && _active!.canUpdate;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height - media.padding.top - 12,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ColoredBox(
            color: _backupNight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _backupNight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x332F5BFF),
                    blurRadius: 22,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: _BackupDragHandle()),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _backupNight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _backupElectric,
                            width: _backupBorder,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Backup',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _primaryBackupButton(
                                enabled: !_saving,
                                onPressed: _saving ? null : widget.onImport,
                                icon: const Icon(Icons.restore_outlined),
                                label: const Text('Import backup'),
                              ),
                              const SizedBox(height: 12),
                              _primaryBackupButton(
                                enabled: canSave,
                                onPressed:
                                    canSave ? widget.onSaveCurrent : null,
                                label: const Text('Save to current backup'),
                              ),
                              if (_active == null || !_active!.canUpdate)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Import a backup or create one before saving to the current file.',
                                    style: TextStyle(
                                      color: _backupMuted,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _saving ? null : widget.onCreateNew,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _backupViolet,
                                  disabledForegroundColor: _backupMuted,
                                  backgroundColor: _backupNight,
                                  minimumSize: const Size.fromHeight(48),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  side: const BorderSide(
                                    color: _backupElectric,
                                    width: _backupBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(_backupRadius),
                                  ),
                                ),
                                child: const Text('Create new backup'),
                              ),
                              const SizedBox(height: 16),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _backupPanel,
                                  borderRadius:
                                      BorderRadius.circular(_backupRadius),
                                  border: Border.all(
                                    color: _backupCyan,
                                    width: _backupBorder,
                                  ),
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  child: _loading
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              _active == null
                                                  ? 'Current backup: none'
                                                  : 'Current backup: ${_active!.name}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: _backupMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            _primaryBackupButton(
                                              enabled: !_saving,
                                              onPressed:
                                                  _saving ? null : _rename,
                                              label: Text(_saving
                                                  ? 'Saving…'
                                                  : 'Rename backup file'),
                                            ),
                                            if (_error != null) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                _error!,
                                                style: const TextStyle(
                                                  color: Color(0xFFFFB4AB),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _backupNight = Color(0xFF070B16);
const _backupPanel = Color(0xFF0E162B);
const _backupElectric = Color(0xFF4C8DFF);
const _backupCyan = Color(0xFF22D3EE);
const _backupViolet = Color(0xFFC4B5FD);
const _backupMuted = Color(0xFF93A4BC);
const _backupRadius = 16.0;
const _backupBorder = 1.0;

class _BackupDragHandle extends StatelessWidget {
  const _BackupDragHandle();

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFD0D5DD),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

Widget _primaryBackupButton({
  required bool enabled,
  required VoidCallback? onPressed,
  required Widget label,
  Widget? icon,
}) {
  final button = icon == null
      ? FilledButton(
          onPressed: onPressed,
          style: _primaryBackupStyle(),
          child: label,
        )
      : FilledButton.icon(
          onPressed: onPressed,
          style: _primaryBackupStyle(),
          icon: icon,
          label: label,
        );
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_backupRadius),
      gradient: enabled ? _backupActionGradient : null,
      color: enabled ? null : const Color(0xFF121A2C),
      border: Border.all(
        color: enabled ? Colors.transparent : const Color(0xFF3A4C68),
        width: _backupBorder,
      ),
    ),
    child: button,
  );
}

const _backupActionGradient = LinearGradient(
  colors: [Color(0xFF06B6D4), Color(0xFF7C3AED)],
);

ButtonStyle _primaryBackupStyle() => FilledButton.styleFrom(
      backgroundColor: Colors.transparent,
      disabledBackgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      disabledForegroundColor: _backupMuted,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_backupRadius)),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.14);
        }
        return Colors.white.withValues(alpha: 0.06);
      }),
    );
