import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SolarDiskCacheStore {
  SolarDiskCacheStore._();

  static final SolarDiskCacheStore instance = SolarDiskCacheStore._();

  Future<List<T>?> readList<T>({
    required String namespace,
    required String key,
    required T Function(Map<String, dynamic> json) fromJson,
    bool allowExpired = false,
  }) async {
    final envelope = await _readEnvelope(namespace: namespace, key: key);
    if (envelope == null) {
      return null;
    }

    final expiresAt = envelope.expiresAt;
    if (!allowExpired && expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      return null;
    }

    final items = envelope.payload['items'];
    if (items is! List) {
      return null;
    }

    return items
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> writeList<T>({
    required String namespace,
    required String key,
    required List<T> items,
    required Map<String, dynamic> Function(T item) toJson,
    Duration? ttl,
  }) async {
    final envelope = _SolarCacheEnvelope(
      storedAt: DateTime.now(),
      expiresAt: ttl == null ? null : DateTime.now().add(ttl),
      payload: <String, dynamic>{
        'items': items.map<Map<String, dynamic>>(toJson).toList(growable: false),
      },
    );
    await _writeEnvelope(namespace: namespace, key: key, envelope: envelope);
  }

  Future<void> clear(String namespace, String key) async {
    final file = await _fileFor(namespace: namespace, key: key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<_SolarCacheEnvelope?> _readEnvelope({
    required String namespace,
    required String key,
  }) async {
    try {
      final file = await _fileFor(namespace: namespace, key: key);
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      final json = jsonDecode(raw);
      if (json is! Map) {
        return null;
      }
      return _SolarCacheEnvelope.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeEnvelope({
    required String namespace,
    required String key,
    required _SolarCacheEnvelope envelope,
  }) async {
    try {
      final file = await _fileFor(namespace: namespace, key: key);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(envelope.toJson()), flush: true);
    } catch (_) {
      // Keep the app responsive if local cache writes fail.
    }
  }

  Future<File> _fileFor({
    required String namespace,
    required String key,
  }) async {
    final directory = await _cacheDirectory();
    final safeNamespace = _sanitize(namespace);
    final safeKey = _sanitize(key);
    return File('${directory.path}\\$safeNamespace\\$safeKey.json');
  }

  Future<Directory> _cacheDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}\\solar_cache');
  }

  String _sanitize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

class _SolarCacheEnvelope {
  const _SolarCacheEnvelope({
    required this.storedAt,
    required this.expiresAt,
    required this.payload,
  });

  final DateTime storedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> payload;

  factory _SolarCacheEnvelope.fromJson(Map<String, dynamic> json) {
    return _SolarCacheEnvelope(
      storedAt:
          DateTime.tryParse((json['storedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: DateTime.tryParse((json['expiresAt'] as String?) ?? ''),
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map<Object?, Object?>?) ?? const <Object?, Object?>{},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'storedAt': storedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'payload': payload,
    };
  }
}
