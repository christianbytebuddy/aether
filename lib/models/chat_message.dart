import 'package:aether/models/album_model.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String content;
  final List<AlbumModel> albums;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
    this.albums = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
    'isUser': isUser,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'albums': albums
        .map(
          (a) => {
            'id': a.id,
            'name': a.name,
            'artist': a.artist,
            'imageUrl': a.imageUrl,
            'year': a.year,
            'totalTracks': a.totalTracks,
            'durationMs': a.durationMs,
            'genres': a.genres,
            // ── Guardamos los tracks completos ──
            'tracks': a.tracks
                .map(
                  (t) => {
                    'id': t.id,
                    'name': t.name,
                    'trackNumber': t.trackNumber,
                    'durationMs': t.durationMs,
                    'previewUrl': t.previewUrl,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  };

  factory ChatMessage.fromFirestore(String id, Map<String, dynamic> data) {
    final rawAlbums = (data['albums'] as List<dynamic>?) ?? [];
    return ChatMessage(
      id: id,
      isUser: data['isUser'] as bool,
      content: data['content'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      albums: rawAlbums.map((a) {
        final map = a as Map<String, dynamic>;
        // ── Reconstruimos los tracks desde Firestore ──
        final rawTracks = (map['tracks'] as List<dynamic>?) ?? [];
        final tracks = rawTracks.map((t) {
          final tm = t as Map<String, dynamic>;
          return TrackModel(
            id: tm['id'] as String? ?? '',
            name: tm['name'] as String? ?? '',
            trackNumber: tm['trackNumber'] as int? ?? 0,
            durationMs: tm['durationMs'] as int? ?? 0,
            previewUrl: tm['previewUrl'] as String? ?? '',
          );
        }).toList();

        return AlbumModel(
          id: map['id'] as String? ?? '',
          name: map['name'] as String? ?? '',
          artist: map['artist'] as String? ?? '',
          imageUrl: map['imageUrl'] as String? ?? '',
          year: map['year'] as int? ?? 0,
          totalTracks: map['totalTracks'] as int? ?? 0,
          durationMs: map['durationMs'] as int? ?? 0,
          genres: List<String>.from(map['genres'] as List? ?? []),
          tracks: tracks, // ← ya no es []
        );
      }).toList(),
    );
  }
}
