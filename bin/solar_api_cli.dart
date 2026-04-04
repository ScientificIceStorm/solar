import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:solar_v6/solar_v6.dart';

Future<void> main(List<String> arguments) async {
  final parser = _buildParser();
  ArgResults topLevelResults;

  try {
    topLevelResults = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln('');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (topLevelResults['help'] as bool || topLevelResults.command == null) {
    _printUsage(parser);
    return;
  }

  final command = topLevelResults.command!;
  if ((command['help'] as bool?) ?? false) {
    _printCommandUsage(parser, command.name ?? '');
    return;
  }

  final api = await SolarApi.fromLocalConfig();

  try {
    final output = await _runCommand(api, command);
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
  } on SolarApiException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Unable to read local file: $error');
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } finally {
    api.close();
  }
}

ArgParser _buildParser() {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message.',
    );

  _addHelp(parser.addCommand('config'));
  _addHelp(parser.addCommand('health'));

  final seasons = _addHelp(parser.addCommand('seasons'));
  seasons.addOption('program-id', help: 'Filter by RobotEvents program id.');

  final team = _addHelp(parser.addCommand('team'));
  team
    ..addOption('id', help: 'RobotEvents team id.')
    ..addOption('number', help: 'Team number, for example 24B.');

  final events = _addHelp(parser.addCommand('events'));
  events
    ..addOption('id', help: 'RobotEvents event id.')
    ..addOption('sku', help: 'Event SKU, for example RE-VRC-XX-XXXX.')
    ..addOption('season', help: 'Season id.')
    ..addOption('team-id', help: 'Filter events by team id.');

  final eventTeams = _addHelp(parser.addCommand('event-teams'));
  eventTeams.addOption('event-id', help: 'RobotEvents event id.');

  final divisionRankings = _addHelp(parser.addCommand('division-rankings'));
  divisionRankings
    ..addOption('event-id', help: 'RobotEvents event id.')
    ..addOption('division-id', help: 'RobotEvents division id.');

  final divisionMatches = _addHelp(parser.addCommand('division-matches'));
  divisionMatches
    ..addOption('event-id', help: 'RobotEvents event id.')
    ..addOption('division-id', help: 'RobotEvents division id.');

  final teamMatches = _addHelp(parser.addCommand('team-matches'));
  teamMatches
    ..addOption('team-id', help: 'RobotEvents team id.')
    ..addOption('season', help: 'Season id.')
    ..addOption('event-id', help: 'Event id.');

  final worldSkills = _addHelp(parser.addCommand('world-skills'));
  worldSkills
    ..addOption('season', help: 'Season id.', defaultsTo: '190')
    ..addOption(
      'grade-level',
      help: 'Grade level name.',
      defaultsTo: 'High School',
    );

  final siteData = _addHelp(parser.addCommand('site-data'));
  siteData
    ..addOption('season', help: 'Season id.', defaultsTo: '190')
    ..addOption(
      'grade-level',
      help: 'Grade level name.',
      defaultsTo: 'High School',
    );

  final openskillCache = _addHelp(parser.addCommand('openskill-cache'));
  openskillCache
    ..addOption('season', help: 'Season id.', defaultsTo: '190')
    ..addOption(
      'grade-level',
      help: 'Grade level name.',
      defaultsTo: 'High School',
    )
    ..addFlag(
      'force-refresh',
      negatable: false,
      help: 'Ask RoboServer to rebuild the cache.',
    );

  final openskillPredict = _addHelp(parser.addCommand('openskill-predict'));
  openskillPredict.addOption(
    'body-file',
    help: 'Path to a JSON request body.',
    defaultsTo: 'samples/openskill_predict_request.json',
  );

  final teamLoaderStart = _addHelp(parser.addCommand('team-loader-start'));
  teamLoaderStart
    ..addOption('season', help: 'Season id.', defaultsTo: '190')
    ..addOption(
      'grade-level',
      help: 'Grade level name.',
      defaultsTo: 'High School',
    )
    ..addFlag(
      'force-refresh',
      negatable: false,
      help: 'Rebuild team cache from scratch.',
    );

  final teamLoaderStatus = _addHelp(parser.addCommand('team-loader-status'));
  teamLoaderStatus
    ..addOption('season', help: 'Season id.', defaultsTo: '190')
    ..addOption(
      'grade-level',
      help: 'Grade level name.',
      defaultsTo: 'High School',
    );

  final rankingsLoaderStart = _addHelp(
    parser.addCommand('rankings-loader-start'),
  );
  rankingsLoaderStart
    ..addOption('season', help: 'Season id.', defaultsTo: '190')
    ..addOption(
      'grade-level',
      help: 'Grade level name.',
      defaultsTo: 'High School',
    )
    ..addFlag(
      'force-refresh',
      negatable: false,
      help: 'Rebuild rankings cache from scratch.',
    );

  final rankingsLoaderStatus = _addHelp(
    parser.addCommand('rankings-loader-status'),
  );
  rankingsLoaderStatus
    ..addOption('season', help: 'Season id.', defaultsTo: '190')
    ..addOption(
      'grade-level',
      help: 'Grade level name.',
      defaultsTo: 'High School',
    );

  return parser;
}

