import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../l10n/app_text.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/links.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/open_link.dart';
import 'app_dialog.dart';

/// Metinler değişirse sürümü artırın; kullanıcıdan yeniden onay istenir.
const String _consentKey = 'consent_accepted_v1';

/// Gizlilik politikası ve kullanım şartları daha önce kabul edildi mi?
Future<bool> isConsentAccepted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  } catch (_) {
    return false;
  }
}

/// Kabul edilmediyse onay penceresini gösterir ve kullanıcı kabul edene kadar
/// bekler. "Vazgeç" uygulamayı kapatır.
Future<void> showConsentIfNeeded(BuildContext context) async {
  if (await isConsentAccepted()) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ConsentDialog(),
  );
}

class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog();

  Future<void> _accept(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_consentKey, true);
    } catch (_) {}
    // Analytics yalnızca kabulden sonra başlar.
    unawaited(AnalyticsService.init());
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _decline() async {
    await SystemNavigator.pop();
  }

  Widget _link(BuildContext context, String label, String url) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        onPressed: () => openLink(context, url),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.ink,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Hoş Geldiniz',
      primaryLabel: 'Kabul Et',
      onPrimary: () => _accept(context),
      secondaryLabel: 'Vazgeç',
      onSecondary: _decline,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Uygulamayı kullanmaya devam etmek için aşağıdaki metinleri '
              'okuyup kabul etmeniz gerekir.'),
          const SizedBox(height: 12),
          _link(context, 'Gizlilik Politikası', privacyPolicyUrl),
          _link(context, 'Kullanım Şartları', termsOfUseUrl),
          const SizedBox(height: 12),
          const Text(
              '“Kabul Et”e dokunarak her ikisini de okuduğunuzu ve kabul '
              'ettiğinizi onaylarsınız.',
              style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
