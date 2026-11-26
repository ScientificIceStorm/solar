import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:solar_v6/solar_v6.dart';

const _jumper = 'jumper.robostem.org';
final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');
final _vimeoId = RegExp(r'^\d{6,14}$');
final _vimeoHash = RegExp(r'^[a-f0-9]{6,20}$');

typedef _Stream = ({
  String id,
  String provider,
  String? hash,
  DateTime anchor,
  int seconds,
  DateTime? end,
});

const _youtubeHosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'youtu.be',
  'www.youtube-nocookie.com',
};

String? _videoId(Uri link) {
  if (!_youtubeHosts.contains(link.host)) return null;
  final path = link.pathSegments;
  final id = link.host == 'youtu.be'
      ? path.firstOrNull
      : switch (path.firstOrNull) {
          'watch' => link.queryParameters['v'],
          'live' || 'embed' => path.elementAtOrNull(1),
          _ => null,
        };
  return id != null && _youtubeId.hasMatch(id) ? id : null;
}

/// YouTube refuses page reads from datacenter hosts such as Railway's, so on
/// the server a channel's stream list is read through the site's worker (see
/// `youtubeRelay` in site/_worker.js), falling back to a direct read. Watch
/// pages are refused there too: broadcast timing on the server needs
/// YOUTUBE_API_KEY (see [_youtubeStream]).
final _youtubeRelay =
    Platform.environment['SOLAR_YOUTUBE_RELAY'] ??
    (Platform.environment['RAILWAY_ENVIRONMENT'] != null ||
            Platform.environment['RAILWAY_ENVIRONMENT_NAME'] != null
        ? 'https://solarscout-enz.pages.dev/api/youtube-relay'
        : null);

Future<String?> _youtubePage(
  http.Client client,
  Uri page, {
  bool relayed = false,
}) async {
  final token = Platform.environment['SOLAR_ORIGIN_TOKEN']?.trim() ?? '';
  final relay = Uri.tryParse(_youtubeRelay ?? '');
  if (relayed && relay != null && relay.hasAuthority && token.isNotEmpty) {
    try {
      final response = await client
          .get(
            relay.replace(queryParameters: {'url': page.toString()}),
            headers: {'X-Solar-Origin-Token': token},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.body.contains('ytInitial')) {
        return response.body;
      }
    } on Exception {
      // Try reading the page directly.
    }
  }
  try {
    final response = await client
        .get(page, headers: const {'Accept-Language': 'en-US,en;q=0.9'})
        .timeout(const Duration(seconds: 6));
    return response.statusCode == 200 ? response.body : null;
  } on Exception {
    return null;
  }
}

/// A channel's recent uploads (live streams included) through the YouTube
/// Data API, when the server has a key.
Future<List<String>?> _channelVideosFromApi(
  http.Client client,
  List<String> channel,
) async {
  final key = Platform.environment['YOUTUBE_API_KEY'];
  if (key == null || key.isEmpty) return null;
  final filter = switch (channel) {
    [final handle] when handle.startsWith('@') => {'forHandle': handle},
    ['channel', final id] => {'id': id},
    ['user', final name] => {'forUsername': name},
    _ => null,
  };
  if (filter == null) return null;
  try {
    final channels = await _json(
      client,
      Uri.https('www.googleapis.com', '/youtube/v3/channels', {
        ...filter,
        'part': 'contentDetails',
        'key': key,
      }),
    );
    final item = channels is Map ? _maps(channels['items']).firstOrNull : null;
    final details = item?['contentDetails'];
    final playlists = details is Map ? details['relatedPlaylists'] : null;
    final uploads = playlists is Map ? playlists['uploads'] : null;
    if (uploads is! String) return null;
    final items = await _json(
      client,
      Uri.https('www.googleapis.com', '/youtube/v3/playlistItems', {
        'playlistId': uploads,
        'part': 'contentDetails',
        'maxResults': '15',
        'key': key,
      }),
    );
    if (items is! Map) return null;
    return _maps(items['items'])
        .map((item) => item['contentDetails']?['videoId'])
        .whereType<String>()
        .where(_youtubeId.hasMatch)
        .toList();
  } on Exception {
    return null;
  }
}

