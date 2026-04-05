import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../core/solar_competition_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/app_account.dart';
import '../models/solar_match_prediction.dart';
import '../widgets/solar_team_link.dart';
import '../widgets/solar_page_scaffold.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_primary_button.dart';
import '../widgets/solar_text_field.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _useCurrentSeasonToken = '__use_current_season__';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  Future<List<SeasonSummary>>? _seasonsFuture;
  bool _didSeedProfile = false;
  bool _isSavingProfile = false;
  bool _isUpdatingPassword = false;
  int? _selectedSeasonId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeedProfile) {
      return;
    }

    final account = SolarAppScope.of(context).currentAccount;
    final controller = SolarAppScope.of(context);
    if (account != null) {
      _nameController.text = account.fullName;
      _teamController.text = account.team.number;
      _selectedSeasonId = controller.preferredSeasonId;
      _didSeedProfile = true;
    }

    _seasonsFuture ??= controller.fetchWorldSkillsSeasons(
      programFilter: solarPrimaryProgramFilter,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final controller = SolarAppScope.of(context);
    final currentAccount = controller.currentAccount;
    if (currentAccount == null) {
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      final normalizedName = _nameController.text.trim();
      final normalizedTeam = _teamController.text.trim().toUpperCase();
      final currentTeam = currentAccount.team.number.trim().toUpperCase();
      final currentSeasonId = controller.preferredSeasonId;
      final seasonChanged = _selectedSeasonId != currentSeasonId;
      final teamChanged = normalizedTeam != currentTeam;

      if (normalizedName != currentAccount.fullName.trim()) {
        await controller.updateProfile(fullName: normalizedName);
      }

      if (seasonChanged) {
        await controller.updatePreferredSeason(
          seasonId: _selectedSeasonId,
          refresh: !teamChanged,
        );
      }

      if (teamChanged) {
        await controller.updateTeam(teamNumber: normalizedTeam);
      }

      _teamController.text =
          controller.currentAccount?.team.number ?? _teamController.text;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
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
          _isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _pickSeason(List<SeasonSummary> seasons) async {
    if (seasons.isEmpty) {
      return;
    }

    final currentSeason = seasons.first;
    final selectedSeasonId = _selectedSeasonId;
    final pickedSeason = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8F8FD),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Season',
                  style: TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use the current season by default, or lock Solar to a past season.',
                  style: TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                _SeasonOptionTile(
                  title: 'Current season',
                  subtitle: currentSeason.name,
                  isSelected: selectedSeasonId == null,
                  onTap: () =>
                      Navigator.of(context).pop(_useCurrentSeasonToken),
                  trailing: const Text(
                    'Default',
                    style: TextStyle(
                      color: Color(0xFF5B61F6),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: seasons.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final season = seasons[index];
                      return _SeasonOptionTile(
                        title: season.name,
                        subtitle: season.programName,
                        isSelected: selectedSeasonId == season.id,
                        onTap: () => Navigator.of(context).pop(season.id),
                        trailing: index == 0
                            ? const Text(
                                'Current',
                                style: TextStyle(
                                  color: Color(0xFF5B61F6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || pickedSeason == null) {
      return;
    }

    final pickedSeasonId = pickedSeason == _useCurrentSeasonToken
        ? null
        : pickedSeason as int;

    if (pickedSeasonId == selectedSeasonId) {
      return;
    }

    setState(() {
      _selectedSeasonId = pickedSeasonId;
    });
  }

  Future<void> _updatePassword() async {
    final controller = SolarAppScope.of(context);
    setState(() {
      _isUpdatingPassword = true;
    });

    try {
      await controller.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
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
          _isUpdatingPassword = false;
        });
      }
    }
  }

  MatchSummary? _developerPreviewMatch(SolarQuickviewSnapshot snapshot) {
    return snapshot.nextQualifyingMatch ??
        (snapshot.futureMatches.isEmpty ? null : snapshot.futureMatches.first);
  }

  String _developerMatchTimeLabel(MatchSummary match) {
    final anchor = match.scheduled ?? match.started;
    if (anchor == null) {
      return 'Time pending';
    }
    final local = anchor.toLocal();
    final time = TimeOfDay.fromDateTime(local).format(context);
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$month/$day at $time';
  }

  Future<void> _previewReminder() async {
    final controller = SolarAppScope.of(context);
    final snapshot = await controller.fetchQuickviewSnapshot();
    if (!mounted) {
      return;
    }

    final match = snapshot == null ? null : _developerPreviewMatch(snapshot);
    if (snapshot == null || match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No upcoming match is available to preview yet.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reminder Preview'),
          content: Text(
            'Match ${match.name} in ${snapshot.event.name}\n'
            '${_developerMatchTimeLabel(match)}\n'
            '${match.field.trim().isEmpty ? 'Field pending' : match.field}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _previewSurface({
    required String title,
    required bool widgetStyle,
  }) async {
    final controller = SolarAppScope.of(context);
    final snapshot = await controller.fetchQuickviewSnapshot();
    if (!mounted) {
      return;
    }

    final match = snapshot == null ? null : _developerPreviewMatch(snapshot);
    if (snapshot == null || match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No upcoming match is available to preview yet.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F5F8),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widgetStyle
                      ? 'This is the in-app widget preview for the same next-match data that now syncs to the iPhone widget target.'
                      : 'This is the in-app live activity preview for the next published match.',
                  style: const TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                _DeveloperQuickviewPreview(
                  snapshot: snapshot,
                  match: match,
                  widgetStyle: widgetStyle,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openOnboardingPreview() async {
    final controller = SolarAppScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingScreen(
          previewOnly: true,
          initialCompetitionPreference: controller.competitionPreference,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);

    return SolarPageScaffold(
      title: 'Settings',
      currentDestination: SolarNavDestination.profile,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final account = controller.currentAccount;
          if (account == null) {
            return const SizedBox.shrink();
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 14),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SolarTextField(
                      controller: _nameController,
                      hintText: 'Full name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _ReadOnlyField(label: 'Email', value: account.email),
                    const SizedBox(height: 18),
                    SolarTextField(
                      controller: _teamController,
                      hintText: 'Team number',
                      icon: Icons.tag_rounded,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<List<SeasonSummary>>(
                      future: _seasonsFuture,
                      builder: (context, snapshot) {
                        final seasons =
                            snapshot.data ?? const <SeasonSummary>[];
                        final isLoading =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            seasons.isEmpty;
                        final currentSeason = seasons.isEmpty
                            ? null
                            : seasons.first;
                        SeasonSummary? selectedSeason;
                        for (final season in seasons) {
                          if (season.id == _selectedSeasonId) {
                            selectedSeason = season;
                            break;
                          }
                        }
                        final title = isLoading
                            ? 'Loading seasons...'
                            : selectedSeason?.name ??
                                  currentSeason?.name ??
                                  'Current season unavailable';
                        final subtitle = isLoading
                            ? 'Checking the V5RC Push Back season.'
                            : _selectedSeasonId == null
                            ? currentSeason == null
                                  ? 'Connect the API to load seasons.'
                                  : 'Current season default'
                            : selectedSeason?.programName ?? 'Tap to change';

                        return _SelectionField(
                          label: 'Season',
                          value: title,
                          subtitle: subtitle,
                          enabled: seasons.isNotEmpty && !isLoading,
                          onTap: seasons.isEmpty
                              ? null
                              : () => _pickSeason(seasons),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _SettingsChoiceRow<AppCompetitionPreference>(
                      label: 'Competition',
                      value: controller.competitionPreference,
                      options: AppCompetitionPreference.values,
                      labelBuilder: (value) => switch (value) {
                        AppCompetitionPreference.vexV5 => 'VEX V5',
                        AppCompetitionPreference.vexIQ => 'VEX IQ',
                        AppCompetitionPreference.vexU => 'VEX U',
                        AppCompetitionPreference.vexAI => 'VEX AI',
                      },
                      onSelected: controller.setCompetitionPreference,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          openSolarTeamProfileForSummary(context, account.team);
                        },
                        child: const Text('Open current team page'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SolarPrimaryButton(
                      label: 'Save profile',
                      onPressed: _saveProfile,
                      isLoading: _isSavingProfile,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Security',
                      style: TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SolarTextField(
                      controller: _currentPasswordController,
                      hintText: 'Current password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    SolarTextField(
                      controller: _newPasswordController,
                      hintText: 'New password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    SolarTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm new password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 18),
                    SolarPrimaryButton(
                      label: 'Update password',
                      onPressed: _updatePassword,
                      isLoading: _isUpdatingPassword,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: controller.refreshTeamStats,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        side: const BorderSide(color: Color(0xFF16182C)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Refresh team data',
                        style: TextStyle(
                          color: Color(0xFF16182C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Developer',
                      style: TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Preview match reminders, live activities, widget layouts, and the onboarding flow without leaving the app.',
                      style: TextStyle(
                        color: Color(0xFF8E92A7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _DeveloperActionButton(
                          icon: Icons.notifications_active_outlined,
                          label: 'Test reminder',
                          onTap: _previewReminder,
                        ),
                        _DeveloperActionButton(
                          icon: Icons.view_timeline_rounded,
                          label: 'Preview live activity',
                          onTap: () => _previewSurface(
                            title: 'Live Activity Preview',
                            widgetStyle: false,
                          ),
                        ),
                        _DeveloperActionButton(
                          icon: Icons.widgets_outlined,
                          label: 'Preview widget',
                          onTap: () => _previewSurface(
                            title: 'Widget Preview',
                            widgetStyle: true,
                          ),
                        ),
                        _DeveloperActionButton(
                          icon: Icons.rocket_launch_outlined,
                          label: 'Replay onboarding',
                          onTap: _openOnboardingPreview,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8FD),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'The developer previews use the same next-match payload that now syncs to iOS notifications, widgets, and live activities.',
                        style: TextStyle(
                          color: Color(0xFF5C6074),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsChoiceRow<T> extends StatelessWidget {
  const _SettingsChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final Future<void> Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E92A7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((option) {
                  final selected = option == value;
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        labelBuilder(option),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF24243A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _DeveloperActionButton extends StatelessWidget {
  const _DeveloperActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF8F8FD),
        foregroundColor: const Color(0xFF24243A),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _DeveloperQuickviewPreview extends StatelessWidget {
  const _DeveloperQuickviewPreview({
    required this.snapshot,
    required this.match,
    required this.widgetStyle,
  });

  final SolarQuickviewSnapshot snapshot;
  final MatchSummary match;
  final bool widgetStyle;

  @override
  Widget build(BuildContext context) {
    final scheduled = match.scheduled ?? match.started;
    final scheduledLabel = scheduled == null
        ? 'Time pending'
        : TimeOfDay.fromDateTime(scheduled.toLocal()).format(context);
    final fieldLabel = match.field.trim().isEmpty
        ? 'Field pending'
        : match.field;
    final redTeams = match.alliances
        .where((alliance) => alliance.color.toLowerCase() == 'red')
        .expand((alliance) => alliance.teams)
        .map((team) => team.number)
        .join('  •  ');
    final blueTeams = match.alliances
        .where((alliance) => alliance.color.toLowerCase() == 'blue')
        .expand((alliance) => alliance.teams)
        .map((team) => team.number)
        .join('  •  ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        widgetStyle ? 18 : 20,
        widgetStyle ? 18 : 20,
        widgetStyle ? 18 : 20,
        widgetStyle ? 18 : 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0D1020), Color(0xFF1B2543)],
        ),
        borderRadius: BorderRadius.circular(widgetStyle ? 24 : 28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widgetStyle ? 'Next match widget' : 'Live activity',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      match.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widgetStyle ? 22 : 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  scheduledLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.event.name,
            maxLines: widgetStyle ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: widgetStyle ? 16 : 18,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${match.division.name}  •  $fieldLabel',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _DeveloperAllianceColumn(
                  title: 'Red',
                  teams: redTeams.isEmpty ? 'Pending' : redTeams,
                  color: const Color(0xFFFF8E87),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _DeveloperAllianceColumn(
                  title: 'Blue',
                  teams: blueTeams.isEmpty ? 'Pending' : blueTeams,
                  color: const Color(0xFF8FB0FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeveloperAllianceColumn extends StatelessWidget {
  const _DeveloperAllianceColumn({
    required this.title,
    required this.teams,
    required this.color,
  });

  final String title;
  final String teams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          teams,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E92A7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FD),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled
                  ? const Color(0xFF8E92A7)
                  : const Color(0xFFC1C4D3),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonOptionTile extends StatelessWidget {
  const _SeasonOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF0FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5B61F6)
                : const Color(0xFFE6E8F2),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // ignore: use_null_aware_elements
            if (trailing case final trailing?) trailing,
          ],
        ),
      ),
    );
  }
}
