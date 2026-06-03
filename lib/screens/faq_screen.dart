import 'package:flutter/material.dart';
import 'package:soilair/l10n/app_strings.dart';
import 'package:soilair/main.dart';
import 'package:soilair/theme/app_light_theme.dart';
import 'package:soilair/widgets/base_scaffold.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(appLanguage.value);
    final subtitleColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.65);

    Widget item(String q, String a) => ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: const Icon(Icons.help_outline,
              color: AppLightTheme.botonPrincipal, size: 20),
          title: Text(q,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(a,
                  style: TextStyle(fontSize: 13, height: 1.5, color: subtitleColor)),
            ),
          ],
        );

    return BaseScaffold(
      title: s.faqSeccion,
      body: ListView(
        children: [
          const SizedBox(height: 8),
          item(s.faq1Q, s.faq1A),
          item(s.faq2Q, s.faq2A),
          item(s.faq3Q, s.faq3A),
          item(s.faq4Q, s.faq4A),
          item(s.faq5Q, s.faq5A),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
