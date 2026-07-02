import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/core/user_session.dart';

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

  Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    final snap = await _posts
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final lower = query.toLowerCase();

    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .where((post) {
          final title = (post['title'] as String? ?? '').toLowerCase();
          final description = (post['description'] as String? ?? '')
              .toLowerCase();
          final username = (post['username'] as String? ?? '').toLowerCase();
          return title.contains(lower) ||
              description.contains(lower) ||
              username.contains(lower);
        })
        .toList();
  }

  // ── RATINGS ───────────────────────────────────────────────────────────────

  CollectionReference get _ratings =>
      _db.collection('users').doc(_uid).collection('ratings');

  Future<void> saveRating(String albumId, double rating) async {
    await _ratings.doc(albumId).set({
      'albumId': albumId,
      'rating': rating,
      'ratedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRating(String albumId) async {
    await _ratings.doc(albumId).delete();
  }

  Future<double> getRating(String albumId) async {
    final doc = await _ratings.doc(albumId).get();
    if (!doc.exists) return 0.0;
    return (doc.data() as Map<String, dynamic>)['rating'] as double? ?? 0.0;
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
    final foldersSnap = await _folders.get();

    // Todas las lecturas en paralelo — una sola espera
    final results = await Future.wait([
      isAlbumLiked(albumId),
      ...foldersSnap.docs.map(
        (folder) => _folders
            .doc(folder.id)
            .collection('albums')
            .doc(albumId)
            .get()
            .then((doc) => doc.exists ? folder.id : null),
      ),
    ]);

    final isLiked = results.first as bool;
    final savedInFolders = results.skip(1).whereType<String>().toList();

    return {'isLiked': isLiked, 'savedInFolders': savedInFolders};
  }

  // ── COMUNIDAD ─────────────────────────────────────────────────────────────

  final CollectionReference _posts = FirebaseFirestore.instance.collection(
    'community_posts',
  );

  Future<void> createPost({
    required String title,
    required String description,
    required List<AlbumModel> albums,
  }) async {
    final user = _auth.currentUser!;
    await _posts.add({
      'uid': user.uid,
      'username': user.displayName ?? 'Usuario',
      'avatarLetter': (user.displayName ?? 'U')[0].toUpperCase(),
      'photoBase64': UserSession.instance.photoBase64, // ← nuevo
      'title': title,
      'description': description,
      'likes': 0,
      'likedBy': [],
      'albums': albums
          .map(
            (a) => {
              'id': a.id,
              'name': a.name,
              'artist': a.artist,
              'imageUrl': a.imageUrl,
            },
          )
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> togglePostLike(String postId, bool isCurrentlyLiked) async {
    final ref = _posts.doc(postId);
    if (isCurrentlyLiked) {
      await ref.set({
        'likedBy': FieldValue.arrayRemove([_uid]),
        'likes': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'likedBy': FieldValue.arrayUnion([_uid]),
        'likes': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
  }

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final user = _auth.currentUser!;
    await _posts.doc(postId).collection('comments').add({
      'uid': user.uid,
      'username': user.displayName ?? 'Usuario',
      'avatarLetter': (user.displayName ?? 'U')[0].toUpperCase(),
      'photoBase64': UserSession.instance.photoBase64, // ← nuevo
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> commentsStream(String postId) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Future<void> updatePost({
    required String postId,
    required String title,
    required String description,
    required List<AlbumModel> albums,
  }) async {
    await _posts.doc(postId).update({
      'title': title,
      'description': description,
      'albums': albums
          .map(
            (a) => <String, dynamic>{
              'id': a.id,
              'name': a.name,
              'artist': a.artist,
              'imageUrl': a.imageUrl,
            },
          )
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost(String postId) async {
    // Borra comentarios primero
    final comments = await _posts.doc(postId).collection('comments').get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }
    await _posts.doc(postId).delete();
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _posts.doc(postId).collection('comments').doc(commentId).delete();
  }

  Future<Map<String, dynamic>?> getUserDoc(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> saveUserPhoto(String uid, String base64Str) async {
    await _db.collection('users').doc(uid).set({
      'photoBase64': base64Str,
    }, SetOptions(merge: true));
  }

  // ── PREFERENCIAS DE USUARIO ───────────────────────────────────────────────

  Future<bool> hasPreferences() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;
    final genres = data['preferredGenres'] as List?;
    return genres != null && genres.isNotEmpty;
  }

  Future<void> savePreferences({
    required List<String> genres,
    required List<String> artistNames,
  }) async {
    await _db.collection('users').doc(_uid).set({
      'preferredGenres': genres,
      'preferredArtists': artistNames,
      'preferencesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return {'genres': [], 'artists': []};
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return {
      'genres': List<String>.from(data['preferredGenres'] as List? ?? []),
      'artists': List<String>.from(data['preferredArtists'] as List? ?? []),
    };
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

  Stream<Map<String, dynamic>> postStream(String postId) {
    return _posts
        .doc(postId)
        .snapshots()
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>});
  }

  Stream<List<Map<String, dynamic>>> communityPostsStream() {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) {
          final docs = snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList();

          // Saca el pinneado si existe
          final pinned = docs.where((p) => p['pinned'] == true).toList();
          final rest = docs.where((p) => p['pinned'] != true).toList();

          // Pinneado siempre primero, el resto en orden normal
          return [...pinned, ...rest];
        });
  }
  // ── DIARIO MUSICAL ────────────────────────────────────────────────────────

  CollectionReference get _diary =>
      _db.collection('users').doc(_uid).collection('diary');

  Future<void> addDiaryEntry({
    required String albumId,
    required String albumName,
    required String albumArtist,
    required String albumImage,
    required String note,
  }) async {
    await _diary.add({
      'albumId': albumId,
      'albumName': albumName,
      'albumArtist': albumArtist,
      'albumImage': albumImage,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDiaryEntry(String entryId) async {
    await _diary.doc(entryId).delete();
  }

  Stream<List<Map<String, dynamic>>> diaryStream() {
    return _diary
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }
}
