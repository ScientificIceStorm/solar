import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../models/app_account.dart';
import '../models/onboarding_slide.dart';
import '../widgets/solar_screen_background.dart';
import '../widgets/solar_text_field.dart';
import 'home_screen.dart';

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
      imageAsset: 'assets/images/onboarding_1.png',
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
      imageAsset: 'assets/images/onboarding_2.png',
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
      imageAsset: 'assets/images/onboarding_3.png',
    ),
  ];

  final PageController _pageController = PageController();
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _followedTeamsController =
      TextEditingController();
  int _currentIndex = 0;
  AppCompetitionPreference _competition = AppCompetitionPreference.vexV5;
  AppFollowMode _followMode = AppFollowMode.single;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _competition =
        widget.initialCompetitionPreference ?? AppCompetitionPreference.vexV5;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _teamController.dispose();
    _followedTeamsController.dispose();
    super.dispose();
  }

  List<String> _parseTeamNumbers(String raw) {
    return raw
        .split(RegExp(r'[,\s]+'))
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
  }

  Future<void> _finishFlow() async {
    if (widget.previewOnly) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isFinishing = true;
    });

    try {
      final controller = SolarAppScope.of(context);
      final primaryTeam = _teamController.text.trim().toUpperCase();
      await controller.createLocalAccount(
        teamNumber: primaryTeam,
        competitionPreference: _competition,
      );
      await controller.setFollowMode(_followMode);
      if (_followMode == AppFollowMode.multi) {
        final followedTeams = _parseTeamNumbers(_followedTeamsController.text)
          ..remove(primaryTeam);
        await controller.setFavoriteTeamNumbers(followedTeams);
      }
      await controller.completeOnboarding(competitionPreference: _competition);
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(HomeScreen.routeName, (route) => false);
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
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

  Future<void> _handleSkip() async {
    if (widget.previewOnly || _currentIndex == _slides.length - 1) {
      await _finishFlow();
      return;
    }

    await _pageController.animateToPage(
      _slides.length - 1,
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
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 22),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        child: Image.asset(slide.imageAsset, fit: BoxFit.cover),
                      ),
                    ),
                  );
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
                    Column(
                      children: slide.highlights
                          .take(6)
                          .map(
                            (highlight) => Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Colors.white.withValues(alpha: 0.74),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    highlight,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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
                    const SizedBox(height: 14),
                    _OnboardingPickerSection<AppFollowMode>(
                      title: 'Follow Mode',
                      value: _followMode,
                      options: AppFollowMode.values,
                      labelBuilder: (value) => switch (value) {
                        AppFollowMode.single => 'Single team focus',
                        AppFollowMode.multi => 'Multi-team follow',
                      },
                      onSelected: (value) {
                        setState(() {
                          _followMode = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    SolarTextField(
                      controller: _teamController,
                      hintText: 'Primary team number',
                      icon: Icons.tag_rounded,
                      textInputAction: TextInputAction.done,
                    ),
                    if (_followMode == AppFollowMode.multi) ...<Widget>[
                      const SizedBox(height: 12),
                      SolarTextField(
                        controller: _followedTeamsController,
                        hintText: 'Follow team numbers (comma separated)',
                        icon: Icons.group_outlined,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _followMode == AppFollowMode.multi
                          ? 'Primary team is optional. Add any extra teams you want to follow now.'
                          : 'Team number is optional. You can add more teams later in Settings.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: _isFinishing ? null : _handleSkip,
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
                      TextButton.icon(
                        onPressed: _isFinishing ? null : _nextPage,
                        icon: _isFinishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const SizedBox.shrink(),
                        label: Text(
                          _currentIndex == _slides.length - 1 ? 'Done' : 'Next',
                          style: const TextStyle(color: Colors.white),
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
          runSpacing: 8,
          children: options.map((option) {
            final selected = option == value;
            return InkWell(
              onTap: () => onSelected(option),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  labelBuilder(option),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}
