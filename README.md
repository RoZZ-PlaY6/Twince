# Twince

An offline Android task app with strict same-day time windows. Tasks live in Hive, and pending tasks become failed after their deadline when the app runs or resumes. Android local reminders are scheduled at the selected interval during the active window, with exact alarm and notification permissions requested on startup.

The Flutter entry point is `lib/main.dart`. Storage and alarms are coordinated in `lib/services/`, while the task adapter is hand-written in `lib/models/task.dart`.
