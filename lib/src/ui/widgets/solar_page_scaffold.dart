import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/solar_app_scope.dart';
import '../theme/solar_chrome_palette.dart';
import '../pages/onboarding_screen.dart';
import 'solar_navigation.dart';
import 'solar_screen_background.dart';

class SolarPageScaffold extends StatelessWidget {
  const SolarPageScaffold({
    required this.title,
    required this.currentDestination,
    required this.body,
    super.key,
    this.trailing,
  });

  final String title;
  final SolarNavDestination currentDestination;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final account = controller.currentAccount;
    if (account == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final chromeColor = solarChromeAccentColor(
      controller.chromeAccentPreference,
      customAccentValue: controller.customChromeAccentValue,
    );
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        drawer: SolarAppDrawer(
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
                color: chromeColor,
                child: Row(
                  children: <Widget>[
                    Builder(
                      builder: (context) {
                        return InkWell(
                          key: const ValueKey<String>('page-menu-button'),
                          onTap: () => Scaffold.of(context).openDrawer(),
                          borderRadius: BorderRadius.circular(18),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: SolarMenuGlyph(color: Colors.white),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (trailing != null)
                      trailing!
                    else
                      const SizedBox(width: 42),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
                  child: body,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SolarBottomNavBar(
          current: currentDestination,
          onSelected: (destination) {
            navigateToSolarDestination(context, destination);
          },
        ),
      ),
    );
  }
}
