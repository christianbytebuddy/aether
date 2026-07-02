import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aether/models/album_model.dart';
import 'package:flutter/foundation.dart';

class SpotifyService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;
  SpotifyService._internal();
  // ── fin singleton ──────────────────────────────────────────────────────────
  static const _clientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');
  static const _clientSecret = String.fromEnvironment('SPOTIFY_CLIENT_SECRET');
  static const _authUrl = 'https://accounts.spotify.com/api/token';
  static const _apiUrl = 'https://api.spotify.com/v1';
  static const _itunesUrl = 'https://itunes.apple.com';

  String? _accessToken;
  DateTime? _tokenExpiry;

  static const List<String> _curatedAlbumIds = [
    '0EhZEM4RRz0yioTgucDhJq',
    '3RQQmkQEvNCY4prGKE6oc5',
    '2xkZV2Hl1Omi8rk2D7t5lN',
    '6OXg149IkmbgW7zfzbwgS2',
    '1vWMw6pu3err6qqZzI3RhH',
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

    // TEMPORAL
    debugPrint('searchAlbums "$query" → status: ${response.statusCode}');
    if (response.statusCode != 200) {
      debugPrint('Body error: ${response.body}');
    }
    // FIN TEMPORAL

    if (response.statusCode != 200) return [];
    // ... resto igual

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['albums']?['items'] as List<dynamic>?) ?? [];

    return items
        .map((item) => _albumFromSearchItem(item as Map<String, dynamic>))
        .toList();
  }

  // ── iTunes — reemplaza todo lo que era Deezer ─────────────────────────────

  /// Busca tracks de un artista en iTunes y devuelve los que tienen preview.
  /// Devuelve hasta [limit] tracks con previewUrl estable (30 s, nunca expira).
  Future<List<Map<String, dynamic>>> getArtistTopTracks(
    String artistName, {
    String? deezerArtistId, // parámetro mantenido por compatibilidad, ignorado
  }) async {
    final uri = Uri.parse(
      '$_itunesUrl/search'
      '?term=${Uri.encodeComponent(artistName)}'
      '&media=music'
      '&entity=song'
      '&limit=50'
      '&lang=en_us',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>?) ?? [];

    // Filtramos solo los tracks que realmente pertenecen al artista buscado
    // y que tienen preview disponible
    final tracks = results
        .cast<Map<String, dynamic>>()
        .where((t) {
          final artist = (t['artistName'] as String? ?? '').toLowerCase();
          final preview = t['previewUrl'] as String? ?? '';
          return artist.contains(artistName.toLowerCase()) &&
              preview.isNotEmpty;
        })
        .map((t) {
          final imageUrl = _itunesArtwork(t['artworkUrl100'] as String? ?? '');
          return <String, dynamic>{
            'id': t['trackId'].toString(),
            'name': t['trackName'] as String? ?? '',
            'previewUrl': t['previewUrl'] as String? ?? '',
            'imageUrl': imageUrl,
            // Mantenemos la clave por si algo en el código la lee
            'deezerTrackId': '',
          };
        })
        .toList();

    // Eliminamos duplicados por nombre de canción
    final seen = <String>{};
    final unique = tracks.where((t) => seen.add(t['name'] as String)).toList();

    return unique;
  }

  /// Obtiene un preview fresco de iTunes por trackId.
  /// Reemplaza getDeezerTrackPreview — la URL de iTunes NO expira,
  /// pero la mantenemos como método por si echo_game_page la llama.
  Future<String> getDeezerTrackPreview(String trackId) async {
    // Si el trackId está vacío (artistas buscados sin deezerArtistId),
    // no hay nada que buscar.
    if (trackId.isEmpty) return '';

    final uri = Uri.parse('$_itunesUrl/lookup?id=$trackId&entity=song');

    final res = await http.get(uri).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return '';

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>?) ?? [];
    if (results.length < 2) return '';

    // results[0] es la colección/álbum, results[1..] son los tracks
    for (final r in results.skip(1)) {
      final preview =
          (r as Map<String, dynamic>)['previewUrl'] as String? ?? '';
      if (preview.isNotEmpty) return preview;
    }
    return '';
  }

  /// Convierte la URL de artwork de 100px a 600px para mejor calidad.
  String _itunesArtwork(String url100) {
    if (url100.isEmpty) return '';
    return url100.replaceAll('100x100bb', '600x600bb');
  }

  // ── ECHO — búsqueda de artistas (sigue usando Spotify para imágenes) ───────

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
      return <String, dynamic>{
        'id': item['id'] as String? ?? '',
        'name': item['name'] as String? ?? '',
        'imageUrl': images.isNotEmpty
            ? (images[0]['url'] as String? ?? '')
            : '',
        // deezerArtistId ya no se usa — se deja vacío para no romper nada
        'deezerArtistId': '',
      };
    }).toList();
  }

  Future<AlbumModel> getAlbumById(String albumId) => getAlbum(albumId);

  Future<List<AlbumModel>> getPersonalizedFeed({
    required List<String> genres,
    required List<String> artists,
    int limit = 20,
  }) async {
    await _ensureToken();

    final queries = <String>[];

    for (final genre in genres.take(3)) {
      queries.add(genre);
    }
    for (final artist in artists.take(3)) {
      queries.add(artist);
    }

    if (queries.isEmpty) return getFeed(limit: limit);

    final results = await Future.wait(
      queries.map((q) async {
        try {
          final uri = Uri.parse(
            '$_apiUrl/search'
            '?q=${Uri.encodeComponent(q)}'
            '&type=album'
            '&limit=10',
          );
          final response = await http.get(
            uri,
            headers: {'Authorization': 'Bearer $_accessToken'},
          );
          if (response.statusCode != 200) return <AlbumModel>[];

          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = (data['albums']?['items'] as List<dynamic>?) ?? [];

          final filtered = items.where((item) {
            final totalTracks = item['total_tracks'] as int? ?? 0;
            return totalTracks >= 6;
          }).toList();

          final albums = await Future.wait(
            filtered.map((item) async {
              try {
                return await getAlbum(item['id'] as String);
              } catch (_) {
                return null;
              }
            }),
          );

          return albums
              .whereType<AlbumModel>()
              .where((a) => a.imageUrl.isNotEmpty && a.totalTracks >= 6)
              .toList();
        } catch (_) {
          return <AlbumModel>[];
        }
      }),
    );

    final seen = <String>{};
    final all = <AlbumModel>[];
    for (final list in results) {
      for (final album in list) {
        if (seen.add(album.id)) all.add(album);
      }
    }

    if (all.isEmpty) return getFeed(limit: limit);

    all.shuffle();
    return all.take(limit).toList();
  }

  /// Busca los previews de un álbum en iTunes por nombre de álbum y artista.
  /// Devuelve un mapa de {nombreCanción → previewUrl}.
  Future<Map<String, String>> getAlbumPreviewsFromItunes({
    required String albumName,
    required String artistName,
  }) async {
    final uri = Uri.parse(
      '$_itunesUrl/search'
      '?term=${Uri.encodeComponent('$artistName $albumName')}'
      '&media=music'
      '&entity=song'
      '&limit=50'
      '&lang=en_us',
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return {};

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>?) ?? [];

      final previews = <String, String>{};
      for (final r in results.cast<Map<String, dynamic>>()) {
        final trackName = (r['trackName'] as String? ?? '')
            .toLowerCase()
            .trim();
        final preview = r['previewUrl'] as String? ?? '';
        if (trackName.isNotEmpty && preview.isNotEmpty) {
          previews[trackName] = preview;
        }
      }
      return previews;
    } catch (_) {
      return {};
    }
  }
}
