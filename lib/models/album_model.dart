import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/firestore_service.dart';

class AlbumModel {
  final String id;
  final String name;
  final String artist;
  final String imageUrl;
  final int year;
  final int totalTracks;
  final int durationMs;
  final List<String> genres;
  final List<TrackModel> tracks;

  bool isLiked;
  bool isSaved;
  double rating;

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
    this.rating = 0.0,
  });

  String get durationFormatted {
    final minutes = (durationMs / 60000).round();
    return '$minutes min';
  }

  String get yearFormatted => year.toString();

  factory AlbumModel.fromSpotifyJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks']?['items'] as List<dynamic>?) ?? [];
    final tracks = rawTracks
        .map((t) => TrackModel.fromJson(t as Map<String, dynamic>))
        .toList();

    final images = (json['images'] as List<dynamic>?) ?? [];
    final imageUrl = images.isNotEmpty
        ? (images[0]['url'] as String? ?? '')
        : '';

    final releaseDate = json['release_date'] as String? ?? '0';
    final year = int.tryParse(releaseDate.split('-')[0]) ?? 0;

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

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'artist': artist,
    'imageUrl': imageUrl,
    'year': year,
    'totalTracks': totalTracks,
    'durationMs': durationMs,
    'genres': genres,
    'tracks': tracks
        .map(
          (t) => {
            'id': t.id,
            'name': t.name,
            'trackNumber': t.trackNumber,
            'durationMs': t.durationMs,
            'previewUrl': t.previewUrl, // ← nuevo
          },
        )
        .toList(),
  };

  factory AlbumModel.fromCacheJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List<dynamic>?) ?? [];
    return AlbumModel(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: json['artist'] as String,
      imageUrl: json['imageUrl'] as String,
      year: json['year'] as int,
      totalTracks: json['totalTracks'] as int,
      durationMs: json['durationMs'] as int,
      genres: List<String>.from(json['genres'] as List? ?? []),
      tracks: rawTracks
          .map(
            (t) => TrackModel(
              id: t['id'] as String,
              name: t['name'] as String,
              trackNumber: t['trackNumber'] as int,
              durationMs: t['durationMs'] as int,
              previewUrl: t['previewUrl'] as String? ?? '', // ← nuevo
            ),
          )
          .toList(),
    );
  }
}

class TrackModel {
  final String id;
  final String name;
  final int trackNumber;
  final int durationMs;
  final String previewUrl; // ← nuevo

  TrackModel({
    required this.id,
    required this.name,
    required this.trackNumber,
    required this.durationMs,
    this.previewUrl = '', // ← nuevo, opcional para no romper código existente
  });

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
      previewUrl: json['previewUrl'] as String? ?? '', // ← nuevo
    );
  }
}
