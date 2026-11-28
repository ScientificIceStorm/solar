import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_v6/src/core/api_exception.dart';
import 'package:solar_v6/src/core/json_api_client.dart';

void main() {
  JsonApiClient client(http.Client transport, {DateTime Function()? now, Duration timeout = const Duration(seconds: 1)}) => JsonApiClient(transport, requestSpacing: Duration.zero, retryDelay: Duration.zero, requestTimeout: timeout, now: now);
  Future<dynamic> get(JsonApiClient api, [String path = '/seasons']) => api.getJson(baseUrl: 'https://events.vex.com/api/v2', path: path);

  test('50 simultaneous identical reads use one request', () async {
    var count = 0;
    final api = client(MockClient((_) async {
      count++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return http.Response('{"data":[]}', 200);
    }));
    await Future.wait(List.generate(50, (_) => get(api)));
    expect(count, 1);
    api.close();
  });

  test('rate limit preserves status and blocks all queued routes until cooldown', () async {
    var now = DateTime(2026);
    var count = 0;
    final api = client(MockClient((_) async {
      count++;
      return count == 1 ? http.Response('{"retry_after":30}', 429) : http.Response('{"ok":true}', 200);
    }), now: () => now);
    final errors = await Future.wait(List.generate(30, (i) async {
      try { await get(api, '/route$i'); return null; } catch (e) { return e; }
    }));
    expect(count, 1);
    expect(errors, everyElement(isA<SolarApiException>().having((e) => e.statusCode, 'status', 429)));
    now = now.add(const Duration(seconds: 31));
    expect(await get(api), {'ok': true});
    expect(count, 2);
    api.close();
  });

  test('temporary server failure retries once and succeeds', () async {
    var count = 0;
    final api = client(MockClient((_) async => http.Response(++count == 1 ? '{}' : '{"ok":true}', count == 1 ? 503 : 200)));
    expect(await get(api), {'ok': true});
    expect(count, 2);
    api.close();
  });

  test('unauthorized and malformed responses are not retried or wrapped', () async {
    for (final status in [401, 403, 200]) {
      var count = 0;
      final api = client(MockClient((_) async { count++; return http.Response('not json', status); }));
      await expectLater(get(api), throwsA(isA<SolarApiException>().having((e) => e.statusCode, 'status', status)));
      expect(count, 1);
      api.close();
    }
  });

  test('hung requests time out after a bounded retry and can recover', () async {
    var count = 0;
    var offline = true;
    final api = client(MockClient((_) async {
      count++;
      if (offline) await Completer<void>().future;
      return http.Response(jsonEncode({'ok': true}), 200);
    }), timeout: const Duration(milliseconds: 10));
    await expectLater(get(api), throwsA(isA<SolarApiException>()));
    expect(count, 2);
    offline = false;
    expect(await get(api), {'ok': true});
    api.close();
  });

  test('writes are never automatically retried', () async {
    var count = 0;
    final api = client(MockClient((_) async { count++; return http.Response('{}', 503); }));
    await expectLater(api.postJson(baseUrl: 'https://events.vex.com', path: '/test'), throwsA(isA<SolarApiException>()));
    expect(count, 1);
    api.close();
  });
}
