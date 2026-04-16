import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/robot_events_models.dart';
import '../ui/pages/event_awards_screen.dart';
import '../ui/pages/event_division_screen.dart';
import '../ui/pages/calendar_screen.dart';
import '../ui/pages/event_details_screen.dart';
import '../ui/pages/event_schedule_screen.dart';
import '../ui/pages/event_skills_screen.dart';
import '../ui/pages/home_screen.dart';
import '../ui/pages/event_team_screen.dart';
import '../ui/pages/match_details_screen.dart';
import '../ui/pages/onboarding_screen.dart';
import '../ui/pages/profile_screen.dart';
import '../ui/pages/rankings_screen.dart';
import '../ui/pages/reset_password_screen.dart';
import '../ui/pages/sign_in_screen.dart';
import '../ui/pages/sign_up_screen.dart';
import '../ui/pages/splash_screen.dart';
import '../ui/pages/settings_screen.dart';
import '../ui/pages/verification_screen.dart';
import '../ui/pages/team_profile_screen.dart';
import 'app_session_controller.dart';
import 'solar_app_scope.dart';

class SolarApp extends StatefulWidget {
  const SolarApp({super.key, this.controller});

  final AppSessionController? controller;

  @override
  State<SolarApp> createState() => _SolarAppState();
}

class _SolarAppState extends State<SolarApp> {
  late Future<AppSessionController> _controllerFuture;
  AppSessionController? _ownedController;

  @override
  void initState() {
    super.initState();
    _controllerFuture = _loadController();
  }

  Future<AppSessionController> _loadController() async {
    if (widget.controller != null) {
      return widget.controller!;
    }

    final controller = await AppSessionController.bootstrap();
    _ownedController = controller;
    return controller;
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFF7F5F8);
    const primary = Color(0xFF0D6B81);
    const textPrimary = Color(0xFF16182C);
    const accent = Color(0xFF7C8CFF);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
      primary: primary,
    );

    if (widget.controller != null) {
      return _buildApp(
        controller: widget.controller!,
        colorScheme: colorScheme,
        surface: surface,
        textPrimary: textPrimary,
        accent: accent,
      );
    }

    return FutureBuilder<AppSessionController>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _BootstrapErrorScreen(
              onRetry: () {
                setState(() {
                  _ownedController?.dispose();
                  _ownedController = null;
                  _controllerFuture = _loadController();
                });
              },
            ),
          );
        }

        if (!snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const SplashScreen(isBootstrapping: true),
          );
        }

        return _buildApp(
          controller: snapshot.data!,
          colorScheme: colorScheme,
          surface: surface,
          textPrimary: textPrimary,
          accent: accent,
        );
      },
    );
  }

  Widget _buildApp({
    required AppSessionController controller,
    required ColorScheme colorScheme,
    required Color surface,
    required Color textPrimary,
    required Color accent,
  }) {
    return SolarAppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'Solar v6',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: _buildTheme(
              colorScheme: colorScheme,
              surface: surface,
              textPrimary: textPrimary,
              accent: accent,
              dark: false,
            ),
            darkTheme: _buildTheme(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2C97BF),
                brightness: Brightness.dark,
                surface: const Color(0xFF0F1220),
                primary: const Color(0xFF2C97BF),
              ),
              surface: const Color(0xFF0F1220),
              textPrimary: Colors.white,
              accent: const Color(0xFF8DA5FF),
              dark: true,
            ),
            home: const SplashScreen(),
            onGenerateRoute: (settings) {
              final builder = switch (settings.name) {
                SplashScreen.routeName => (_) => const SplashScreen(),
                OnboardingScreen.routeName => (_) => const OnboardingScreen(),
                SignInScreen.routeName => (_) => const SignInScreen(),
                SignUpScreen.routeName => (_) => const SignUpScreen(),
                VerificationScreen.routeName => (_) {
                  final details = settings.arguments is VerificationDetails
                      ? settings.arguments! as VerificationDetails
                      : VerificationDetails.signUp(email: '');
                  return VerificationScreen(details: details);
                },
                ResetPasswordScreen.routeName =>
                  (_) => const ResetPasswordScreen(),
                HomeScreen.routeName => (_) => const HomeScreen(),
                CalendarScreen.routeName => (_) => const CalendarScreen(),
                ProfileScreen.routeName => (_) => const ProfileScreen(),
                TeamProfileScreen.routeName => (_) {
                  final team = settings.arguments;
                  if (team is! TeamSummary) {
                    return const HomeScreen();
                  }
                  return TeamProfileScreen(team: team);
                },
                RankingsScreen.routeName => (_) => const RankingsScreen(),
                SettingsScreen.routeName => (_) => const SettingsScreen(),
                EventDetailsScreen.routeName => (_) {
                  final event = settings.arguments;
                  if (event is! EventSummary) {
                    return const HomeScreen();
                  }
                  return EventDetailsScreen(event: event);
                },
                EventScheduleScreen.routeName => (_) {
                  final event = settings.arguments;
                  if (event is! EventSummary) {
                    return const HomeScreen();
                  }
                  return EventScheduleScreen(event: event);
                },
                EventTeamScreen.routeName => (_) {
                  final args = settings.arguments;
                  if (args is! EventTeamScreenArgs) {
                    return const HomeScreen();
                  }
                  return EventTeamScreen(args: args);
                },
                MatchDetailsScreen.routeName => (_) {
                  final args = settings.arguments;
                  if (args is! MatchDetailsScreenArgs) {
                    return const HomeScreen();
                  }
                  return MatchDetailsScreen(args: args);
                },
                EventSkillsScreen.routeName => (_) {
                  final event = settings.arguments;
                  if (event is! EventSummary) {
                    return const HomeScreen();
                  }
                  return EventSkillsScreen(event: event);
                },
                EventAwardsScreen.routeName => (_) {
                  final event = settings.arguments;
                  if (event is! EventSummary) {
                    return const HomeScreen();
                  }
                  return EventAwardsScreen(event: event);
                },
                EventDivisionScreen.routeName => (_) {
                  final args = settings.arguments;
                  if (args is! EventDivisionScreenArgs) {
                    return const HomeScreen();
                  }
                  return EventDivisionScreen(args: args);
                },
                _ => null,
              };

              if (builder == null) {
                return null;
              }

              return MaterialPageRoute<void>(
                builder: builder,
                settings: settings,
              );
            },
          );
        },
      ),
    );
  }
}

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color surface,
  required Color textPrimary,
  required Color accent,
  required bool dark,
}) {
  final baseTextTheme = GoogleFonts.montserratTextTheme().apply(
    bodyColor: textPrimary,
    displayColor: textPrimary,
  );

  return ThemeData(
    fontFamily: GoogleFonts.montserrat().fontFamily,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
        TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
        TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
        TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
        TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
        TargetPlatform.fuchsia: _NoAnimationPageTransitionsBuilder(),
      },
    ),
    textTheme: baseTextTheme.copyWith(
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.88),
      hintStyle: TextStyle(
        color: textPrimary.withValues(alpha: 0.45),
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: textPrimary.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: textPrimary.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.3),
      ),
    ),
  );
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Color(0xFF16182C),
              ),
              const SizedBox(height: 16),
              const Text(
                'Solar could not finish loading.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16182C),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Try again and the app will attempt a safer startup path instead of hanging on the splash screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF5E647A),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
