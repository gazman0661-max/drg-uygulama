import 'package:flutter/material.dart' hide Text;
import '../l10n/app_text.dart';

import '../theme/app_theme.dart';

/// Uygulama temasına uygun ortak popup: zümrüt başlık şeridi, altın çizgi,
/// hat motifi, sedef zemin ve pirinç/altın düğmeler.
/// Dışa dokunarak / geri tuşuyla kapanmaz; yalnızca düğmelerle kapanır.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.primaryLabel,
    this.onPrimary,
    this.primaryBusy = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final Widget child;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryBusy;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.gold, width: 1.2),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: AppColors.deep,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 42,
                        width: 42,
                        child: Image.asset('assets/images/hat.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ivory,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 2, color: AppColors.gold),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        height: 1.5,
                        color: AppColors.ink,
                      ),
                      child: child,
                    ),
                  ),
                ),
                if (primaryLabel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    child: Row(
                      children: [
                        if (secondaryLabel != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onSecondary,
                              child: Text(secondaryLabel!),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onPrimary,
                            child: primaryBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(primaryLabel!),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
