import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TestNotificationDialog extends StatefulWidget {
  const TestNotificationDialog({super.key, required this.onSend});

  final Future<bool> Function(String title, String body) onSend;

  @override
  State<TestNotificationDialog> createState() => _TestNotificationDialogState();
}

class _TestNotificationDialogState extends State<TestNotificationDialog> {
  final _title = TextEditingController(text: 'Twince Alert');
  final _body = TextEditingController(text: 'This is a test notification!');
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title and message.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final sent = await widget.onSend(title, body);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
          content: Text(
        sent
            ? 'Test notification sent.'
            : 'Notification permission denied or unavailable.',
      )));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not show notification: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.cyan),
        ),
        title: const Text('Test notification',
            style: TextStyle(color: AppTheme.cyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(
                controller: _body,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(_sending ? 'Sending…' : 'Send test')),
        ],
      );
}
