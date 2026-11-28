class SolarApiException implements Exception {
  SolarApiException(
    this.message, {
    this.statusCode,
    this.uri,
    this.details,
    this.retryAfter,
  });

  final String message;
  final int? statusCode;
  final Uri? uri;
  final Object? details;
  final Duration? retryAfter;

  String get userMessage => switch (statusCode) {
    401 ||
    403 => 'VEX Events could not authorize this connection. Check the API key.',
    429 =>
      'VEX Events is busy. Please wait ${retryAfter?.inSeconds ?? 30} seconds, then retry.',
    _ => 'Could not reach VEX Events. Check your connection and retry.',
  };

  @override
  String toString() {
    final pieces = <String>[message];
    if (statusCode != null) {
      pieces.add('status=$statusCode');
    }
    if (uri != null) {
      pieces.add('uri=$uri');
    }
    if (details != null) {
      pieces.add('details=$details');
    }
    return 'SolarApiException(${pieces.join(', ')})';
  }
}
