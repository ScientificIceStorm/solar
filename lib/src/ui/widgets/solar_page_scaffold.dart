import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/solar_app_scope.dart';
import '../pages/sign_in_screen.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
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
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(SignInScreen.routeName, (route) => false);
          },
        ),
        body: SolarScreenBackground(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Builder(
                    builder: (context) {
                      return InkWell(
                        key: const ValueKey<String>('page-menu-button'),
                        onTap: () => Scaffold.of(context).openDrawer(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 18,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const SolarMenuGlyph(color: Color(0xFF16182C)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else
                    const SizedBox(width: 52),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 114),
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
