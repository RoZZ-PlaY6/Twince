import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backup_library.dart';
import '../services/backup_policy.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'backup_dialogs.dart';

class ExportBackupButton extends StatefulWidget {
  const ExportBackupButton({super.key});

  @override
  State<ExportBackupButton> createState() => _ExportBackupButtonState();
}

class _ExportBackupButtonState extends State<ExportBackupButton> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    if (_exporting) return;
    final storage = context.read<StorageService>();
    final active = await BackupLibrary.instance.current();
    if (!mounted) return;
    final choice = await showBackupSaveDialog(context, active: active);
    if (choice == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final contents = ExportService.instance.encodeBackup(storage);
      if (contents == null) {
        _message('No data to back up.');
        return;
      }
      if (choice == BackupSaveChoice.current) {
        await _saveCurrent(contents);
        return;
      }
      await _createNew(contents);
    } on BackupNameException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Backup failed.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveCurrent(String contents) async {
    final saved = await BackupLibrary.instance.saveCurrent(contents);
    if (!mounted) return;
    _message(
      saved.saved
          ? 'Updated ${saved.name}.'
          : 'Could not update the original backup. Write access may be unavailable or expired. Import the file again or create a new backup.',
    );
  }

  Future<void> _createNew(String contents) async {
    final requested = await showBackupNameDialog(
      context,
      initialName: timestampedBackupName(DateTime.now()),
      title: 'New backup file',
      action: 'Create',
    );
    if (requested == null || !mounted) return;
    final created = await BackupLibrary.instance.createNew(
      name: requested,
      contents: contents,
    );
    final shared =
        await ExportService.instance.shareExisting(created.path, created.name);
    if (!mounted) return;
    _message(switch (shared.status) {
      ExportStatus.shared => 'Created ${created.name}.',
      ExportStatus.noData => 'No data to back up.',
      ExportStatus.unavailable => created.path == null
          ? 'This platform cannot write the backup file.'
          : 'Saved ${created.name}. Sharing is unavailable here.',
    });
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openBackup() async {
    await showBackupManagerSheet(
      context,
      onImport: _import,
      onSaveCurrent: () async {
        final storage = context.read<StorageService>();
        final contents = ExportService.instance.encodeBackup(storage);
        if (contents == null) {
          _message('No data to back up.');
          return;
        }
        await _saveCurrent(contents);
      },
      onCreateNew: () async {
        final storage = context.read<StorageService>();
        final contents = ExportService.instance.encodeBackup(storage);
        if (contents == null) {
          _message('No data to back up.');
          return;
        }
        try {
          await _createNew(contents);
        } on BackupNameException catch (error) {
          _message(error.message);
        }
      },
    );
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final result = await ImportService.instance
          .pickAndImport(context.read<StorageService>());
      if (!mounted || result.status == ImportStatus.cancelled) return;
      final message = switch (result.status) {
        ImportStatus.success => result.backupWritable
            ? 'Restored ${result.backupName}. Later saves can update this file.'
            : 'Restored ${result.tasksImported} tasks and ${result.recurringImported} recurring tasks.',
        ImportStatus.invalidFormat => 'The backup file format is invalid.',
        ImportStatus.noData => 'The backup file has no data.',
        ImportStatus.unavailable =>
          'Choosing a backup file is unavailable here.',
        ImportStatus.cancelled => '',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بازیابی انجام نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Import Backup / بازیابی',
            onPressed: _importing || _exporting ? null : _openBackup,
            icon: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_outlined, color: AppTheme.cyan),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'پشتیبان‌گیری / Export Data',
            onPressed: _exporting || _importing ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.backup_outlined, color: AppTheme.cyan),
          ),
        ],
      );
}
