import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/solar_app_scope.dart';
import '../pages/onboarding_screen.dart';
import 'solar_navigation.dart';
import 'solar_screen_background.dart';

class SolarEventSubpageScaffold extends StatelessWidget {
  const SolarEventSubpageScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final account = controller.currentAccount;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
          topFillColor: Colors.black,
          topFillHeight: MediaQuery.paddingOf(context).top + 26,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF16182C),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF24243A),
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8E92A7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(child: body),
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
