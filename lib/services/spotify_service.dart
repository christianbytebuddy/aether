import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aether/models/album_model.dart';

class SpotifyService {
  static const _clientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');
  static const _clientSecret = String.fromEnvironment('SPOTIFY_CLIENT_SECRET');
  static const _authUrl = 'https://accounts.spotify.com/api/token';
  static const _apiUrl = 'https://api.spotify.com/v1';

  String? _accessToken;
  DateTime? _tokenExpiry;

  static const List<String> _curatedAlbumIds = [
    '5052Ip89wdW8EGdpjEpNeq', // formula of love
    '0EhZEM4RRz0yioTgucDhJq', // how sweet
    '3RQQmkQEvNCY4prGKE6oc5', // un verano sin ti
    '2xkZV2Hl1Omi8rk2D7t5lN', // the new abnormal
    '6OXg149IkmbgW7zfzbwgS2', // the red summer
    '1vWMw6pu3err6qqZzI3RhH', // ruby
  ];

  Future<void> _ensureToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }

    _accessToken = null;
    _tokenExpiry = null;

    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

    final response = await http.post(
      Uri.parse(_authUrl),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (response.statusCode != 200) {
      throw Exception('Error obteniendo token: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String;
    _tokenExpiry = DateTime.now().add(
      Duration(seconds: (data['expires_in'] as int) - 60),
    );
  }

  Future<AlbumModel> getAlbum(String albumId) async {
    await _ensureToken();

    final response = await http.get(
      Uri.parse('$_apiUrl/albums/$albumId'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Error obteniendo álbum $albumId: ${response.body}');
    }

    return AlbumModel.fromSpotifyJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AlbumModel>> getFeed({int limit = 10}) async {
    await _ensureToken();

    final curatedAlbums = <AlbumModel>[];
    for (var i = 0; i < _curatedAlbumIds.length; i += 3) {
      final batch = _curatedAlbumIds.skip(i).take(3).toList();
      final results = await Future.wait(batch.map(getAlbum));
      curatedAlbums.addAll(results);
    }

    final discoveryAlbums = await _getNewReleases(limit: limit);
    final allIds = curatedAlbums.map((a) => a.id).toSet();
    final uniqueDiscovery = discoveryAlbums
        .where((a) => !allIds.contains(a.id))
        .toList();

    return [...curatedAlbums, ...uniqueDiscovery]..shuffle();
  }

  Future<List<AlbumModel>> _getNewReleases({int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/browse/new-releases?limit=$limit'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['albums']?['items'] as List<dynamic>?) ?? [];
    if (items.isEmpty) return [];

    final ids = items.map((i) => i['id'] as String).toList();
    final albums = <AlbumModel>[];
    for (var i = 0; i < ids.length; i += 3) {
      final batch = ids.skip(i).take(3).toList();
      try {
        final results = await Future.wait(batch.map(getAlbum));
        albums.addAll(results);
      } catch (_) {}
    }
    return albums;
  }

  AlbumModel _albumFromSearchItem(Map<String, dynamic> item) {
    final images = (item['images'] as List<dynamic>?) ?? [];
    final imageUrl = images.isNotEmpty
        ? (images[0]['url'] as String? ?? '')
        : '';

    final releaseDate = item['release_date'] as String? ?? '0';
    final year = int.tryParse(releaseDate.split('-')[0]) ?? 0;

    return AlbumModel(
      id: item['id'] as String? ?? '',
      name: item['name'] as String? ?? '',
      artist:
          (item['artists'] as List<dynamic>?)
              ?.map((a) => a['name'] as String)
              .join(', ') ??
          '',
      imageUrl: imageUrl,
      year: year,
      totalTracks: item['total_tracks'] as int? ?? 0,
      durationMs: 0,
      genres: [],
      tracks: [],
    );
  }

  Future<List<AlbumModel>> searchAlbums(String query) async {
    await _ensureToken();

    final uri = Uri.parse(
      '$_apiUrl/search'
      '?q=${Uri.encodeComponent(query)}'
      '&type=album'
      '&limit=10',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['albums']?['items'] as List<dynamic>?) ?? [];

    return items
        .map((item) => _albumFromSearchItem(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> getDeezerTrackPreview(String trackId) async {
    final res = await http.get(
      Uri.parse('https://api.deezer.com/track/$trackId'),
    );
    if (res.statusCode != 200) return '';
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['preview'] as String? ?? '';
  }

  // ── ECHO ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchArtists(String query) async {
    await _ensureToken();

    final uri = Uri.parse(
      '$_apiUrl/search'
      '?q=${Uri.encodeComponent(query)}'
      '&type=artist'
      '&limit=8',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['artists']?['items'] as List<dynamic>?) ?? [];

    return items.map((item) {
      final images = (item['images'] as List<dynamic>?) ?? [];
      return {
        'id': item['id'] as String? ?? '',
        'name': item['name'] as String? ?? '',
        'imageUrl': images.isNotEmpty
            ? (images[0]['url'] as String? ?? '')
            : '',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getArtistTopTracks(
    String artistName, {
    String? deezerArtistId,
  }) async {
    String resolvedId;
    String artistImageUrl = '';

    if (deezerArtistId != null && deezerArtistId.isNotEmpty) {
      resolvedId = deezerArtistId;

      final artistRes = await http.get(
        Uri.parse('https://api.deezer.com/artist/$resolvedId'),
      );
      if (artistRes.statusCode == 200) {
        final artistData = jsonDecode(artistRes.body) as Map<String, dynamic>;
        artistImageUrl =
            artistData['picture_xl'] as String? ??
            artistData['picture_big'] as String? ??
            artistData['picture'] as String? ??
            '';
      }
    } else {
      final searchRes = await http.get(
        Uri.parse(
          'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(artistName)}&limit=10',
        ),
      );
      if (searchRes.statusCode != 200) return [];

      final searchData = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final artists = (searchData['data'] as List<dynamic>?) ?? [];
      if (artists.isEmpty) return [];

      final exactMatches = artists
          .where(
            (a) =>
                (a['name'] as String).toLowerCase() == artistName.toLowerCase(),
          )
          .toList();

      final candidates = exactMatches.isNotEmpty ? exactMatches : artists;
      final match = candidates.reduce((a, b) {
        final fansA = (a['nb_fan'] as int?) ?? 0;
        final fansB = (b['nb_fan'] as int?) ?? 0;
        return fansA >= fansB ? a : b;
      });

      resolvedId = match['id'].toString();
      artistImageUrl =
          match['picture_xl'] as String? ??
          match['picture_big'] as String? ??
          match['picture'] as String? ??
          '';
    }

    final tracksRes = await http.get(
      Uri.parse('https://api.deezer.com/artist/$resolvedId/top?limit=30'),
    );
    if (tracksRes.statusCode != 200) return [];

    final tracksData = jsonDecode(tracksRes.body) as Map<String, dynamic>;
    final tracks = (tracksData['data'] as List<dynamic>?) ?? [];

    return tracks
        .map((t) {
          final album = t['album'] as Map<String, dynamic>? ?? {};
          final imageUrl =
              album['cover_xl'] as String? ??
              album['cover_big'] as String? ??
              album['cover_medium'] as String? ??
              album['cover'] as String? ??
              artistImageUrl;

          final previewUrl = t['preview'] as String? ?? '';

          return {
            'id': t['id'].toString(),
            'name': t['title'] as String? ?? '',
            'deezerTrackId': t['id'].toString(),
            'previewUrl': previewUrl,
            'imageUrl': imageUrl,
          };
        })
        .where((t) => (t['previewUrl'] as String).isNotEmpty)
        .toList();
  }

  Future<AlbumModel> getAlbumById(String albumId) => getAlbum(albumId);
}
