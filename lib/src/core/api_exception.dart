class SolarApiException implements Exception {
  SolarApiException(this.message, {this.statusCode, this.uri, this.details});

  final String message;
  final int? statusCode;
  final Uri? uri;
  final Object? details;

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
