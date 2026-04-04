class QueryEncoder {
  static Uri buildUri(
    String baseUrl,
    String path, [
    Map<String, Object?> query = const {},
  ]) {
    final base = Uri.parse(baseUrl);
    final resolvedPath = _joinPaths(base.path, path);
    final queryParts = <String>[];

    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }

      if (value is Iterable && value is! String) {
        var index = 0;
        for (final nestedValue in value) {
          if (nestedValue == null) {
            continue;
          }
          queryParts.add(
            '${Uri.encodeQueryComponent('${entry.key}[$index]')}='
            '${Uri.encodeQueryComponent(_scalarToString(nestedValue))}',
          );
          index += 1;
        }
        continue;
      }

      queryParts.add(
        '${Uri.encodeQueryComponent(entry.key)}='
        '${Uri.encodeQueryComponent(_scalarToString(value))}',
      );
    }

    final prefix = base.replace(path: resolvedPath, query: null).toString();
    if (queryParts.isEmpty) {
      return Uri.parse(prefix);
    }
    return Uri.parse('$prefix?${queryParts.join('&')}');
  }

  static String _scalarToString(Object value) {
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }

  static String _joinPaths(String basePath, String nextPath) {
    final normalizedBase = basePath.isEmpty
        ? ''
        : (basePath.endsWith('/') && basePath.length > 1
              ? basePath.substring(0, basePath.length - 1)
              : basePath);
    final normalizedNext = nextPath.startsWith('/')
        ? nextPath.substring(1)
        : nextPath;

    if (normalizedBase.isEmpty || normalizedBase == '/') {
      return normalizedNext.isEmpty ? '/' : '/$normalizedNext';
    }
    if (normalizedNext.isEmpty) {
      return normalizedBase.startsWith('/')
          ? normalizedBase
          : '/$normalizedBase';
    }

    final baseWithSlash = normalizedBase.startsWith('/')
        ? normalizedBase
        : '/$normalizedBase';
    return '$baseWithSlash/$normalizedNext';
  }
}
