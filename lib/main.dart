import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/reminder_scheduler_service.dart';
import 'services/storage_service.dart';
import 'services/time_watcher_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    NotificationService? notifications;
    if (!kIsWeb) {
      notifications = NotificationService.instance;
      await notifications.initialize();
    }
    final storage = await StorageService.initialize(notifications);
    await storage.reconcile();

    // Initialize and start the foreground reminder scheduler
    final reminderScheduler = ReminderSchedulerService(
      storage: storage,
      notifications: notifications ?? NotificationService.instance,
    )..start();

    runApp(TwinceApp(
      storage: storage,
      reminderScheduler: reminderScheduler,
    ));
  } catch (error) {
    // A persistent storage failure should show a recoverable screen, not a
    // blank browser tab or an uncaught error before the first frame.
    runApp(_StartupFailureApp(error: error));
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Twince',
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text('Twince could not start.'),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      );
}

class TwinceApp extends StatefulWidget {
  const TwinceApp({
    super.key,
    required this.storage,
    required this.reminderScheduler,
  });
  final StorageService storage;
  final ReminderSchedulerService reminderScheduler;

  @override
  State<TwinceApp> createState() => _TwinceAppState();
}

class _TwinceAppState extends State<TwinceApp> {
  late final TimeWatcherService _watcher;
  late final ReminderSchedulerService _reminderScheduler;

  @override
  void initState() {
    super.initState();
    _watcher = TimeWatcherService(widget.storage)..start();
    _reminderScheduler = widget.reminderScheduler;
  }

  @override
  void dispose() {
    _watcher.dispose();
    _reminderScheduler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: widget.storage,
        child: MaterialApp(
          title: 'Twince',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const HomeScreen(),
        ),
      );
}
