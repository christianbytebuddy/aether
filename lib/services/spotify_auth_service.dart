import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SpotifyAuthService {
  static const _clientId = 'b86fec074d134665a6691ee45672b57d';
  static const _clientSecret = '06dde81f08fd43b79591f4250b9c236a';
  static const _redirectUri = 'aether://spotify-callback';
  static const _scopes =
      'user-top-read user-read-private user-read-recently-played';

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static Function(String)? onCallback;

  String get _uid => _auth.currentUser!.uid;

  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }

  Future<bool> connectSpotify() async {
    try {
      final state = _generateState();

      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': _scopes,
        'state': state,
      });

      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      final completer = Completer<String>();

      onCallback = (url) {
        if (!completer.isCompleted) completer.complete(url);
      };

      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => '',
      );

      onCallback = null;

      if (result.isEmpty) return false;

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];
      if (code == null) return false;

      final tokens = await _exchangeCode(code);
      if (tokens == null) return false;

      await _saveTokens(tokens);
      return true;
    } catch (e) {
      debugPrint('SPOTIFY AUTH ERROR: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _exchangeCode(String code) async {
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
      },
    );

    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    await _db.collection('users').doc(_uid).update({
      'spotifyConnected': true,
      'spotifyAccessToken': tokens['access_token'],
      'spotifyRefreshToken': tokens['refresh_token'],
      'spotifyTokenExpiry': DateTime.now()
          .add(Duration(seconds: tokens['expires_in'] as int))
          .toIso8601String(),
    });
  }

  Future<String?> _getValidToken() async {
    final doc = await _db.collection('users').doc(_uid).get();
    final data = doc.data();
    if (data == null) return null;

    final expiry = DateTime.parse(
      data['spotifyTokenExpiry'] as String? ?? '2000-01-01',
    );

    if (DateTime.now().isBefore(expiry)) {
      return data['spotifyAccessToken'] as String?;
    }

    return await _refreshToken(data['spotifyRefreshToken'] as String? ?? '');
  }

  Future<String?> _refreshToken(String refreshToken) async {
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final newToken = data['access_token'] as String;

    await _db.collection('users').doc(_uid).update({
      'spotifyAccessToken': newToken,
      'spotifyTokenExpiry': DateTime.now()
          .add(Duration(seconds: data['expires_in'] as int))
          .toIso8601String(),
    });

    return newToken;
  }

  Future<List<Map<String, dynamic>>> getTopArtists() async {
    final token = await _getValidToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.https('api.spotify.com', '/v1/me/top/artists', {
        'limit': '10',
        'time_range': 'medium_term',
      }),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];

    return items
        .map(
          (a) => {
            'name': a['name'] as String,
            'imageUrl': (a['images'] as List<dynamic>?)?.isNotEmpty == true
                ? a['images'][0]['url'] as String
                : '',
            'genres': List<String>.from(a['genres'] as List? ?? []),
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getTopTracks() async {
    final token = await _getValidToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.https('api.spotify.com', '/v1/me/top/tracks', {
        'limit': '10',
        'time_range': 'medium_term',
      }),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];

    return items
        .map(
          (t) => {
            'name': t['name'] as String,
            'artist':
                (t['artists'] as List<dynamic>?)
                    ?.map((a) => a['name'] as String)
                    .join(', ') ??
                '',
            'durationMs': t['duration_ms'] as int,
            'imageUrl':
                (t['album']?['images'] as List<dynamic>?)?.isNotEmpty == true
                ? t['album']['images'][0]['url'] as String
                : '',
            'albumName': t['album']?['name'] as String? ?? '',
          },
        )
        .toList();
  }

  Future<bool> isConnected() async {
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.data()?['spotifyConnected'] == true;
  }

  Future<void> disconnect() async {
    await _db.collection('users').doc(_uid).update({
      'spotifyConnected': false,
      'spotifyAccessToken': FieldValue.delete(),
      'spotifyRefreshToken': FieldValue.delete(),
      'spotifyTokenExpiry': FieldValue.delete(),
    });
  }

  Future<List<Map<String, dynamic>>> getRecentlyPlayed() async {
    final token = await _getValidToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.https('api.spotify.com', '/v1/me/player/recently-played', {
        'limit': '50',
      }),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];

    return items.map((item) {
      final track = item['track'] as Map<String, dynamic>;
      return {
        'name': track['name'] as String,
        'artist':
            (track['artists'] as List<dynamic>?)
                ?.map((a) => a['name'] as String)
                .join(', ') ??
            '',
        'durationMs': track['duration_ms'] as int,
        'playedAt': item['played_at'] as String,
      };
    }).toList();
  }
}
