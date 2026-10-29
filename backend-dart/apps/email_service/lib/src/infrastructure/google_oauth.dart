import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:portal_core/portal_core.dart';

class GoogleConnection {
  const GoogleConnection(this.email, this.refreshToken);
  final String email;
  final String refreshToken;
}

class GoogleOAuth {
  GoogleOAuth({
    required this.client,
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    required this.stateSecret,
    required this.appUrl,
    DateTime Function()? clock,
    Uri? tokenEndpoint,
    Uri? profileEndpoint,
  })  : _clock = clock ?? DateTime.now,
        _tokenEndpoint = tokenEndpoint ??
            Uri.parse('https://oauth2.googleapis.com/token'),
        _profileEndpoint = profileEndpoint ??
            Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo') {
    if (stateSecret.isEmpty) throw ArgumentError('State secret required');
  }

  final http.Client client;
  final String clientId, clientSecret, redirectUri, stateSecret, appUrl;
  final DateTime Function() _clock;
  final Uri _tokenEndpoint, _profileEndpoint;

  static const scope =
      'https://www.googleapis.com/auth/gmail.send '
      'https://www.googleapis.com/auth/userinfo.email';

  String _encode(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  String _signature(String input) => base64Url
      .encode(Hmac(sha256, utf8.encode(stateSecret))
          .convert(utf8.encode(input)).bytes)
      .replaceAll('=', '');

  String stateFor(String id, String email) {
    final payload = _encode(jsonEncode({
      'sub': id,
      'email': email,
      'role': 'admin',
      'iat': _clock().toUtc().millisecondsSinceEpoch,
    }));
    return payload + '.' + _signature(payload);
  }

  Map<String, dynamic>? parseState(String? state) {
    if (state == null || state.length > 4096) return null;
    final parts = state.split('.');
    if (parts.length != 2 ||
        !safeTokenEquals(parts[1], _signature(parts[0]))) return null;
    try {
      final payload = jsonDecode(utf8.decode(
          base64Url.decode(base64Url.normalize(parts[0]))));
      if (payload is! Map<String, dynamic> ||
          payload['role'] != 'admin' ||
          payload['sub'] is! String ||
          payload['email'] is! String ||
          payload['iat'] is! int) return null;
      final age = _clock().toUtc().millisecondsSinceEpoch -
          (payload['iat'] as int);
      if (age < 0 || age > const Duration(minutes: 10).inMilliseconds) {
        return null;
      }
      return payload;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Uri authorizationUrl(String id, String email) =>
      Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scope,
        'access_type': 'offline',
        'prompt': 'consent',
        'state': stateFor(id, email),
      });

  Future<Map<String, dynamic>> _token(Map<String, String> fields) async {
    final response = await client.post(_tokenEndpoint, body: fields)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Google OAuth returned HTTP ' +
          response.statusCode.toString());
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Google response');
    }
    return decoded;
  }

  Future<GoogleConnection> exchange(String code) async {
    final tokens = await _token({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'client_secret': clientSecret,
    });
    final access = tokens['access_token'];
    final refresh = tokens['refresh_token'];
    if (access is! String || access.isEmpty ||
        refresh is! String || refresh.isEmpty) {
      throw const FormatException('Missing Google tokens');
    }
    final response = await client.get(_profileEndpoint,
        headers: {'authorization': 'Bearer ' + access})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Google profile returned HTTP ' +
          response.statusCode.toString());
    }
    final profile = jsonDecode(response.body);
    if (profile is! Map<String, dynamic> ||
        profile['email'] is! String ||
        (profile['email'] as String).isEmpty) {
      throw const FormatException('Missing Google email');
    }
    return GoogleConnection(profile['email'] as String, refresh);
  }

  Future<String> refresh(String refreshToken) async {
    final tokens = await _token({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
      'client_secret': clientSecret,
    });
    final access = tokens['access_token'];
    if (access is! String || access.isEmpty) {
      throw const FormatException('Google access token unavailable');
    }
    return access;
  }

  Uri adminRedirect(String status) =>
      Uri.parse(appUrl).resolve('/admin/email-connections')
          .replace(queryParameters: {'google': status});
}
