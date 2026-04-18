import 'package:flutter/material.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/solar_match_prediction.dart';
import 'match_details_screen.dart';
import 'event_team_screen.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import '../widgets/solar_match_row.dart';

class EventScheduleScreen extends StatelessWidget {
  const EventScheduleScreen({required this.event, super.key});

  static const routeName = '/event-schedule';

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final teamNumber = controller.currentAccount?.team.number ?? 'Team';

    return SolarEventSubpageScaffold(
      title: '$teamNumber Schedule',
      subtitle: event.name,
      body: FutureBuilder<List<MatchSummary>>(
        future: controller.fetchTeamScheduleForEvent(event.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _CenteredLoader();
          }

          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return const _EmptyEventState(
              title: 'No scheduled matches yet',
              body:
                  'When RobotEvents publishes this team schedule, it will show up here.',
            );
          }

          return StretchingOverscrollIndicator(
            axisDirection: AxisDirection.down,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _openPredictionsSheet(
                          context: context,
                          controller: controller,
                          matches: matches,
                          event: event,
                        );
                      },
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('All match predictions'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD2E7)),
                        foregroundColor: const Color(0xFF16182C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: matches.length,
                    itemBuilder: (context, index) => SolarMatchRow(
                      match: matches[index],
                      highlightTeamNumber: teamNumber,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          MatchDetailsScreen.routeName,
                          arguments: MatchDetailsScreenArgs(
                            match: matches[index],
                            event: event,
                            highlightTeamNumber: teamNumber,
                          ),
                        );
                      },
                      onTeamTap: (team) {
                        final resolvedTeam = controller.resolveKnownTeamSummary(
                          teamNumber: team.number,
                          teamId: team.id,
                          teamName: team.name,
                        );
                        openSolarEventTeamScreen(
                          context,
                          event: event,
                          team: resolvedTeam,
                          highlightTeamNumber: team.number,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPredictionsSheet({
    required BuildContext context,
    required AppSessionController controller,
    required List<MatchSummary> matches,
    required EventSummary event,
  }) async {
    final scopedMatches = matches
        .where((match) => match.alliances.length >= 2)
        .toList(growable: false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F5F8),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: FutureBuilder<List<_SchedulePredictionItem>>(
              future: _loadMatchPredictions(
                controller: controller,
                event: event,
                matches: scopedMatches,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  );
                }

                final predictions = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'All Match Predictions',
                      style: TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Red and blue highlights show the projected winner for each published match.',
                      style: TextStyle(
                        color: Color(0xFF6F748B),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.builder(
                        itemCount: predictions.length,
                        itemBuilder: (context, index) {
                          final item = predictions[index];
                          final prediction = item.prediction;
                          final winnerColor = _predictionWinnerColor(prediction);
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFDCE0EC)),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 8,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: winnerColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        _schedulePredictionLabel(item.match),
                                        style: const TextStyle(
                                          color: Color(0xFF24243A),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        prediction == null
                                            ? 'Prediction unavailable'
                                            : 'Projected ${prediction.predictedRedScore}-${prediction.predictedBlueScore}',
                                        style: const TextStyle(
                                          color: Color(0xFF6F748B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<List<_SchedulePredictionItem>> _loadMatchPredictions({
    required AppSessionController controller,
    required EventSummary event,
    required List<MatchSummary> matches,
  }) async {
    return Future.wait<_SchedulePredictionItem>(
      matches.map((match) async {
        SolarMatchPrediction? prediction;
        try {
          prediction = await controller.predictMatch(match: match, event: event);
        } catch (_) {
          prediction = null;
        }
        return _SchedulePredictionItem(match: match, prediction: prediction);
      }),
    );
  }
}

class _SchedulePredictionItem {
  const _SchedulePredictionItem({required this.match, required this.prediction});

  final MatchSummary match;
  final SolarMatchPrediction? prediction;
}

Color _predictionWinnerColor(SolarMatchPrediction? prediction) {
  if (prediction == null) {
    return const Color(0xFFB8BECE);
  }
  if (prediction.predictedRedScore > prediction.predictedBlueScore) {
    return const Color(0xFFD24E4E);
  }
  if (prediction.predictedBlueScore > prediction.predictedRedScore) {
    return const Color(0xFF2E6BF2);
  }
  return const Color(0xFF8D92A8);
}

String _schedulePredictionLabel(MatchSummary match) {
  String prefix;
  switch (match.round) {
    case MatchRound.qualification:
      prefix = 'Q';
    case MatchRound.practice:
      prefix = 'P';
    case MatchRound.quarterfinals:
      prefix = 'QF';
    case MatchRound.semifinals:
      prefix = 'SF';
    case MatchRound.finals:
      prefix = 'F';
    default:
      prefix = match.name.trim().isEmpty ? 'Match' : match.name.trim();
  }

  if (prefix == 'Match' || prefix == match.name.trim()) {
    return prefix;
  }

  final number = match.matchNumber > 0 ? match.matchNumber : match.instance;
  return number > 0 ? '$prefix$number' : prefix;
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
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
            border: Border.all(color: const Color(0xFFE3E6F0)),
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
