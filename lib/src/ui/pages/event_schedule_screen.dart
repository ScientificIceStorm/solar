import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/solar_match_prediction.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import '../widgets/solar_match_row.dart';
import 'event_team_screen.dart';
import 'match_details_screen.dart';

class EventScheduleScreen extends StatefulWidget {
  const EventScheduleScreen({required this.event, super.key});

  static const routeName = '/event-schedule';

  final EventSummary event;

  @override
  State<EventScheduleScreen> createState() => _EventScheduleScreenState();
}

class _EventScheduleScreenState extends State<EventScheduleScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _predictionModeEnabled = false;
  Future<Map<int, SolarMatchPrediction?>>? _predictionFuture;
  String? _predictionCacheKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _predictionKey(List<MatchSummary> matches) {
    final ids = matches.map((match) => '${match.id}').join(',');
    return '${widget.event.id}|$ids';
  }

  Future<Map<int, SolarMatchPrediction?>> _loadPredictions(
    List<MatchSummary> matches,
  ) async {
    final controller = SolarAppScope.of(context);
    final predictions = <int, SolarMatchPrediction?>{};
    for (final match in matches) {
      if (match.alliances.length < 2) {
        predictions[match.id] = null;
        continue;
      }

      try {
        predictions[match.id] = await controller.predictMatch(
          match: match,
          event: widget.event,
        );
      } catch (_) {
        predictions[match.id] = null;
      }
    }
    return predictions;
  }

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final teamNumber = controller.currentAccount?.team.number ?? 'Team';

    return SolarEventSubpageScaffold(
      title: '$teamNumber Schedule',
      subtitle: widget.event.name,
      body: FutureBuilder<List<MatchSummary>>(
        future: controller.fetchTeamScheduleForEvent(widget.event.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _CenteredLoader();
          }

          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return const _EmptyEventState(
              title: 'No scheduled matches yet',
              body: 'When this event publishes match pairings, they will show up here.',
            );
          }

          final query = _searchController.text.trim().toLowerCase();
          final visibleMatches = query.isEmpty
              ? matches
              : matches.where((match) {
                  if (solarMatchScreenLabel(match).toLowerCase().contains(query)) {
                    return true;
                  }
                  for (final alliance in match.alliances) {
                    for (final team in alliance.teams) {
                      final label =
                          '${team.number} ${team.name}'.trim().toLowerCase();
                      if (label.contains(query)) {
                        return true;
                      }
                    }
                  }
                  return false;
                }).toList(growable: false);

          if (visibleMatches.isEmpty) {
            return const _EmptyEventState(
              title: 'No matches found',
              body: 'Try a different team number or match label.',
            );
          }

          Widget matchesList(Map<int, SolarMatchPrediction?> predictionsByMatch) {
            return StretchingOverscrollIndicator(
              axisDirection: AxisDirection.down,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: visibleMatches.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _ScheduleToolbar(
                      controller: _searchController,
                      predictionModeEnabled: _predictionModeEnabled,
                      matchCount: visibleMatches.length,
                      onChanged: (_) => setState(() {}),
                      onPredictionModeChanged: (value) {
                        setState(() {
                          _predictionModeEnabled = value;
                        });
                      },
                    );
                  }

                  final match = visibleMatches[index - 1];
                  final prediction = predictionsByMatch[match.id];
                  return SolarMatchRow(
                    match: match,
                    highlightTeamNumber: teamNumber,
                    stripeColorOverride: _predictionModeEnabled
                        ? _predictionStripeColor(prediction)
                        : null,
                    scoreTextOverride: _predictionModeEnabled
                        ? _predictedScoreText(prediction)
                        : null,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        MatchDetailsScreen.routeName,
                        arguments: MatchDetailsScreenArgs(
                          match: match,
                          event: widget.event,
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
                        event: widget.event,
                        team: resolvedTeam,
                        highlightTeamNumber: team.number,
                      );
                    },
                  );
                },
              ),
            );
          }

          if (!_predictionModeEnabled) {
            return matchesList(const <int, SolarMatchPrediction?>{});
          }

          final predictionKey = _predictionKey(visibleMatches);
          if (_predictionFuture == null || _predictionCacheKey != predictionKey) {
            _predictionCacheKey = predictionKey;
            _predictionFuture = _loadPredictions(visibleMatches);
          }

          return FutureBuilder<Map<int, SolarMatchPrediction?>>(
            future: _predictionFuture,
            builder: (context, predictionSnapshot) {
              if (!predictionSnapshot.hasData) {
                return const _CenteredLoader();
              }
              return matchesList(predictionSnapshot.data!);
            },
          );
        },
      ),
    );
  }
}

class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({
    required this.controller,
    required this.predictionModeEnabled,
    required this.matchCount,
    required this.onChanged,
    required this.onPredictionModeChanged,
  });

  final TextEditingController controller;
  final bool predictionModeEnabled;
  final int matchCount;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onPredictionModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7DBEA)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6F748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Search matches or teams',
                      hintStyle: TextStyle(
                        color: Color(0xFF8E92A7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$matchCount',
                  style: const TextStyle(
                    color: Color(0xFF6F748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () =>
                    onPredictionModeChanged(!predictionModeEnabled),
                icon: Icon(
                  Icons.analytics_outlined,
                  size: 18,
                  color: predictionModeEnabled
                      ? const Color(0xFF16182C)
                      : const Color(0xFF5F6478),
                ),
                label: Text(
                  predictionModeEnabled
                      ? 'Show actual scores again'
                      : 'Show predicted scores',
                  style: TextStyle(
                    color: predictionModeEnabled
                        ? const Color(0xFF16182C)
                        : const Color(0xFF5F6478),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Switch.adaptive(
                value: predictionModeEnabled,
                onChanged: onPredictionModeChanged,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF5F66FF),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

TextSpan _predictedScoreText(SolarMatchPrediction? prediction) {
  const baseColor = Color(0xFF8E92A7);
  if (prediction == null) {
    return const TextSpan(
      text: '-- - --',
      style: TextStyle(
        color: baseColor,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
      ),
    );
  }

  final redScore = prediction.predictedRedScore;
  final blueScore = prediction.predictedBlueScore;
  final redWins = redScore > blueScore;
  final blueWins = blueScore > redScore;

  TextStyle scoreStyle(bool emphasized) {
    return const TextStyle(
      color: baseColor,
      fontSize: 20,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
    ).copyWith(fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500);
  }

  return TextSpan(
    children: <InlineSpan>[
      TextSpan(
        text: '$redScore',
        style: scoreStyle(redWins || (!redWins && !blueWins)),
      ),
      const TextSpan(
        text: ' - ',
        style: TextStyle(
          color: baseColor,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
        ),
      ),
      TextSpan(
        text: '$blueScore',
        style: scoreStyle(blueWins || (!redWins && !blueWins)),
      ),
    ],
  );
}

Color _predictionStripeColor(SolarMatchPrediction? prediction) {
  if (prediction == null) {
    return const Color(0xFFDADAE3);
  }
  if (prediction.predictedRedScore == prediction.predictedBlueScore) {
    return const Color(0xFFD6AF52);
  }
  return prediction.predictedRedScore > prediction.predictedBlueScore
      ? const Color(0xFF3FCB73)
      : const Color(0xFFFF6B64);
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
    );
  }
}
