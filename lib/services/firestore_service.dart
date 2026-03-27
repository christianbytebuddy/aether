import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aether/models/album_model.dart';

/// Maneja el CRUD de likes y carpetas en Firestore.
///
/// Estructura en Firestore:
/// users/{uid}/
///   liked_albums/{albumId}   → datos del álbum likeado
///   folders/{folderId}/
///     name: String
///     albums/{albumId}       → datos del álbum guardado
class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ── Referencias ───────────────────────────────────────────────────────────

  CollectionReference get _likedAlbums =>
      _db.collection('users').doc(_uid).collection('liked_albums');

  CollectionReference get _folders =>
      _db.collection('users').doc(_uid).collection('folders');

  // ── LIKES ─────────────────────────────────────────────────────────────────

  Future<void> likeAlbum(AlbumModel album) async {
    await _likedAlbums.doc(album.id).set(_albumToMap(album));
  }

  Future<void> unlikeAlbum(String albumId) async {
    await _likedAlbums.doc(albumId).delete();
  }

  Future<bool> isAlbumLiked(String albumId) async {
    final doc = await _likedAlbums.doc(albumId).get();
    return doc.exists;
  }

  /// Stream en tiempo real de álbumes likeados
  Stream<List<AlbumModel>> likedAlbumsStream() {
    return _likedAlbums
        .orderBy('likedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => _albumFromMap(d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  // ── CARPETAS ──────────────────────────────────────────────────────────────

  /// Crea una carpeta nueva
  Future<String> createFolder(String name) async {
    final ref = await _folders.add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> renameFolder(String folderId, String newName) async {
    await _folders.doc(folderId).update({'name': newName});
  }

  /// Elimina una carpeta y todos sus álbumes
  Future<void> deleteFolder(String folderId) async {
    // Borra los álbumes dentro primero
    final albums = await _folders.doc(folderId).collection('albums').get();
    for (final doc in albums.docs) {
      await doc.reference.delete();
    }
    await _folders.doc(folderId).delete();
  }

  /// Stream en tiempo real de carpetas del usuario
  Stream<List<Map<String, dynamic>>> foldersStream() {
    return _folders
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

  // ── ÁLBUMES EN CARPETA ────────────────────────────────────────────────────

  Future<void> saveAlbumToFolder(String folderId, AlbumModel album) async {
    await _folders
        .doc(folderId)
        .collection('albums')
        .doc(album.id)
        .set(_albumToMap(album));
  }

  Future<void> removeAlbumFromFolder(String folderId, String albumId) async {
    await _folders.doc(folderId).collection('albums').doc(albumId).delete();
  }

  Stream<List<AlbumModel>> folderAlbumsStream(String folderId) {
    return _folders
        .doc(folderId)
        .collection('albums')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _albumFromMap(d.data())).toList());
  }

  // ── Estado combinado (liked + saved) para un álbum ───────────────────────

  /// Carga si un álbum está likeado y en qué carpetas está guardado
  Future<Map<String, dynamic>> getAlbumState(String albumId) async {
    final liked = await isAlbumLiked(albumId);

    final foldersSnap = await _folders.get();
    final savedInFolders = <String>[];

    for (final folder in foldersSnap.docs) {
      final albumDoc = await _folders
          .doc(folder.id)
          .collection('albums')
          .doc(albumId)
          .get();
      if (albumDoc.exists) savedInFolders.add(folder.id);
    }

    return {'isLiked': liked, 'savedInFolders': savedInFolders};
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Map<String, dynamic> _albumToMap(AlbumModel album) => {
    'id': album.id,
    'name': album.name,
    'artist': album.artist,
    'imageUrl': album.imageUrl,
    'year': album.year,
    'totalTracks': album.totalTracks,
    'durationMs': album.durationMs,
    'genres': album.genres,
    'likedAt': FieldValue.serverTimestamp(),
    'savedAt': FieldValue.serverTimestamp(),
  };

  AlbumModel _albumFromMap(Map<String, dynamic> map) => AlbumModel(
    id: map['id'] as String,
    name: map['name'] as String,
    artist: map['artist'] as String,
    imageUrl: map['imageUrl'] as String,
    year: map['year'] as int,
    totalTracks: map['totalTracks'] as int,
    durationMs: map['durationMs'] as int,
    genres: List<String>.from(map['genres'] as List? ?? []),
    tracks: [], // No guardamos tracklist en Firestore para ahorrar espacio
  );
}
