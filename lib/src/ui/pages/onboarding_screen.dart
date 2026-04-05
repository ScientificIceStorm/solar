import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../models/app_account.dart';
import '../models/onboarding_slide.dart';
import '../widgets/solar_screen_background.dart';
import 'sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.previewOnly = false,
    this.initialCompetitionPreference,
  });

  static const routeName = '/onboarding';

  final bool previewOnly;
  final AppCompetitionPreference? initialCompetitionPreference;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slides = <OnboardingSlide>[
    OnboardingSlide(
      title: 'Everything Solar has right now',
      description:
          'Quickview, Solarize rankings, calendars, division tabs, team pages, match predictions, event photos, widgets, live activities, and notifications are all already in this build.',
      highlights: <String>[
        'Quickview',
        'Solarize',
        'Calendar',
        'Division tabs',
        'Match details',
        'Team pages',
        'Event photos',
        'Widgets',
        'Live activities',
      ],
    ),
    OnboardingSlide(
      title: 'Move through comp day faster',
      description:
          'Jump from your next match into the right division, event, ranking, or team page without bouncing around different menus.',
      highlights: <String>[
        'Next match',
        'Division standings',
        'Schedule view',
        'Skills view',
        'Solarize team list',
      ],
    ),
    OnboardingSlide(
      title: 'Set Solar up your way',
      description:
          'Tell Solar which competition family you are in so the app defaults to the right teams, events, and rankings before you finish.',
    ),
  ];

  final PageController _pageController = PageController();
  int _currentIndex = 0;
  AppCompetitionPreference _competition = AppCompetitionPreference.vexV5;

  @override
  void initState() {
    super.initState();
    _competition =
        widget.initialCompetitionPreference ?? AppCompetitionPreference.vexV5;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishFlow() async {
    await SolarAppScope.of(
      context,
    ).completeOnboarding(competitionPreference: _competition);
    if (!mounted) {
      return;
    }
    if (widget.previewOnly) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
    );
  }

  Future<void> _nextPage() async {
    if (_currentIndex == _slides.length - 1) {
      await _finishFlow();
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
                  if (slide.highlights.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: slide.highlights
                          .map(
                            (highlight) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                highlight,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (_currentIndex == _slides.length - 1) ...<Widget>[
                    const SizedBox(height: 22),
                    _OnboardingPickerSection<AppCompetitionPreference>(
                      title: 'Competition',
                      value: _competition,
                      options: AppCompetitionPreference.values,
                      labelBuilder: (value) => switch (value) {
                        AppCompetitionPreference.vexV5 => 'VEX V5',
                        AppCompetitionPreference.vexIQ => 'VEX IQ',
                        AppCompetitionPreference.vexU => 'VEX U',
                        AppCompetitionPreference.vexAI => 'VEX AI',
                      },
                      onSelected: (value) {
                        setState(() {
                          _competition = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: _finishFlow,
                        child: Text(
                          widget.previewOnly ? 'Close' : 'Skip',
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
                        child: Text(
                          _currentIndex == _slides.length - 1 ? 'Done' : 'Next',
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

class _OnboardingPickerSection<T> extends StatelessWidget {
  const _OnboardingPickerSection({
    required this.title,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String title;
  final T value;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options
              .map((option) {
                final selected = option == value;
                return InkWell(
                  onTap: () => onSelected(option),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      labelBuilder(option),
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}
