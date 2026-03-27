import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aether/models/album_model.dart';

class SpotifyService {
  static const _clientId = 'b86fec074d134665a6691ee45672b57d';
  static const _clientSecret = '06dde81f08fd43b79591f4250b9c236a';
  static const _authUrl = 'https://accounts.spotify.com/api/token';
  static const _apiUrl = 'https://api.spotify.com/v1';

  String? _accessToken;
  DateTime? _tokenExpiry;

  static const List<String> _curatedAlbumIds = [
    '5052Ip89wdW8EGdpjEpNeq',
    '2NCtCObbmJoJnplsR5mLAl',
    '3RQQmkQEvNCY4prGKE6oc5',
    '3HgoCO9wWuPcNhz8Ip4C46',
    '02m1qgJzjEADPa353lcevb',
    '0EhZEM4RRz0yioTgucDhJq',
    '4lkJ6i3LDK8HvcU2tPWX9k',
    '2X6WyzpxY70eUn3lnewB7d',
    '2V5rhszUpCudPcb01zevOt?',
  ];

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<void> _ensureToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }
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

  // ── Álbum completo por ID (con tracklist) ─────────────────────────────────

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

  // ── Feed del home ─────────────────────────────────────────────────────────

  Future<List<AlbumModel>> getFeed({int limit = 10}) async {
    await _ensureToken();

    final curatedAlbums = await Future.wait(_curatedAlbumIds.map(getAlbum));

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

    try {
      return await Future.wait(
        items.map((item) => getAlbum(item['id'] as String)),
      );
    } catch (_) {
      return [];
    }
  }

  // ── Búsqueda optimizada ───────────────────────────────────────────────────
  //
  // ANTES: hacía 15 llamadas individuales para obtener el álbum completo.
  // AHORA: usa los datos que ya devuelve /search (portada, nombre, artista,
  //        año) y construye un AlbumModel liviano SIN tracklist.
  //        El tracklist completo solo se carga al abrir el detail sheet.

  Future<List<AlbumModel>> searchAlbums(String query) async {
    await _ensureToken();

    final uri = Uri.parse(
      '$_apiUrl/search'
      '?q=${Uri.encodeComponent(query)}'
      '&type=album'
      '&limit=20',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['albums']?['items'] as List<dynamic>?) ?? [];

    // Construye modelos livianos directamente desde la respuesta de /search
    // → 1 sola llamada HTTP en lugar de 20
    return items
        .map((item) => _albumFromSearchItem(item as Map<String, dynamic>))
        .toList();
  }

  /// Construye un AlbumModel liviano desde el item de /search.
  /// No tiene tracklist — se carga bajo demanda al abrir el detalle.
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
      durationMs: 0, // No disponible en /search — se carga al abrir detalle
      genres: [], // No disponible en /search
      tracks: [], // Se carga bajo demanda
    );
  }
}
