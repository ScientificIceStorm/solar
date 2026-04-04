import 'package:flutter/material.dart';

import 'solar_brand_mark.dart';
import 'solar_screen_background.dart';

class SolarAuthShell extends StatelessWidget {
  const SolarAuthShell({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.showBrand = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SolarScreenBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 8),
                      if (showBackButton)
                        IconButton(
                          onPressed:
                              onBack ?? () => Navigator.of(context).maybePop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        )
                      else
                        const SizedBox(height: 40),
                      const SizedBox(height: 14),
                      if (showBrand) ...<Widget>[
                        const Center(
                          child: SolarBrandMark(iconSize: 72, wordmarkSize: 30),
                        ),
                        const SizedBox(height: 36),
                      ],
                      Text(title, style: theme.textTheme.titleLarge),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5E647A),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
