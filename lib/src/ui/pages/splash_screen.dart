import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../widgets/solar_brand_mark.dart';
import '../widgets/solar_screen_background.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.isBootstrapping = false});

  static const routeName = '/';

  final bool isBootstrapping;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isBootstrapping) {
      return;
    }

    _timer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) {
        return;
      }

      final controller = SolarAppScope.of(context);
      final nextScreen = controller.isSignedIn
          ? const HomeScreen()
          : controller.hasCompletedOnboarding
          ? const SignInScreen()
          : const OnboardingScreen();

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => nextScreen));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SolarScreenBackground(
        child: Center(child: SolarBrandMark(iconSize: 112, wordmarkSize: 46)),
      ),
    );
  }
}
