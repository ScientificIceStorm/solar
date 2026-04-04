import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../models/onboarding_slide.dart';
import '../widgets/solar_screen_background.dart';
import 'sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const routeName = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slides = <OnboardingSlide>[
    OnboardingSlide(
      title: 'View your live team stats',
      description:
          'Blank onboarding screen one for now. We can wire the real copy and illustrations after the flow is approved.',
    ),
    OnboardingSlide(
      title: 'We have modern events calendar features',
      description:
          'Blank onboarding screen two for now. This gives us the structure and transitions without locking the final content yet.',
    ),
    OnboardingSlide(
      title: 'Look up nearby events and activities',
      description:
          'Blank onboarding screen three for now. Once you are happy with the flow, we can swap in polished content and real assets.',
    ),
  ];

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToSignIn() async {
    await SolarAppScope.of(context).completeOnboarding();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
    );
  }

  Future<void> _nextPage() async {
    if (_currentIndex == _slides.length - 1) {
      await _goToSignIn();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentIndex];

    return Scaffold(
      body: SolarScreenBackground(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return const SizedBox.expand();
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x21000000),
                    blurRadius: 22,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    slide.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: _goToSignIn,
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: List<Widget>.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: index == _currentIndex ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: index == _currentIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _nextPage,
                        child: const Text(
                          'Next',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
