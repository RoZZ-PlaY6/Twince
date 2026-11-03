import 'package:flutter/material.dart';

import '../services/week_cycle_service.dart';
import '../theme/app_theme.dart';

/// Asks for the current week. A required choice cannot be dismissed.
Future<void> showWeekCycleDialog(
  BuildContext context,
  WeekCycleService cycle, {
  bool requiredChoice = false,
}) async {
  final selected = await showDialog<bool>(
    context: context,
    barrierDismissible: !requiredChoice,
    builder: (dialogContext) => PopScope(
      canPop: !requiredChoice,
      child: AlertDialog(
        title: const Text(
          'هفته جاری را انتخاب کنید',
          style: TextStyle(fontFamily: AppTheme.persianFontFamily),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'انتخاب جدید از شنبهٔ همین هفته محاسبه می‌شود.',
              style: TextStyle(fontFamily: AppTheme.persianFontFamily),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, WeekParity.even.isOdd),
                child: Text(WeekParity.even.persianChoiceLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, WeekParity.odd.isOdd),
                child: Text(WeekParity.odd.persianChoiceLabel),
              ),
            ),
            if (!requiredChoice)
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, cycle.isOddOn(DateTime.now())),
                child: const Text(
                  'بازنشانی',
                  style: TextStyle(fontFamily: AppTheme.persianFontFamily),
                ),
              ),
          ],
        ),
        actions: [
          if (!requiredChoice)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'انصراف',
                style: TextStyle(fontFamily: AppTheme.persianFontFamily),
              ),
            ),
        ],
      ),
    ),
  );
  if (selected == null) return;
  await cycle.chooseCurrentWeek(selected);
}
