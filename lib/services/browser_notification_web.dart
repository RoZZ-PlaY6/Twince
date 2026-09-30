import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Called directly from a button press so the permission prompt has a gesture.
Future<bool> showBrowserNotification(String title, String body) async {
  var permission = web.Notification.permission;
  if (permission == 'default') {
    permission = (await web.Notification.requestPermission().toDart).toDart;
  }
  if (permission != 'granted') return false;
  web.Notification(title, web.NotificationOptions(body: body));
  return true;
}
