import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../ui/pages/search_screen.dart';
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
  static const MethodChannel _iosCompanionChannel = MethodChannel(
    'solar/ios_companion',
  );

  late Future<AppSessionController> _controllerFuture;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AppSessionController? _ownedController;
  bool _didAttachCompanionRouteHandler = false;
  bool _isHandlingCompanionRoute = false;
  String? _pendingCompanionRoute;

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
    if (_didAttachCompanionRouteHandler) {
      _iosCompanionChannel.setMethodCallHandler(null);
    }
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
    _attachCompanionRouteHandler(controller);
    if (_pendingCompanionRoute != null && !_isHandlingCompanionRoute) {
      final queuedRoute = _pendingCompanionRoute!;
      _pendingCompanionRoute = null;
      unawaited(
        _openCompanionRoute(controller: controller, route: queuedRoute),
      );
    }

    return SolarAppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'Solar v6',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
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
                SearchScreen.routeName => (_) {
                  final args = settings.arguments;
                  if (args is! SearchScreenArgs) {
                    return const SearchScreen();
                  }
                  return SearchScreen(args: args);
                },
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

              return _buildPageRoute<void>(
                settings: settings,
                builder: builder,
              );
            },
          );
        },
      ),
    );
  }

  void _attachCompanionRouteHandler(AppSessionController controller) {
    if (_didAttachCompanionRouteHandler) {
      return;
    }

    _didAttachCompanionRouteHandler = true;
    _iosCompanionChannel.setMethodCallHandler((call) async {
      if (call.method != 'openCompanionRoute') {
        return;
      }
      final route = _companionRouteFromArguments(call.arguments);
      if (route == null) {
        return;
      }
      await _openCompanionRoute(controller: controller, route: route);
    });

    unawaited(_consumePendingCompanionRoute(controller));
  }

  Future<void> _consumePendingCompanionRoute(
    AppSessionController controller,
  ) async {
    try {
      final route = await _iosCompanionChannel.invokeMethod<String>(
        'consumePendingCompanionRoute',
      );
      if (route == null || route.trim().isEmpty) {
        return;
      }
      await _openCompanionRoute(controller: controller, route: route);
    } on MissingPluginException {
      // Companion deep links are iOS-only.
    } on PlatformException {
      // Ignore route delivery issues to keep startup resilient.
    }
  }

  String? _companionRouteFromArguments(Object? arguments) {
    if (arguments is String) {
      return arguments;
    }
    if (arguments is Map) {
      final raw = arguments['route'] ?? arguments['action'];
      if (raw is String) {
        return raw;
      }
    }
    return null;
  }

  Future<void> _openCompanionRoute({
    required AppSessionController controller,
    required String route,
  }) async {
    if (_isHandlingCompanionRoute) {
      return;
    }

    _isHandlingCompanionRoute = true;
    try {
      await controller.refreshTeamStats();
      final snapshot = await controller.fetchNotificationCenterSnapshot();
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        _pendingCompanionRoute = route;
        return;
      }

      final normalizedRoute = route.trim().toLowerCase();
      MatchSummary? targetMatch;
      EventSummary? targetEvent;

      if (normalizedRoute.contains('recent')) {
        final recent = snapshot.recentResults.isEmpty
            ? null
            : snapshot.recentResults.first;
        targetMatch = recent?.match;
        targetEvent = recent?.event;
      } else {
        targetMatch = snapshot.upcomingMatch;
        targetEvent = snapshot.upcomingEvent;
      }

      targetMatch ??= snapshot.recentResults.isEmpty
          ? null
          : snapshot.recentResults.first.match;
      targetEvent ??= snapshot.recentResults.isEmpty
          ? null
          : snapshot.recentResults.first.event;

      if (targetMatch == null) {
        await navigator.pushNamed(HomeScreen.routeName);
        return;
      }

      await navigator.pushNamed(
        MatchDetailsScreen.routeName,
        arguments: MatchDetailsScreenArgs(
          match: targetMatch,
          event: targetEvent,
          highlightTeamNumber: controller.currentAccount?.team.number,
        ),
      );
    } finally {
      _isHandlingCompanionRoute = false;
    }
  }
}

const Set<String> _tabRouteNames = <String>{
  HomeScreen.routeName,
  RankingsScreen.routeName,
  SearchScreen.routeName,
  CalendarScreen.routeName,
  ProfileScreen.routeName,
};

PageRoute<T> _buildPageRoute<T>({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  final routeName = settings.name;
  if (routeName != null && _tabRouteNames.contains(routeName)) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return CupertinoPageRoute<T>(builder: builder, settings: settings);
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return MaterialPageRoute<T>(builder: builder, settings: settings);
  }
}

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color surface,
  required Color textPrimary,
  required Color accent,
  required bool dark,
}) {
  final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
    bodyColor: textPrimary,
    displayColor: textPrimary,
  );
  final displayFamily = GoogleFonts.outfit().fontFamily;
  final titleWeight = dark ? FontWeight.w700 : FontWeight.w800;

  return ThemeData(
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface,
    canvasColor: dark ? const Color(0xFF060810) : const Color(0xFF050607),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    textTheme: baseTextTheme.copyWith(
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: displayFamily,
        fontSize: 34,
        fontWeight: titleWeight,
        height: 1.15,
        letterSpacing: -1.2,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontFamily: displayFamily,
        fontSize: 28,
        fontWeight: titleWeight,
        letterSpacing: -0.9,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: displayFamily,
        fontSize: 30,
        fontWeight: titleWeight,
        letterSpacing: -0.9,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontFamily: displayFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
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
