// Finds each match's moment in its event's livestream ahead of time, for
// deploy/seed.
//
// A match's replay link is its stream's video at (match start - broadcast
// start), the alignment Live-viewer (jumper.robostem.org) uses. YouTube
// refuses to show broadcast start times to datacenter hosts such as Railway,
// so the API server can't do this itself without YOUTUBE_API_KEY. This script
// runs the server's own matching (bin/solar_streams.dart) locally for every
// division with matches in deploy/seed and writes
// match-videos-<event>-<division>.json, which the deployed server serves for
// finished events.
//
// It makes no RobotEvents API calls: matches come from the seed and events
// from a saved /api/events?seasonId=<season> response. Webcast lists come
// from a local server cache when there is one, else from the event's page.
//
//   dart run deploy/build_match_videos.dart --events events.json
//       [--seed deploy/seed] [--cache .solar_rankings_cache/companion]
//       [--state progress.json] [--only SKU,SKU]
//
// A division that finds nothing keeps the file it already has.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:solar_v6/solar_v6.dart';

import '../bin/solar_event_information.dart';
import '../bin/solar_streams.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('events', mandatory: true)
    ..addOption('seed', defaultsTo: 'deploy/seed')
    ..addOption('cache', defaultsTo: '.solar_rankings_cache/companion')
    ..addOption('state')
    ..addOption('only')
    ..addOption('workers', defaultsTo: '3');
  final options = parser.parse(arguments);

  final events = {
    for (final row in (jsonDecode(
      await File(options['events'] as String).readAsString(),
    ) as List).cast<Map<String, dynamic>>())
      row['id'] as int: EventSummary.fromJson(row),
  };
  final seed = options['seed'] as String;
  final cache = options['cache'] as String;
  final statePath = options['state'] as String?;
  final done = <String>{
    if (statePath != null && File(statePath).existsSync())
      ...(jsonDecode(File(statePath).readAsStringSync()) as List).cast<String>(),
  };
  final only = (options['only'] as String?)?.split(',').toSet();

  final pattern = RegExp(r'rated-matches-(\d+)-(\d+)\.json$');
  final now = DateTime.now();
  final todo = <(EventSummary, DivisionSummary, File)>[];
  for (final file in Directory(seed).listSync().whereType<File>()) {
    final found = pattern.firstMatch(file.path);
    final event = found == null ? null : events[int.parse(found[1]!)];
    if (event == null || !(event.start?.isBefore(now) ?? false)) continue;
    if (only != null && !only.contains(event.sku)) continue;
    final divisionId = int.parse(found![2]!);
    if (done.contains('${event.id}-$divisionId')) continue;
    final division =
        event.divisions.where((item) => item.id == divisionId).firstOrNull ??
        DivisionSummary(id: divisionId, name: 'Division $divisionId');
    todo.add((event, division, file));
  }
  todo.sort((a, b) => a.$1.id.compareTo(b.$1.id));
  stdout.writeln('${todo.length} divisions to look up');

  Future<List<String>> webcasts(EventSummary event) async {
    try {
      final saved = jsonDecode(
        await File('$cache/event-information-v4-${event.sku}.json')
            .readAsString(),
      );
      if (saved is Map && saved['webcasts'] is List) {
        return (saved['webcasts'] as List).whereType<String>().toList();
      }
    } on Exception {
      // Not cached: read the event's page.
    }
    final information = await solarEventInformation(event.sku);
    await Future<void>.delayed(const Duration(seconds: 2));
    return solarWebcastsDuring(
      (information['webcasts'] as List? ?? []).whereType<String>().toList(),
      event.start,
      event.end,
    );
  }

  var next = 0, checked = 0, found = 0, linked = 0, failed = 0;
  Future<void> worker() async {
    while (next < todo.length) {
      final (event, division, file) = todo[next++];
      final label = '${event.sku} d${division.id}';
      try {
        final matches =
            ((jsonDecode(await file.readAsString()) as Map)['matches'] as List)
                .cast<Map<String, dynamic>>()
                .map(MatchSummary.fromJson)
                .toList();
        final rows = await solarMatchStreams(
          event,
          division,
          matches,
          () => webcasts(event),
        );
        checked++;
        if (rows.isNotEmpty) {
          found++;
          linked += rows.length;
          await File('$seed/match-videos-${event.id}-${division.id}.json')
              .writeAsString(jsonEncode({'rows': rows}));
          stdout.writeln('[$checked/${todo.length}] $label ${rows.length} '
              'matches  ${event.name.substring(0, event.name.length.clamp(0, 60))}');
        } else {
          stdout.writeln('[$checked/${todo.length}] $label no stream found');
        }
        done.add('${event.id}-${division.id}');
        if (statePath != null) {
          await File(statePath).writeAsString(jsonEncode(done.toList()..sort()));
        }
      } on Exception catch (error) {
        checked++;
        failed++;
        stdout.writeln('[$checked/${todo.length}] $label failed: $error');
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < int.parse(options['workers'] as String); i++) worker(),
  ]);
  final total = Directory(seed)
      .listSync()
      .map((entry) => RegExp(r'match-videos-(\d+)-').firstMatch(entry.path)?[1])
      .whereType<String>()
      .toSet()
      .length;
  stdout.writeln('done: $found divisions with match videos this run '
      '($linked matches), $failed failed; $total events with match videos '
      'in $seed');
  exit(failed == 0 ? 0 : 1);
}
