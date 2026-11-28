import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'query_encoder.dart';

class JsonApiClient {
  JsonApiClient(
    this._client, {
    this.requestTimeout = const Duration(seconds: 12),
    this.requestSpacing = const Duration(milliseconds: 1100),
    this.retryDelay = const Duration(milliseconds: 400),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final http.Client _client;
  final Duration requestTimeout;
  final Duration requestSpacing;
  final Duration retryDelay;
  final DateTime Function() _now;
  final Map<String, Future<dynamic>> _pending = {};
  final Map<String, Future<void>> _queues = {};
  final Map<String, DateTime> _nextRequestAt = {};
  final Map<String, DateTime> _blockedUntil = {};
  bool _closed = false;

  bool get isRateLimited =>
      _blockedUntil.values.any((time) => time.isAfter(_now()));

  void close() {
    _closed = true;
    _client.close();
  }

  Future<dynamic> getJson({
    required String baseUrl,
    required String path,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
  }) {
    final uri = QueryEncoder.buildUri(baseUrl, path, query);
    // Include credentials in the private deduplication key; never log it.
    final sortedHeaders = headers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final key = '$uri|${jsonEncode(Map.fromEntries(sortedHeaders))}';
    return _pending.putIfAbsent(key, () async {
      try {
        for (var attempt = 0; ; attempt++) {
          try {
            return await _scheduled(uri, () async {
              final response = await _client
                  .get(uri, headers: {'Accept': 'application/json', ...headers})
                  .timeout(requestTimeout);
              return _decodeResponse(response, uri);
            });
          } on SolarApiException catch (error) {
            final transient =
                error.statusCode == null ||
                const [502, 503, 504].contains(error.statusCode);
            if (!transient || attempt >= 1 || _closed) rethrow;
            await Future<void>.delayed(retryDelay);
          }
        }
      } finally {
        _pending.remove(key);
      }
    });
  }

  Future<dynamic> postJson({
    required String baseUrl,
    required String path,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) {
    final uri = QueryEncoder.buildUri(baseUrl, path, query);
    // Never automatically retry writes.
    return _scheduled(uri, () async {
      final response = await _client
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              ...headers,
            },
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);
      return _decodeResponse(response, uri);
    });
  }

  Future<dynamic> _scheduled(Uri uri, Future<dynamic> Function() send) async {
    final host = uri.authority;
    final previous = _queues[host] ?? Future<void>.value();
    final release = Completer<void>();
    _queues[host] = release.future;
    try {
      await previous;
      _checkAvailable(uri);
      final next = _nextRequestAt[host];
      if (next != null && next.isAfter(_now())) {
        await Future<void>.delayed(next.difference(_now()));
      }
      _checkAvailable(uri);
      _nextRequestAt[host] = _now().add(requestSpacing);
      return await send();
    } on SolarApiException {
      rethrow; // Preserve HTTP status, especially 401 and 429.
    } on Exception catch (error) {
      throw SolarApiException(
        'Network request failed',
        uri: uri,
        details: error,
      );
    } finally {
      release.complete();
      if (identical(_queues[host], release.future)) _queues.remove(host);
    }
  }

  void _checkAvailable(Uri uri) {
    if (_closed) throw SolarApiException('Connection closed', uri: uri);
    final until = _blockedUntil[uri.authority];
    if (until != null && until.isAfter(_now())) {
      throw SolarApiException(
        'VEX Events request limit reached',
        statusCode: 429,
        uri: uri,
        retryAfter: until.difference(_now()),
      );
    }
  }

  dynamic _decodeResponse(http.Response response, Uri uri) {
    if (response.statusCode == 429) {
      var seconds = int.tryParse(response.headers['retry-after'] ?? '');
      if (seconds == null) {
        try {
          seconds = HttpDate.parse(
            response.headers['retry-after'] ?? '',
          ).difference(_now()).inSeconds;
        } catch (_) {
          try {
            final data = jsonDecode(response.body);
            if (data is Map) seconds = int.tryParse('${data['retry_after']}');
          } catch (_) {
            /* Non-JSON rate-limit responses are valid too. */
          }
        }
      }
      final delay = Duration(seconds: (seconds ?? 30) < 1 ? 1 : seconds ?? 30);
      _blockedUntil[uri.authority] = _now().add(delay);
      throw SolarApiException(
        'VEX Events request limit reached',
        statusCode: 429,
        uri: uri,
        retryAfter: delay,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SolarApiException(
        'Request failed',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    final body = response.body.trim();
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      throw SolarApiException(
        'Response was not valid JSON',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }
}
