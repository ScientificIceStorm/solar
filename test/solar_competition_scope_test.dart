import 'package:flutter_test/flutter_test.dart';
import 'package:solar_v6/src/core/solar_competition_scope.dart';

void main() {
  test('V5 program matcher excludes AI and VEX U labels', () {
    expect(isSolarPrimaryProgramText('VEX V5 Robotics Competition'), isTrue);
    expect(isSolarPrimaryProgramText('V5RC'), isTrue);
    expect(isSolarPrimaryProgramText('VRC 2023-2024: Over Under'), isTrue);

    expect(isSolarPrimaryProgramText('VEX AI Robotics Competition'), isFalse);
    expect(isSolarPrimaryProgramText('VEX U Robotics Competition'), isFalse);
    expect(isSolarPrimaryProgramText('VEX IQ Robotics Competition'), isFalse);
  });

  test('Push Back seasons stay ahead of other V5 seasons', () {
    final comparison = compareSolarSeasonPriority(
      leftName: 'VEX V5 Robotics Competition 2025-2026: Push Back',
      leftId: 197,
      rightName: 'VEX V5 Robotics Competition 2026-2027: New Game',
      rightId: 205,
    );

    expect(comparison, lessThan(0));
  });
}
