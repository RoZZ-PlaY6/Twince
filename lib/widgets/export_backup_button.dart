import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class ExportBackupButton extends StatefulWidget {
  const ExportBackupButton({super.key});

  @override
  State<ExportBackupButton> createState() => _ExportBackupButtonState();
}

class _ExportBackupButtonState extends State<ExportBackupButton> {
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final result = await ExportService.instance
          .exportAndShare(context.read<StorageService>());
      if (!mounted) return;
      final message = switch (result.status) {
        ExportStatus.shared => 'پشتیبان‌گیری با موفقیت آماده شد.',
        ExportStatus.noData => 'داده‌ای برای پشتیبان‌گیری وجود ندارد.',
        ExportStatus.unavailable =>
          'اشتراک‌گذاری فایل در این پلتفرم در دسترس نیست.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پشتیبان‌گیری انجام نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'پشتیبان‌گیری / Export Data',
        onPressed: _exporting ? null : _export,
        icon: _exporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.backup_outlined, color: AppTheme.cyan),
      );
}
