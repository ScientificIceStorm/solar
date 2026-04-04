import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'query_encoder.dart';

class JsonApiClient {
  JsonApiClient(this._client);

  final http.Client _client;

  Future<dynamic> getJson({
    required String baseUrl,
    required String path,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
  }) async {
    final uri = QueryEncoder.buildUri(baseUrl, path, query);

    try {
      final response = await _client.get(
        uri,
        headers: <String, String>{'Accept': 'application/json', ...headers},
      );
      return _decodeResponse(response, uri);
    } on Exception catch (error) {
      throw SolarApiException(
        'Network request failed',
        uri: uri,
        details: error,
      );
    }
  }

  Future<dynamic> postJson({
    required String baseUrl,
    required String path,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final uri = QueryEncoder.buildUri(baseUrl, path, query);

    try {
      final response = await _client.post(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...headers,
        },
        body: body == null ? null : jsonEncode(body),
      );
      return _decodeResponse(response, uri);
    } on Exception catch (error) {
      throw SolarApiException(
        'Network request failed',
        uri: uri,
        details: error,
      );
    }
  }

  dynamic _decodeResponse(http.Response response, Uri uri) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SolarApiException(
        'Request failed',
        statusCode: response.statusCode,
        uri: uri,
        details: response.body,
      );
    }

    final body = response.body.trim();
    if (body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw SolarApiException(
        'Response was not valid JSON',
        statusCode: response.statusCode,
        uri: uri,
        details: error,
      );
    }
  }
}
