import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import '../widgets/solar_team_link.dart';

class EventSkillsScreen extends StatelessWidget {
  const EventSkillsScreen({required this.event, super.key});

  static const routeName = '/event-skills';

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final highlightedTeamNumber = controller.currentAccount?.team.number;

    return SolarEventSubpageScaffold(
      title: 'Skills Rankings',
      subtitle: event.name,
      body: FutureBuilder<List<SkillAttempt>>(
        future: controller.fetchEventSkills(event.id),
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

          final combinedEntries = _buildCombinedEntries(skills);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: combinedEntries.length,
            itemBuilder: (context, index) {
              final entry = combinedEntries[index];
              return _CombinedSkillRow(
                entry: entry,
                highlighted:
                    highlightedTeamNumber != null &&
                    entry.team.number.trim().toUpperCase() ==
                        highlightedTeamNumber.trim().toUpperCase(),
                showDivider: index != combinedEntries.length - 1,
              );
            },
          );
        },
      ),
    );
  }
}

class _CombinedSkillRow extends StatelessWidget {
  const _CombinedSkillRow({
    required this.entry,
    required this.highlighted,
    required this.showDivider,
  });

  final _CombinedSkillEntry entry;
  final bool highlighted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final labelColor = highlighted
        ? const Color(0xFF2930FF)
        : const Color(0xFF16182C);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 44,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${entry.rank}',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SolarTeamLinkText(
                      teamNumber: entry.team.number,
                      teamId: entry.team.id,
                      teamName: entry.team.name,
                      maxLines: 1,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 20,
                        fontWeight: highlighted
                            ? FontWeight.w500
                            : FontWeight.w400,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'D ${entry.driverScore} • A ${entry.programmingScore}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF707487),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 56, maxWidth: 76),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${entry.combinedScore}',
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF64677A),
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showDivider) ...<Widget>[
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0xFFDADAE3)),
          ],
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
    required this.driverScore,
  });

  final int rank;
  final TeamReference team;
  final int programmingScore;
  final int driverScore;

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
      }
      continue;
    }

    if (normalizedType.contains('driver')) {
      if (attempt.score > scratch.driverScore) {
        scratch.driverScore = attempt.score;
      }
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
      driverScore: item.driverScore,
    );
  }, growable: false);
}

class _CombinedSkillScratch {
  _CombinedSkillScratch({required this.team});

  final TeamReference team;
  int programmingScore = 0;
  int driverScore = 0;

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