ArgParser _addHelp(ArgParser parser) {
  parser.addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Show command help.',
  );
  return parser;
}

Future<Object?> _runCommand(SolarApi api, ArgResults command) async {
  switch (command.name) {
    case 'config':
      return api.config.toSafeJson();
    case 'health':
      return <String, dynamic>{
        'config': api.config.toSafeJson(),
        'server': (await api.roboServer.health()).toJson(),
      };
    case 'seasons':
      return <String, dynamic>{
        'seasons': (await api.robotEvents.fetchSeasons(
          programId: _readIntOption(command, 'program-id'),
        )).map((season) => season.toJson()).toList(),
      };
    case 'team':
      final id = _readIntOption(command, 'id');
      final number = _readOptionalString(command, 'number');
      if (id == null && number == null) {
        throw const FormatException('Provide --id or --number.');
      }
      return <String, dynamic>{
        'teams': (await api.robotEvents.searchTeams(
          id: id,
          number: number,
        )).map((team) => team.toJson()).toList(),
      };
    case 'events':
      final id = _readIntOption(command, 'id');
      final sku = _readOptionalString(command, 'sku');
      final season = _readIntOption(command, 'season');
      final teamId = _readIntOption(command, 'team-id');
      if (id == null && sku == null && season == null && teamId == null) {
        throw const FormatException(
          'Provide at least one of --id, --sku, --season, or --team-id.',
        );
      }
      return <String, dynamic>{
        'events': (await api.robotEvents.fetchEvents(
          id: id,
          sku: sku,
          season: season,
          teamId: teamId,
        )).map((event) => event.toJson()).toList(),
      };
    case 'event-teams':
      return <String, dynamic>{
        'teams': (await api.robotEvents.fetchEventTeams(
          _readRequiredInt(command, 'event-id'),
        )).map((team) => team.toJson()).toList(),
      };
    case 'division-rankings':
      return <String, dynamic>{
        'rankings': (await api.robotEvents.fetchDivisionRankings(
          eventId: _readRequiredInt(command, 'event-id'),
          divisionId: _readRequiredInt(command, 'division-id'),
        )).map((entry) => entry.toJson()).toList(),
      };
    case 'division-matches':
      return <String, dynamic>{
        'matches': (await api.robotEvents.fetchDivisionMatches(
          eventId: _readRequiredInt(command, 'event-id'),
          divisionId: _readRequiredInt(command, 'division-id'),
        )).map((entry) => entry.toJson()).toList(),
      };
    case 'team-matches':
      return <String, dynamic>{
        'matches': (await api.robotEvents.fetchTeamMatches(
          _readRequiredInt(command, 'team-id'),
          season: _readIntOption(command, 'season'),
          eventId: _readIntOption(command, 'event-id'),
        )).map((entry) => entry.toJson()).toList(),
      };
    case 'world-skills':
      return <String, dynamic>{
        'entries': (await api.worldSkills.fetchRankings(
          seasonId: _readRequiredInt(command, 'season'),
          gradeLevel:
              _readOptionalString(command, 'grade-level') ?? 'High School',
        )).map((entry) => entry.toJson()).toList(),
      };
    case 'site-data':
      return (await api.roboServer.fetchSiteData(
        season: _readRequiredInt(command, 'season'),
        gradeLevel:
            _readOptionalString(command, 'grade-level') ?? 'High School',
      )).toJson();
    case 'openskill-cache':
      return <String, dynamic>{
        'rankings': (await api.roboServer.fetchOpenSkillCache(
          season: _readRequiredInt(command, 'season'),
          gradeLevel:
              _readOptionalString(command, 'grade-level') ?? 'High School',
          forceRefresh: command['force-refresh'] as bool,
        )).map((entry) => entry.toJson()).toList(),
      };
    case 'openskill-predict':
      final bodyPath =
          _readOptionalString(command, 'body-file') ??
          'samples/openskill_predict_request.json';
      final rawBody = await File(bodyPath).readAsString();
      final payload = OpenSkillPredictionRequest.fromJson(
        jsonDecode(rawBody) as Map<String, dynamic>,
      );
      return (await api.roboServer.predictOpenSkill(payload)).toJson();
    case 'team-loader-start':
      return (await api.roboServer.startTeamLoader(
        season: _readRequiredInt(command, 'season'),
        gradeLevel:
            _readOptionalString(command, 'grade-level') ?? 'High School',
        forceRefresh: command['force-refresh'] as bool,
      )).toJson();
    case 'team-loader-status':
      return (await api.roboServer.fetchTeamLoaderStatus(
        season: _readRequiredInt(command, 'season'),
        gradeLevel:
            _readOptionalString(command, 'grade-level') ?? 'High School',
      )).toJson();
    case 'rankings-loader-start':
      return (await api.roboServer.startRankingsLoader(
        season: _readRequiredInt(command, 'season'),
        gradeLevel:
            _readOptionalString(command, 'grade-level') ?? 'High School',
        forceRefresh: command['force-refresh'] as bool,
      )).toJson();
    case 'rankings-loader-status':
      return (await api.roboServer.fetchRankingsLoaderStatus(
        season: _readRequiredInt(command, 'season'),
        gradeLevel:
            _readOptionalString(command, 'grade-level') ?? 'High School',
      )).toJson();
    default:
      throw FormatException('Unknown command: ${command.name}');
  }
}

int _readRequiredInt(ArgResults results, String optionName) {
  final value = _readIntOption(results, optionName);
  if (value == null) {
    throw FormatException('Missing required option --$optionName.');
  }
  return value;
}

int? _readIntOption(ArgResults results, String optionName) {
  final raw = results[optionName] as String?;
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final value = int.tryParse(raw);
  if (value == null) {
    throw FormatException('Option --$optionName must be an integer.');
  }
  return value;
}

String? _readOptionalString(ArgResults results, String optionName) {
  final raw = results[optionName] as String?;
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return raw.trim();
}

void _printUsage(ArgParser parser) {
  stdout.writeln('Usage: dart run bin/solar_api_cli.dart <command> [options]');
  stdout.writeln('');
  stdout.writeln(parser.usage);
}

void _printCommandUsage(ArgParser parser, String commandName) {
  final command = parser.commands[commandName];
  if (command == null) {
    _printUsage(parser);
    return;
  }

  stdout.writeln(
    'Usage: dart run bin/solar_api_cli.dart $commandName [options]',
  );
  stdout.writeln('');
  stdout.writeln(command.usage);
}