Future<List<String>> _channelVideos(http.Client client, Uri link) async {
  if (!_youtubeHosts.contains(link.host)) return [];
  final parts = link.pathSegments;
  if (parts.isEmpty) return [];
  final channel = parts.first.startsWith('@')
      ? parts.take(1).toList()
      : const {'channel', 'c', 'user'}.contains(parts.first) &&
            parts.length >= 2
      ? parts.take(2).toList()
      : <String>[];
  if (channel.isEmpty) return [];
  final fromApi = await _channelVideosFromApi(client, channel);
  if (fromApi != null && fromApi.isNotEmpty) return fromApi.take(10).toList();
  try {
    final body = await _youtubePage(
      client,
      Uri(
        scheme: 'https',
        host: 'www.youtube.com',
        pathSegments: [...channel, 'streams'],
      ),
      relayed: true,
    );
    if (body == null) return [];
    final data = body.replaceAllMapped(
      RegExp(r'\\x([a-fA-F0-9]{2})'),
      (match) => String.fromCharCode(int.parse(match[1]!, radix: 16)),
    );
    return RegExp(
      r'"(?:videoId|contentId)"\s*:\s*"([A-Za-z0-9_-]{11})"',
    ).allMatches(data).map((match) => match[1]!).toSet().take(10).toList();
  } on Exception {
    return [];
  }
}

Future<_Stream?> _youtubeStream(http.Client client, String id) async {
  try {
    final key = Platform.environment['YOUTUBE_API_KEY'];
    if (key != null && key.isNotEmpty) {
      try {
        final data = await _json(
          client,
          Uri.https('www.googleapis.com', '/youtube/v3/videos', {
            'id': id,
            'part': 'liveStreamingDetails,status',
            'key': key,
          }),
        );
        final item = data is Map ? _maps(data['items']).firstOrNull : null;
        final timing = item?['liveStreamingDetails'];
        if (timing is Map) {
          if (item?['status'] case {'embeddable': false}) return null;
          final start = DateTime.tryParse('${timing['actualStartTime'] ?? ''}');
          final end = DateTime.tryParse('${timing['actualEndTime'] ?? ''}');
          if (start != null) {
            return (
              id: id,
              provider: 'youtube',
              hash: null,
              anchor: start,
              seconds: 0,
              end: end,
            );
          }
        }
      } on Exception {
        // Continue with the public player metadata.
      }
    }
    final body = await _youtubePage(
      client,
      Uri.https('www.youtube.com', '/watch', {'v': id}),
    );
    if (body == null) return null;
    final details = RegExp(
      r'"liveBroadcastDetails"\s*:\s*(\{[^}]+\})',
    ).firstMatch(body)?.group(1);
    if (details == null) return null;
    final timing = jsonDecode(details) as Map<String, dynamic>;
    final start = DateTime.tryParse(timing['startTimestamp']?.toString() ?? '');
    final end = DateTime.tryParse(timing['endTimestamp']?.toString() ?? '');
    if (start == null || (end == null && timing['isLiveNow'] != true)) {
      return null;
    }
    return (
      id: id,
      provider: 'youtube',
      hash: null,
      anchor: start,
      seconds: 0,
      end: end,
    );
  } on Exception {
    return null;
  }
}

/// Keeps only webcast links that can belong to an event held between [start]
/// and [end]. Organizer pages often still list last season's streams, and
/// scraped links sometimes run into neighbouring text ("…_oHosted"); a YouTube
/// broadcast that ended well before the event or began well after it is
/// dropped, as is a YouTube link without a valid video id. Links whose timing
/// cannot be read (uploads, other providers, lookups that fail) are kept.
Future<List<String>> solarWebcastsDuring(
  List<String> links,
  DateTime? start,
  DateTime? end,
) async {
  if (links.isEmpty) return links;
  final client = http.Client();
  try {
    final kept = await Future.wait(
      links.map((link) async {
        final uri = Uri.tryParse(link);
        if (uri == null) return null;
        if (!_youtubeHosts.contains(uri.host)) return link;
        final id = _videoId(uri);
        if (id == null) {
          // A channel or playlist page is fine; a mangled video link is not.
          final segment = uri.pathSegments.firstOrNull;
          return const {'watch', 'live', 'embed'}.contains(segment) ||
                  uri.host == 'youtu.be'
              ? null
              : link;
        }
        if (start == null) return link;
        final stream = await _youtubeStream(client, id);
        if (stream == null) return link;
        const slack = Duration(hours: 36);
        final from = start.subtract(slack);
        final until = (end ?? start).add(slack);
        final streamEnd = stream.end ?? DateTime.now();
        return streamEnd.isBefore(from) || stream.anchor.isAfter(until)
            ? null
            : link;
      }),
    );
    return kept.whereType<String>().toList();
  } finally {
    client.close();
  }
}

Future<dynamic> _json(http.Client client, Uri uri) async {
  final response = await client.get(uri).timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) return null;
  return jsonDecode(response.body);
}

List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : [];

