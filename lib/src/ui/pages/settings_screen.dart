import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../core/solar_competition_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/app_account.dart';
import '../widgets/solar_page_scaffold.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_primary_button.dart';
import '../widgets/solar_team_link.dart';
import '../widgets/solar_text_field.dart';

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
  Future<List<SeasonSummary>>? _seasonsFuture;
  bool _didSeedProfile = false;
  bool _isSavingProfile = false;
  int? _selectedSeasonId;
  bool _showDeveloperTools = false;
  AppCompetitionPreference? _seasonCompetitionPreference;

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

    if (_seasonCompetitionPreference != controller.competitionPreference ||
        _seasonsFuture == null) {
      _seasonCompetitionPreference = controller.competitionPreference;
      _seasonsFuture = controller.fetchWorldSkillsSeasons(
        programFilter: _programFilterForCompetition(
          controller.competitionPreference,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
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
      ).showSnackBar(const SnackBar(content: Text('Settings updated.')));
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

  String _programFilterForCompetition(AppCompetitionPreference preference) {
    return switch (preference) {
      AppCompetitionPreference.vexV5 => solarPrimaryProgramFilter,
      AppCompetitionPreference.vexIQ => 'vex iq',
      AppCompetitionPreference.vexU => 'vex u',
      AppCompetitionPreference.vexAI => 'vex ai',
    };
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

  Future<void> _runCompanionPreview() async {
    final controller = SolarAppScope.of(context);
    await controller.refreshTeamStats();
    await controller.syncIosCompanion();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Live activity and widgets were refreshed with current team data.',
        ),
      ),
    );
  }

  Future<void> _clearCompanionPreview() async {
    final controller = SolarAppScope.of(context);
    await controller.clearIosCompanion();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live activity preview cleared.')),
    );
  }

  Future<void> _pickDeveloperScrimmageStartAt() async {
    final controller = SolarAppScope.of(context);
    final current =
        controller.developerScrimmageStartAt ?? DateTime.now().toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || pickedDate == null) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted || pickedTime == null) {
      return;
    }

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    await controller.setDeveloperScrimmageStartAt(combined);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Quickview scrimmage now starts ${_developerScrimmageLabel(combined)}.',
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
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Team',
                      style: TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SolarTextField(
                      controller: _nameController,
                      hintText: 'Display name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
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
                            ? 'Checking the active season.'
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
                      onSelected: (value) async {
                        await controller.setCompetitionPreference(value);
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _seasonCompetitionPreference = value;
                          _selectedSeasonId = controller.preferredSeasonId;
                          _seasonsFuture = controller.fetchWorldSkillsSeasons(
                            programFilter: _programFilterForCompetition(value),
                            force: true,
                          );
                        });
                      },
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
                      label: 'Save',
                      onPressed: _saveProfile,
                      isLoading: _isSavingProfile,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showDeveloperTools = !_showDeveloperTools;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _showDeveloperTools
                        ? 'Hide developer tools'
                        : 'Developer tools',
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              if (_showDeveloperTools) ...<Widget>[
                const SizedBox(height: 8),
                _SectionCard(
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
                      const SizedBox(height: 10),
                      const Text(
                        'Keep test-only scrimmage data hidden in normal use. Turn it on only when you want to preview the local Quickview test event.',
                        style: TextStyle(
                          color: Color(0xFF8E92A7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SwitchRow(
                        title: 'Show Quickview test scrimmage',
                        subtitle: controller.developerScrimmageEnabled
                            ? 'Enabled for local debugging.'
                            : 'Hidden from the app.',
                        value: controller.developerScrimmageEnabled,
                        onChanged: (value) {
                          controller.setDeveloperScrimmageEnabled(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _SelectionField(
                        label: 'Scrimmage start',
                        value: controller.developerScrimmageStartAt == null
                            ? 'Not set'
                            : _developerScrimmageLabel(
                                controller.developerScrimmageStartAt!,
                              ),
                        subtitle: controller.developerScrimmageEnabled
                            ? 'Controls when Q1 and the whole test event begin. This stays pinned until you change it again.'
                            : 'Enable the scrimmage first, then set the start time once so it does not keep drifting.',
                        enabled: controller.developerScrimmageEnabled,
                        onTap: _pickDeveloperScrimmageStartAt,
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
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _runCompanionPreview,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: const BorderSide(color: Color(0xFF16182C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Test live activity + widgets',
                          style: TextStyle(
                            color: Color(0xFF16182C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _clearCompanionPreview,
                        child: const Text('Clear live activity preview'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _developerScrimmageLabel(DateTime value) {
  final local = value.toLocal();
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hourOfPeriod = local.hour % 12;
  final hour = hourOfPeriod == 0 ? 12 : hourOfPeriod;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day}/${local.year}  $hour:$minute $period';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  title,
                  style: const TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
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
            ...?trailing == null ? null : <Widget>[trailing!],
          ],
        ),
      ),
    );
  }
}
