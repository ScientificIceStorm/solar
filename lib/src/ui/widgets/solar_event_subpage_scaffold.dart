import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/solar_app_scope.dart';
import '../theme/solar_chrome_palette.dart';
import '../pages/onboarding_screen.dart';
import 'solar_navigation.dart';
import 'solar_scaffold_metrics.dart';
import 'solar_screen_background.dart';

class SolarEventSubpageScaffold extends StatelessWidget {
  const SolarEventSubpageScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
    super.key,
    this.headerBottom,
    this.bodyPadding = solarPageBodyPadding,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget? headerBottom;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final chromeColor = solarChromeAccentColor(
      controller.chromeAccentPreference,
      customAccentValue: controller.customChromeAccentValue,
    );
    final topInset = MediaQuery.paddingOf(context).top;
    final account = controller.currentAccount;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        drawer: account == null
            ? null
            : SolarAppDrawer(
                account: account,
                onActionSelected: (action) {
                  Navigator.of(context).pop();
                  openSolarDrawerAction(context, action);
                },
                onSignOut: () async {
                  await controller.signOut();
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    OnboardingScreen.routeName,
                    (route) => false,
                  );
                },
              ),
        body: SolarScreenBackground(
          padding: EdgeInsets.zero,
          respectSafeArea: false,
          child: Column(
            children: <Widget>[
              Container(
                padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 12),
                decoration: BoxDecoration(
                  color: chromeColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(solarHeaderCornerRadius),
                    bottomRight: Radius.circular(solarHeaderCornerRadius),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          borderRadius: BorderRadius.circular(18),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD9DDF5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (headerBottom != null) ...<Widget>[
                      const SizedBox(height: 18),
                      headerBottom!,
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(padding: bodyPadding, child: body),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SolarBottomNavBar(
          current: null,
          onSelected: (destination) {
            navigateToSolarDestination(context, destination);
          },
        ),
      ),
    );
  }
}
