import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../core/solar_competition_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/solar_match_prediction.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import '../widgets/solar_match_row.dart';
import '../widgets/solar_team_link.dart';
import 'event_team_screen.dart';

class MatchDetailsScreenArgs {
  const MatchDetailsScreenArgs({
    required this.match,
    this.event,
    this.highlightTeamNumber,
  });

  final MatchSummary match;
  final EventSummary? event;
  final String? highlightTeamNumber;
}

class MatchDetailsScreen extends StatelessWidget {
  const MatchDetailsScreen({required this.args, super.key});

  static const routeName = '/match-details';

  final MatchDetailsScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final event =
        args.event ?? controller.resolveKnownEvent(args.match.event.id);

    return SolarEventSubpageScaffold(
      title: solarMatchScreenLabel(args.match),
      subtitle: event?.name ?? args.match.event.name,
      body: FutureBuilder<SolarMatchPrediction?>(
        future: controller.predictMatch(match: args.match, event: event),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredLoader();
          }

          final prediction = snapshot.data;
          if (prediction == null) {
            return const _InlineMessage(
              'Prediction data is unavailable until Solar can reach the live event APIs.',
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              _MatchMetaHeader(
                match: args.match,
                event: event,
                prediction: prediction,
              ),
              const SizedBox(height: 22),
              _PredictionSection(prediction: prediction),
              const SizedBox(height: 24),
              _AllianceSection(
                title: 'Red Alliance',
                alliance: prediction.redAlliance,
                color: const Color(0xFFFF6B64),
                event: event,
              ),
              const SizedBox(height: 24),
              _AllianceSection(
                title: 'Blue Alliance',
                alliance: prediction.blueAlliance,
                color: const Color(0xFF7A9DFF),
                event: event,
              ),
              const SizedBox(height: 24),
              _FlatSection(
                title: '$solarizeLabel Readout',
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < prediction.insights.length; i++)
                      _ReadoutRow(
                        text: prediction.insights[i],
                        showDivider: i != prediction.insights.length - 1,
                      ),
                  ],
                ),
              ),
              if (prediction.hasActualResult) ...<Widget>[
                const SizedBox(height: 24),
                _ActualResultSection(prediction: prediction),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MatchMetaHeader extends StatelessWidget {
  const _MatchMetaHeader({
    required this.match,
    required this.event,
    required this.prediction,
  });

  final MatchSummary match;
  final EventSummary? event;
  final SolarMatchPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final anchor = match.scheduled ?? match.started;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          [
            if (event != null) _locationLabel(event!.location),
            if (match.division.name.trim().isNotEmpty) match.division.name,
          ].join('  •  '),
          style: const TextStyle(
            color: Color(0xFF8E92A7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        SolarMatchRow(
          match: match,
          highlightTeamNumber: null,
          onTeamTap: (teamReference) {
            if (event != null) {
              final controller = SolarAppScope.of(context);
              final resolvedTeam = controller.resolveKnownTeamSummary(
                teamNumber: teamReference.number,
                teamId: teamReference.id,
                teamName: teamReference.name,
              );
              openSolarEventTeamScreen(
                context,
                event: event!,
                team: resolvedTeam,
                highlightTeamNumber: teamReference.number,
              );
              return;
            }
            openSolarTeamProfileForReference(
              context,
              teamNumber: teamReference.number,
              teamId: teamReference.id,
              teamName: teamReference.name,
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: <Widget>[
            _MetaPill(
              label: anchor == null ? 'Time pending' : _dateTimeLabel(anchor),
            ),
            _MetaPill(label: '${prediction.evidenceMatches} matches'),
            _MetaPill(label: '${(prediction.confidence * 100).round()}% conf.'),
            if (prediction.hasActualResult)
              _MetaPill(label: prediction.predictionDeltaLabel),
          ],
        ),
      ],
    );
  }
}

class _PredictionSection extends StatelessWidget {
  const _PredictionSection({required this.prediction});

  final SolarMatchPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final favoredColor = prediction.favoredAllianceColor == 'red'
        ? const Color(0xFFFF6B64)
        : const Color(0xFF7A9DFF);

    return _FlatSection(
      title: 'Prediction',
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${prediction.predictedRedScore} - ${prediction.predictedBlueScore}',
                style: const TextStyle(
                  color: Color(0xFF191B35),
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${prediction.favoredAllianceLabel} ${(prediction.favoredWinProbability * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: favoredColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PredictionMetricRow(
            label: 'Red win chance',
            value: '${(prediction.redWinProbability * 100).round()}%',
          ),
          _PredictionMetricRow(
            label: 'Blue win chance',
            value: '${(prediction.blueWinProbability * 100).round()}%',
          ),
          _PredictionMetricRow(
            label: '$solarizeLabel confidence',
            value: '${(prediction.confidence * 100).round()}%',
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _AllianceSection extends StatelessWidget {
  const _AllianceSection({
    required this.title,
    required this.alliance,
    required this.color,
    required this.event,
  });

  final String title;
  final SolarAlliancePrediction alliance;
  final Color color;
  final EventSummary? event;

  @override
  Widget build(BuildContext context) {
    return _FlatSection(
      title: title,
      child: Column(
        children: <Widget>[
          _PredictionMetricRow(
            label: 'Projected score',
            value: alliance.projectedScore.round().toString(),
          ),
          _PredictionMetricRow(
            label: 'Alliance rating',
            value: alliance.strength.toStringAsFixed(1),
          ),
          _PredictionMetricRow(
            label: 'Offense / Defense',
            value:
                '${alliance.offense.toStringAsFixed(1)} / ${alliance.defense.toStringAsFixed(1)}',
          ),
          _PredictionMetricRow(
            label: 'Momentum',
            value: alliance.momentum.toStringAsFixed(1),
            showDivider: alliance.teams.isNotEmpty,
          ),
          for (var i = 0; i < alliance.teams.length; i++)
            _TeamModelRow(
              team: alliance.teams[i],
              color: color,
              event: event,
              showDivider: i != alliance.teams.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ActualResultSection extends StatelessWidget {
  const _ActualResultSection({required this.prediction});

  final SolarMatchPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final accuracy = prediction.predictedCorrectly;
    return _FlatSection(
      title: 'Actual Result',
      child: Column(
        children: <Widget>[
          _PredictionMetricRow(
            label: 'Final score',
            value:
                '${prediction.actualRedScore} - ${prediction.actualBlueScore}',
          ),
          _PredictionMetricRow(
            label: 'Prediction delta',
            value: prediction.predictionDeltaLabel,
          ),
          _PredictionMetricRow(
            label: '$solarizeLabel call',
            value: accuracy == null
                ? 'Too close to grade'
                : accuracy
                ? 'Correct'
                : 'Missed',
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              prediction.predictionDeltaSummary,
              style: const TextStyle(
                color: Color(0xFF6F748B),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamModelRow extends StatelessWidget {
  const _TeamModelRow({
    required this.team,
    required this.color,
    required this.event,
    required this.showDivider,
  });

  final SolarTeamPrediction team;
  final Color color;
  final EventSummary? event;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFDADAE3)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SolarTeamLinkText(
                  teamNumber: team.team.number,
                  teamId: team.team.id,
                  teamName: team.team.name,
                  onTap: () {
                    if (event != null) {
                      final resolvedTeam = controller.resolveKnownTeamSummary(
                        teamNumber: team.team.number,
                        teamId: team.team.id,
                        teamName: team.team.name,
                      );
                      openSolarEventTeamScreen(
                        context,
                        event: event!,
                        team: resolvedTeam,
                        highlightTeamNumber: team.team.number,
                      );
                      return;
                    }
                    openSolarTeamProfileForReference(
                      context,
                      teamNumber: team.team.number,
                      teamId: team.team.id,
                      teamName: team.team.name,
                    );
                  },
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Off ${team.offense.toStringAsFixed(1)}  •  Def ${team.defense.toStringAsFixed(1)}  •  Mom ${team.momentum.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Color(0xFF6F748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prior ${team.priorEventMatches} event  •  ${team.priorSeasonMatches} season  •  WR ${team.worldRank ?? '--'}',
                  style: const TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (team.eventCombinedSkills != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Skills ${team.eventCombinedSkills}  •  Driver ${team.eventDriverScore ?? 0}  •  Auton ${team.eventAutonScore ?? 0}',
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            team.compositeRating.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFF191B35),
              fontSize: 26,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatSection extends StatelessWidget {
  const _FlatSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF24243A),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _PredictionMetricRow extends StatelessWidget {
  const _PredictionMetricRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFDADAE3)))
            : null,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6F748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF191B35),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadoutRow extends StatelessWidget {
  const _ReadoutRow({required this.text, required this.showDivider});

  final String text;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFDADAE3)))
            : null,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4B4F68),
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6F748B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8E92A7),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }
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

String _locationLabel(LocationSummary location) {
  final pieces = <String>[
    if (location.city.trim().isNotEmpty) location.city.trim(),
    if (location.region.trim().isNotEmpty) location.region.trim(),
  ];
  return pieces.isEmpty ? 'Location pending' : pieces.join(', ');
}

String _dateTimeLabel(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.month}/${value.day}  $hour:$minute $suffix';
}
