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
    showDragHandle: true,
    backgroundColor: const Color(0xFF071126),
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
  final _name = TextEditingController();
  ActiveBackup? _active;
  bool _loading = true;
  bool _saving = false;

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
      _name.text = active?.name ?? '';
      _loading = false;
    });
  }

  Future<void> _rename() async {
    setState(() => _saving = true);
    try {
      final renamed = await BackupLibrary.instance.rename(_name.text);
      if (!mounted) return;
      setState(() => _active = renamed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Active backup is now ${renamed.name}.')),
      );
    } on BackupNameException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename the backup file.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Backup',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : widget.onImport,
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Import backup'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving || _active == null || !_active!.canUpdate
                  ? null
                  : widget.onSaveCurrent,
              child: const Text('Save to current backup'),
            ),
            if (_active == null || !_active!.canUpdate)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Import a backup or create one before saving to the current file.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : widget.onCreateNew,
              child: const Text('Create new backup'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xB20B1B3A),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppTheme.cyan.withValues(alpha: 0.55)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _active == null
                              ? 'Current backup: none'
                              : 'Current backup: ${_active!.name}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Backup file name',
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed:
                                _saving || _active == null ? null : _rename,
                            child: Text(_saving ? 'Saving…' : 'Rename'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
