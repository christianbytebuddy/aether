class AlbumModel {
  final String id; // ID único de Spotify
  final String name; // Nombre del álbum
  final String artist; // Artista principal
  final String imageUrl; // URL de la portada (Spotify provee 3 tamaños)
  final int year; // Año de lanzamiento
  final int totalTracks; // Total de canciones
  final int durationMs; // Duración total en milisegundos
  final List<String> genres; // Géneros (vienen del artista en Spotify)
  final List<TrackModel> tracks; // Tracklist

  bool isLiked;
  bool isSaved;

  AlbumModel({
    required this.id,
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.year,
    required this.totalTracks,
    required this.durationMs,
    required this.genres,
    required this.tracks,
    this.isLiked = false,
    this.isSaved = false,
  });

  /// Duración total formateada
  String get durationFormatted {
    final minutes = (durationMs / 60000).round();
    return '$minutes min';
  }

  /// Año como String
  String get yearFormatted => year.toString();

  /// Construye un AlbumModel desde la respuesta JSON de Spotify
  factory AlbumModel.fromSpotifyJson(Map<String, dynamic> json) {
    // Tracklist
    final rawTracks = (json['tracks']?['items'] as List<dynamic>?) ?? [];
    final tracks = rawTracks
        .map((t) => TrackModel.fromJson(t as Map<String, dynamic>))
        .toList();

    // Portada — Spotify devuelve 3 tamaños, tomamos el más grande
    final images = (json['images'] as List<dynamic>?) ?? [];
    final imageUrl = images.isNotEmpty
        ? (images[0]['url'] as String? ?? '')
        : '';

    // Año desde release_date "2021-10-22" → 2021
    final releaseDate = json['release_date'] as String? ?? '0';
    final year = int.tryParse(releaseDate.split('-')[0]) ?? 0;

    // Duración total sumando todas las pistas
    final durationMs = tracks.fold<int>(0, (sum, t) => sum + t.durationMs);

    return AlbumModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      artist:
          (json['artists'] as List<dynamic>?)
              ?.map((a) => a['name'] as String)
              .join(', ') ??
          '',
      imageUrl: imageUrl,
      year: year,
      totalTracks: json['total_tracks'] as int? ?? 0,
      durationMs: durationMs,
      genres: List<String>.from(json['genres'] as List<dynamic>? ?? []),
      tracks: tracks,
    );
  }
}

/// Modelo de una canción dentro del álbum
class TrackModel {
  final String id;
  final String name;
  final int trackNumber;
  final int durationMs;

  TrackModel({
    required this.id,
    required this.name,
    required this.trackNumber,
    required this.durationMs,
  });

  /// Duración formateada → "3:45"
  String get durationFormatted {
    final minutes = durationMs ~/ 60000;
    final seconds = (durationMs % 60000) ~/ 1000;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      trackNumber: json['track_number'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
    );
  }
}
