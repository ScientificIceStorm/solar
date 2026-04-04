import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../pages/team_profile_screen.dart';

Future<void> openSolarTeamProfileForSummary(
  BuildContext context,
  TeamSummary team,
) {
  return Navigator.of(
    context,
  ).pushNamed(TeamProfileScreen.routeName, arguments: team);
}

Future<void> openSolarTeamProfileForReference(
  BuildContext context, {
  required String teamNumber,
  int? teamId,
  String teamName = '',
  String organization = '',
  String robotName = '',
  String? grade,
}) {
  final controller = SolarAppScope.of(context);
  final resolvedTeam = controller.resolveKnownTeamSummary(
    teamNumber: teamNumber,
    teamId: teamId,
    teamName: teamName,
    organization: organization,
    robotName: robotName,
    grade: grade,
  );
  return openSolarTeamProfileForSummary(context, resolvedTeam);
}

class SolarTeamLinkText extends StatelessWidget {
  const SolarTeamLinkText({
    required this.teamNumber,
    super.key,
    this.teamId,
    this.teamName = '',
    this.organization = '',
    this.robotName = '',
    this.grade,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.padding = EdgeInsets.zero,
  });

  final String teamNumber;
  final int? teamId;
  final String teamName;
  final String organization;
  final String robotName;
  final String? grade;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final TextOverflow overflow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        openSolarTeamProfileForReference(
          context,
          teamNumber: teamNumber,
          teamId: teamId,
          teamName: teamName,
          organization: organization,
          robotName: robotName,
          grade: grade,
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: padding,
        child: Text(
          teamNumber,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          style: style,
        ),
      ),
    );
  }
}
