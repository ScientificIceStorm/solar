typedef JsonMap = Map<String, dynamic>;

JsonMap asJsonMap(Object? value) {
  if (value is JsonMap) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<JsonMap> asJsonMapList(Object? value) {
  if (value is! List) {
    return const <JsonMap>[];
  }
  return value.whereType<Map>().map(asJsonMap).toList(growable: false);
}

String readString(Object? value, [String fallback = '']) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

int readInt(Object? value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

double readDouble(Object? value, [double fallback = 0]) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool readBool(Object? value, [bool fallback = false]) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return fallback;
}

DateTime? readDateTime(Object? value) {
  final text = readString(value).trim();
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

List<String> readStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => readString(entry).trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

String firstNonEmpty(Iterable<String?> values, {String fallback = ''}) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return fallback;
}