Future<Map<String, Object?>> solarMatchStreams(
  EventSummary event,
  DivisionSummary division,
  Iterable<MatchSummary> matches,
  Future<List<String>> Function() officialWebcasts,
) async {
  if (!matches.any((match) => match.started != null)) return {};
  final client = http.Client();
  try {
    final starts = {for (final match in matches) match.id: match.started};
    List<Map<String, dynamic>> presets = [];
    try {
      presets = _maps(
        await _json(client, Uri.https(_jumper, '/api/get-all-routes')),
      );
    } on Exception {
      // The event's official stream can still be used.
    }
    final preset = presets
        .where((item) => item['sku'] == event.sku)
        .firstOrNull;
    final streams = <_Stream>[];
    final vimeo = preset?['vimeo'];
    if (vimeo is Map && event.divisions.length == 1) {
      for (final day in _maps(vimeo['days'])) {
        final id = day['videoId'].toString();
        final hash = day['hash']?.toString();
        final anchorId = int.tryParse(day['anchorMatchId'].toString());
        final anchor =
            starts[anchorId] ??
            DateTime.tryParse(day['anchorStartedAt']?.toString() ?? '');
        final seconds = day['anchorSeconds'];
        if (_vimeoId.hasMatch(id) &&
            (hash == null || _vimeoHash.hasMatch(hash)) &&
            anchor != null &&
            seconds is int &&
            seconds >= 0) {
          streams.add((
            id: id,
            provider: 'vimeo',
            hash: hash,
            anchor: anchor,
            seconds: seconds,
            end: null,
          ));
        }
      }
    }

    final ids = <String>{};
    final presetStreams = preset?['streams'];
    if (presetStreams is List && event.divisions.length == 1) {
      ids.addAll(presetStreams.whereType<String>().where(_youtubeId.hasMatch));
    } else if (presetStreams is Map) {
      final divisionStreams = presetStreams['${division.id}'];
      if (divisionStreams is List) {
        ids.addAll(
          divisionStreams.whereType<String>().where(_youtubeId.hasMatch),
        );
      }
    }

    final channelIds = <String>{};
    if (streams.isEmpty && ids.isEmpty) {
      final apiLink = Uri.tryParse(event.livestreamLink);
      final singleDivision = event.divisions.length == 1;
      final apiId = apiLink == null || !singleDivision
          ? null
          : _videoId(apiLink);
      if (apiId != null) ids.add(apiId);
      if (ids.isEmpty && singleDivision) {
        final links = {
          if (apiLink != null && apiLink.hasAuthority) apiLink,
          ...(await officialWebcasts()).map(Uri.tryParse).whereType<Uri>(),
        };
        for (final link in links.take(3)) {
          final id = _videoId(link);
          if (id != null) {
            ids.add(id);
          } else {
            channelIds.addAll(await _channelVideos(client, link));
          }
        }
      }
      if (ids.isEmpty &&
          channelIds.isEmpty &&
          event.start != null &&
          event.end != null) {
        try {
          final detected = await _json(
            client,
            Uri.https(_jumper, '/api/detect-streams', {
              'sku': event.sku,
              'eventStart': event.start!.toIso8601String(),
              'eventEnd': event.end!.toIso8601String(),
              'divisions': jsonEncode([division.toJson()]),
            }),
          );
          if (detected is Map) {
            ids.addAll(
              _maps(detected['streams'])
                  .map((row) => row['videoId'])
                  .whereType<String>()
                  .where(_youtubeId.hasMatch),
            );
          }
        } on Exception {
          // No verified stream is available for this event.
        }
      }
    }

    streams.addAll(
      (await Future.wait(
        ids.take(6).map((id) => _youtubeStream(client, id)),
      )).whereType<_Stream>(),
    );
    final channelStreams = (await Future.wait(
      channelIds
          .difference(ids)
          .take(10)
          .map((id) => _youtubeStream(client, id)),
    )).whereType<_Stream>();

    streams.sort((a, b) => b.anchor.compareTo(a.anchor));
    final result = <String, Object?>{};
    for (final match in matches) {
      final started = match.started;
      if (started == null) continue;
      final matchingChannelStreams = channelStreams
          .where(
            (stream) =>
                !started.isBefore(stream.anchor) &&
                !started.isAfter(stream.end ?? DateTime.now()),
          )
          .toList();
      for (final stream in [
        ...streams,
        if (matchingChannelStreams.length == 1) matchingChannelStreams.single,
      ]) {
        final offset =
            started.difference(stream.anchor).inSeconds + stream.seconds;
        if (offset < 0 ||
            (stream.end == null && offset > 12 * 3600) ||
            (stream.end != null && started.isAfter(stream.end!))) {
          continue;
        }
        final seek = offset;
        final uri = stream.provider == 'vimeo'
            ? Uri.https('player.vimeo.com', '/video/${stream.id}', {
                if (stream.hash != null) 'h': stream.hash!,
                'autoplay': '1',
              }).replace(fragment: 't=${seek}s')
            : Uri.https('www.youtube-nocookie.com', '/embed/${stream.id}', {
                'start': '$seek',
                'autoplay': '1',
              });
        result['${match.id}'] = uri.toString();
        break;
      }
    }
    return result;
  } finally {
    client.close();
  }
}
