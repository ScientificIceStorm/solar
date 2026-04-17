import 'package:flutter/material.dart';

import '../../models/robot_events_models.dart';
import 'solar_team_link.dart';

class SolarMatchRow extends StatelessWidget {
  const SolarMatchRow({
    required this.match,
    this.highlightTeamNumber,
    this.onTap,
    this.onTeamTap,
    super.key,
  });

  final MatchSummary match;
  final String? highlightTeamNumber;
  final VoidCallback? onTap;
  final void Function(TeamReference team)? onTeamTap;

  @override
  Widget build(BuildContext context) {
    final redAlliance = _allianceForColor(match, 'red');
    final blueAlliance = _allianceForColor(match, 'blue');
    final teamResultColor = _highlightResultColor(
      match: match,
      highlightTeamNumber: highlightTeamNumber,
    );

    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      // Flat list treatment keeps the match rows crisp and avoids the
      // over-designed card look the user called out.
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 6,
            height: 52,
            decoration: BoxDecoration(
              color: teamResultColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  solarMatchTimeLabel(match),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB6B7C2),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    solarMatchScreenLabel(match),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: Color(0xFF191B35),
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AllianceColumn(
              teams: redAlliance?.teams ?? const <TeamReference>[],
              color: const Color(0xFFFF6B64),
              alignEnd: false,
              highlightTeamNumber: highlightTeamNumber,
              onTeamTap: onTeamTap,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 94,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                textAlign: TextAlign.center,
                text: solarMatchScoreText(redAlliance, blueAlliance),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AllianceColumn(
              teams: blueAlliance?.teams ?? const <TeamReference>[],
              color: const Color(0xFF7A9DFF),
              alignEnd: true,
              highlightTeamNumber: highlightTeamNumber,
              onTeamTap: onTeamTap,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

Color _highlightResultColor({
  required MatchSummary match,
  required String? highlightTeamNumber,
}) {
  if (highlightTeamNumber == null || highlightTeamNumber.trim().isEmpty) {
    return const Color(0xFFDADAE3);
  }

  final alliance = _allianceContainingTeam(match, highlightTeamNumber);
  final opponent = alliance == null ? null : _opposingAlliance(match, alliance);
  if (alliance == null ||
      opponent == null ||
      alliance.score < 0 ||
      opponent.score < 0) {
    return const Color(0xFFDADAE3);
  }

  if (alliance.score > opponent.score) {
    return const Color(0xFF3FCB73);
  }
  if (alliance.score < opponent.score) {
    return const Color(0xFFFF6B64);
  }
  return const Color(0xFFD6AF52);
}

MatchAlliance? _allianceContainingTeam(MatchSummary match, String teamNumber) {
  final normalized = teamNumber.trim().toUpperCase();
  for (final alliance in match.alliances) {
    for (final team in alliance.teams) {
      if (team.number.trim().toUpperCase() == normalized) {
        return alliance;
      }
    }
  }
  return null;
}

MatchAlliance? _opposingAlliance(
  MatchSummary match,
  MatchAlliance selectedAlliance,
) {
  for (final alliance in match.alliances) {
    if (!identical(alliance, selectedAlliance) &&
        alliance.color.toLowerCase() != selectedAlliance.color.toLowerCase()) {
      return alliance;
    }
  }

  for (final alliance in match.alliances) {
    if (!identical(alliance, selectedAlliance)) {
      return alliance;
    }
  }

  return null;
}

class _AllianceColumn extends StatelessWidget {
  const _AllianceColumn({
    required this.teams,
    required this.color,
    required this.alignEnd,
    required this.highlightTeamNumber,
    required this.onTeamTap,
  });

  final List<TeamReference> teams;
  final Color color;
  final bool alignEnd;
  final String? highlightTeamNumber;
  final void Function(TeamReference team)? onTeamTap;

  @override
  Widget build(BuildContext context) {
    final shownTeams = teams.take(2).toList(growable: false);

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: shownTeams.isEmpty
          ? <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  'TBD',
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.18,
                  ),
                ),
              ),
            ]
          : shownTeams
                .map((team) {
                  final isHighlighted =
                      highlightTeamNumber != null &&
                      team.number.trim().toUpperCase() ==
                          highlightTeamNumber!.trim().toUpperCase();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (onTeamTap != null) {
                            onTeamTap!(team);
                            return;
                          }
                          openSolarTeamProfileForReference(
                            context,
                            teamNumber: team.number,
                            teamId: team.id,
                            teamName: team.name,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              team.number,
                              textAlign: alignEnd
                                  ? TextAlign.right
                                  : TextAlign.left,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isHighlighted
                                    ? const Color(0xFF191B35)
                                    : color,
                                fontSize: 14,
                                fontWeight: isHighlighted
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
    );
  }
}

MatchAlliance? _allianceForColor(MatchSummary match, String colorName) {
  for (final alliance in match.alliances) {
    if (alliance.color.toLowerCase().contains(colorName)) {
      return alliance;
    }
  }

  if (match.alliances.isEmpty) {
    return null;
  }

  return colorName == 'red'
      ? match.alliances.first
      : match.alliances.length > 1
      ? match.alliances[1]
      : match.alliances.first;
}

String solarMatchScreenLabel(MatchSummary match) {
  switch (match.round) {
    case MatchRound.qualification:
      return 'Q${match.matchNumber > 0 ? match.matchNumber : match.instance}';
    case MatchRound.round128:
      return _eliminationLabel(
        prefix: 'R128',
        instance: match.instance,
        matchNumber: match.matchNumber,
      );
    case MatchRound.round64:
      return _eliminationLabel(
        prefix: 'R64',
        instance: match.instance,
        matchNumber: match.matchNumber,
      );
    case MatchRound.round32:
      return _eliminationLabel(
        prefix: 'R32',
        instance: match.instance,
        matchNumber: match.matchNumber,
      );
    case MatchRound.round16:
      return _eliminationLabel(
        prefix: 'R16',
        instance: match.instance,
        matchNumber: match.matchNumber,
      );
    case MatchRound.quarterfinals:
      return _eliminationLabel(
        prefix: 'QF',
        instance: match.instance,
        matchNumber: match.matchNumber,
      );
    case MatchRound.semifinals:
      return _eliminationLabel(
        prefix: 'SF',
        instance: match.instance,
        matchNumber: match.matchNumber,
      );
    case MatchRound.finals:
      return _eliminationLabel(
        prefix: 'F',
        instance: match.instance,
        matchNumber: match.matchNumber,
      );
    case MatchRound.practice:
      return 'P${match.matchNumber > 0 ? match.matchNumber : match.instance}';
    default:
      return match.name;
  }
}

String _eliminationLabel({
  required String prefix,
  required int instance,
  required int matchNumber,
}) {
  final series = instance > 0 ? '$instance' : '';
  final game = matchNumber > 0 ? '$matchNumber' : '';
  if (series.isNotEmpty && game.isNotEmpty) {
    return '$prefix$series-$game';
  }
  if (series.isNotEmpty) {
    return '$prefix$series';
  }
  if (game.isNotEmpty) {
    return '$prefix$game';
  }
  return prefix;
}

String solarMatchScoreLabel(
  MatchAlliance? redAlliance,
  MatchAlliance? blueAlliance,
) {
  final redScore = redAlliance?.score ?? -1;
  final blueScore = blueAlliance?.score ?? -1;
  final left = redScore >= 0 ? '$redScore' : '--';
  final right = blueScore >= 0 ? '$blueScore' : '--';
  return '$left - $right';
}

TextSpan solarMatchScoreText(
  MatchAlliance? redAlliance,
  MatchAlliance? blueAlliance,
) {
  final redScore = redAlliance?.score ?? -1;
  final blueScore = blueAlliance?.score ?? -1;
  final redWins = redScore >= 0 && blueScore >= 0 && redScore > blueScore;
  final blueWins = redScore >= 0 && blueScore >= 0 && blueScore > redScore;

  TextStyle scoreStyle(bool isWinner) {
    return TextStyle(
      color: Colors.black,
      fontSize: 20,
      fontWeight: isWinner ? FontWeight.w800 : FontWeight.w400,
      letterSpacing: -0.5,
    );
  }

  return TextSpan(
    children: <InlineSpan>[
      TextSpan(
        text: redScore >= 0 ? '$redScore' : '--',
        style: scoreStyle(redWins || (!redWins && !blueWins)),
      ),
      const TextSpan(
        text: ' - ',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
        ),
      ),
      TextSpan(
        text: blueScore >= 0 ? '$blueScore' : '--',
        style: scoreStyle(blueWins || (!redWins && !blueWins)),
      ),
    ],
  );
}

String solarMatchTimeLabel(MatchSummary match) {
  final date = (match.started ?? match.scheduled)?.toLocal();
  if (date == null) {
    return 'TBD';
  }

  final minutes = date.minute.toString().padLeft(2, '0');
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final suffix = date.hour >= 12 ? 'P' : 'A';
  return '$hour:$minutes$suffix';
}
