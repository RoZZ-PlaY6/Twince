import 'package:flutter/material.dart';

import '../services/week_cycle_service.dart';
import '../theme/app_theme.dart';

/// Asks for the current week. A required choice cannot be dismissed.
Future<void> showWeekCycleDialog(
  BuildContext context,
  WeekCycleService cycle, {
  bool requiredChoice = false,
}) async {
  final currentOdd = cycle.isConfigured ? cycle.isOddOn(DateTime.now()) : null;
  final selected = await showDialog<bool>(
    context: context,
    barrierDismissible: !requiredChoice,
    builder: (dialogContext) {
      final media = MediaQuery.of(dialogContext);
      return PopScope(
        canPop: !requiredChoice,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              EdgeInsets.fromLTRB(20, 24, 20, 24 + media.viewPadding.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: media.size.height - media.padding.vertical - 48,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1738),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF22D3EE)),
                boxShadow: const [
                  BoxShadow(color: Color(0x402F5BFF), blurRadius: 22),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'هفته جاری را انتخاب کنید',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontFamily: AppTheme.persianFontFamily,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'انتخاب جدید از شنبهٔ همین هفته محاسبه می‌شود.',
                        style: TextStyle(
                          color: Color(0xFF93A4BC),
                          height: 1.4,
                          fontFamily: AppTheme.persianFontFamily,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WeekChoiceButton(
                        label: WeekParity.even.persianChoiceLabel,
                        selected: currentOdd == WeekParity.even.isOdd,
                        onPressed: () =>
                            Navigator.pop(dialogContext, WeekParity.even.isOdd),
                      ),
                      const SizedBox(height: 12),
                      _WeekChoiceButton(
                        label: WeekParity.odd.persianChoiceLabel,
                        selected: currentOdd == WeekParity.odd.isOdd,
                        onPressed: () =>
                            Navigator.pop(dialogContext, WeekParity.odd.isOdd),
                      ),
                      if (!requiredChoice)
                        TextButton(
                          onPressed: () => Navigator.pop(
                              dialogContext, cycle.isOddOn(DateTime.now())),
                          child: const Text(
                            'بازنشانی',
                            style: TextStyle(
                              color: Color(0xFF93A4BC),
                              fontFamily: AppTheme.persianFontFamily,
                            ),
                          ),
                        ),
                      if (!requiredChoice)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFC4B5FD),
                            ),
                            child: const Text(
                              'انصراف',
                              style: TextStyle(
                                fontFamily: AppTheme.persianFontFamily,
                              ),
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
      );
    },
  );
  if (selected == null) return;
  await cycle.chooseCurrentWeek(selected);
}

class _WeekChoiceButton extends StatelessWidget {
  const _WeekChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF7C3AED)],
              )
            : null,
        color: selected ? null : const Color(0xFF121A2C),
        border: Border.all(
          color: selected ? Colors.transparent : const Color(0xFF4C8DFF),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.persianFontFamily,
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
