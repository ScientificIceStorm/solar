import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import 'event_team_screen.dart';

class EventSkillsScreen extends StatefulWidget {
  const EventSkillsScreen({required this.event, super.key});

  static const routeName = '/event-skills';

  final EventSummary event;

  @override
  State<EventSkillsScreen> createState() => _EventSkillsScreenState();
}

class _EventSkillsScreenState extends State<EventSkillsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final highlightedTeamNumber = controller.currentAccount?.team.number;

    return SolarEventSubpageScaffold(
      title: 'Skills Rankings',
      subtitle: widget.event.name,
      body: FutureBuilder<List<SkillAttempt>>(
        future: controller.fetchEventSkills(widget.event.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _CenteredLoader();
          }

          final skills = snapshot.data!;
          if (skills.isEmpty) {
            return const _EmptyEventState(
              title: 'No skills results yet',
              body:
                  'When event skills runs are published, they will appear here.',
            );
          }

          final query = _searchController.text.trim().toLowerCase();
          final combinedEntries = _buildCombinedEntries(skills)
              .where((entry) {
                if (query.isEmpty) {
                  return true;
                }
                final teamName = entry.team.name.trim().toLowerCase();
                final teamNumber = entry.team.number.trim().toLowerCase();
                return teamNumber.contains(query) || teamName.contains(query);
              })
              .toList(growable: false);

          return Column(
            children: <Widget>[
              _EventSkillsSearchField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: combinedEntries.isEmpty
                    ? const _EmptyEventState(
                        title: 'No matching teams',
                        body:
                            'Try another team number or team name to search the skills table.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: combinedEntries.length,
                        itemBuilder: (context, index) {
                          final entry = combinedEntries[index];
                          final resolvedTeam = controller
                              .resolveKnownTeamSummary(
                                teamNumber: entry.team.number,
                                teamId: entry.team.id,
                                teamName: entry.team.name,
                              );
                          return _CombinedSkillRow(
                            entry: entry,
                            team: resolvedTeam,
                            event: widget.event,
                            highlighted:
                                highlightedTeamNumber != null &&
                                entry.team.number.trim().toUpperCase() ==
                                    highlightedTeamNumber.trim().toUpperCase(),
                            showDivider: index != combinedEntries.length - 1,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventSkillsSearchField extends StatelessWidget {
  const _EventSkillsSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search skills rankings',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }
}

class _CombinedSkillRow extends StatelessWidget {
  const _CombinedSkillRow({
    required this.entry,
    required this.team,
    required this.event,
    required this.highlighted,
    required this.showDivider,
  });

  final _CombinedSkillEntry entry;
  final TeamSummary team;
  final EventSummary event;
  final bool highlighted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final labelColor = highlighted
        ? const Color(0xFF2930FF)
        : const Color(0xFF16182C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          openSolarEventTeamScreen(
            context,
            event: event,
            team: team,
            highlightTeamNumber: team.number,
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 42,
                child: Text(
                  '${entry.rank}',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.team.number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 20,
                        fontWeight: highlighted
                            ? FontWeight.w700
                            : FontWeight.w600,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.team.name.trim().isEmpty
                          ? 'Event team profile'
                          : entry.team.name.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF707487),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _SkillMetricChip(
                          icon: Icons.sports_esports_rounded,
                          score: entry.driverScore,
                          attempts: entry.driverAttempts,
                          color: const Color(0xFF2A7FFF),
                        ),
                        _SkillMetricChip(
                          icon: Icons.memory_rounded,
                          score: entry.programmingScore,
                          attempts: entry.programmingAttempts,
                          color: const Color(0xFF7F61FF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${entry.combinedScore}',
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillMetricChip extends StatelessWidget {
  const _SkillMetricChip({
    required this.icon,
    required this.score,
    required this.attempts,
    required this.color,
  });

  final IconData icon;
  final int score;
  final int attempts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$attempts att',
            style: const TextStyle(
              color: Color(0xFF6F748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CombinedSkillEntry {
  const _CombinedSkillEntry({
    required this.rank,
    required this.team,
    required this.programmingScore,
    required this.programmingAttempts,
    required this.driverScore,
    required this.driverAttempts,
  });

  final int rank;
  final TeamReference team;
  final int programmingScore;
  final int programmingAttempts;
  final int driverScore;
  final int driverAttempts;

  int get combinedScore => programmingScore + driverScore;
}

List<_CombinedSkillEntry> _buildCombinedEntries(List<SkillAttempt> attempts) {
  final bestByTeam = <String, _CombinedSkillScratch>{};

  for (final attempt in attempts) {
    final key = attempt.team.number.trim().toUpperCase();
    final scratch = bestByTeam.putIfAbsent(
      key,
      () => _CombinedSkillScratch(team: attempt.team),
    );

    final normalizedType = attempt.type.toLowerCase();
    if (normalizedType.contains('program') ||
        normalizedType.contains('auton')) {
      if (attempt.score > scratch.programmingScore) {
        scratch.programmingScore = attempt.score;
        scratch.programmingAttempts = attempt.attempts;
      }
      continue;
    }

    if (normalizedType.contains('driver') &&
        attempt.score > scratch.driverScore) {
      scratch.driverScore = attempt.score;
      scratch.driverAttempts = attempt.attempts;
    }
  }

  final ordered = bestByTeam.values.toList(growable: false)
    ..sort((a, b) {
      if (a.combinedScore != b.combinedScore) {
        return b.combinedScore.compareTo(a.combinedScore);
      }
      if (a.driverScore != b.driverScore) {
        return b.driverScore.compareTo(a.driverScore);
      }
      if (a.programmingScore != b.programmingScore) {
        return b.programmingScore.compareTo(a.programmingScore);
      }
      return a.team.number.compareTo(b.team.number);
    });

  return List<_CombinedSkillEntry>.generate(ordered.length, (index) {
    final item = ordered[index];
    return _CombinedSkillEntry(
      rank: index + 1,
      team: item.team,
      programmingScore: item.programmingScore,
      programmingAttempts: item.programmingAttempts,
      driverScore: item.driverScore,
      driverAttempts: item.driverAttempts,
    );
  }, growable: false);
}

class _CombinedSkillScratch {
  _CombinedSkillScratch({required this.team});

  final TeamReference team;
  int programmingScore = 0;
  int programmingAttempts = 0;
  int driverScore = 0;
  int driverAttempts = 0;

  int get combinedScore => programmingScore + driverScore;
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _EmptyEventState extends StatelessWidget {
  const _EmptyEventState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
