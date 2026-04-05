const int solarPrimaryProgramId = 1;
const List<int> solarPrimaryProgramIds = <int>[solarPrimaryProgramId];

const String solarPrimaryProgramFilter = 'V5RC';
const String solarPreferredSeasonName = 'Push Back';
const String solarizeLabel = 'Solarize';

bool isSolarPrimaryProgramText(String value) {
  final normalized = _normalizeCompetitionText(value);
  if (normalized.isEmpty) {
    return false;
  }

  const blockedSignals = <String>[
    'vex ai',
    'ai robotics competition',
    'vex u',
    'vex iq',
    'iq robotics competition',
    'air drone',
    'factory automation',
    'workshops & camps',
    'workshop',
    'camp',
  ];
  for (final signal in blockedSignals) {
    if (normalized.contains(signal)) {
      return false;
    }
  }

  return normalized == 'vrc' ||
      normalized.contains('v5rc') ||
      normalized.contains('vrc ') ||
      normalized.contains(' vrc') ||
      normalized.contains('vex v5 robotics competition') ||
      normalized.contains('v5 robotics competition') ||
      normalized.contains('vex robotics competition');
}

bool isSolarPreferredSeasonText(String value) {
  return _normalizeCompetitionText(value).contains('push back');
}

int compareSolarSeasonPriority({
  required String leftName,
  required int leftId,
  required String rightName,
  required int rightId,
}) {
  final preferredCompare = _seasonPriority(
    leftName,
  ).compareTo(_seasonPriority(rightName));
  if (preferredCompare != 0) {
    return preferredCompare;
  }
  return rightId.compareTo(leftId);
}

String _normalizeCompetitionText(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

int _seasonPriority(String name) {
  return isSolarPreferredSeasonText(name) ? 0 : 1;
}
