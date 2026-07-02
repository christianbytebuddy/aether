import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:aether/services/spotify_service.dart';

class AlbumDetailSheet extends StatefulWidget {
  final AlbumModel album;
  final FirestoreService firestoreService;
  final Color bgColor;

  const AlbumDetailSheet({
    super.key,
    required this.album,
    required this.firestoreService,
    required this.bgColor,
  });

  @override
  State<AlbumDetailSheet> createState() => _AlbumDetailSheetState();
}

class _AlbumDetailSheetState extends State<AlbumDetailSheet> {
  static const _accent = Color(0xFF7B6EF6);

  // ── Likes / Rating ────────────────────────────────────────────────────────
  bool _isLiked = false;
  bool _isProcessing = false;
  double _rating = 0.0;

  // ── Audio ─────────────────────────────────────────────────────────────────
  final _player = AudioPlayer();
  final _spotify = SpotifyService();

  Map<String, String> _previews = {};
  bool _loadingPreviews = true;

  String? _playingTrackId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.album.isLiked;
    _rating = widget.album.rating;
    _loadRating();
    _loadTracksIfNeeded();
    _loadTracksAndPreviews();

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
      if (state == PlayerState.completed) {
        setState(() => _playingTrackId = null);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadTracksIfNeeded() async {
    if (widget.album.tracks.isNotEmpty) return;
    try {
      final full = await _spotify.getAlbum(widget.album.id);
      if (!mounted) return;
      setState(() {
        // Limpiamos por si acaso y agregamos los tracks frescos
        widget.album.tracks.clear();
        widget.album.tracks.addAll(full.tracks);
      });
    } catch (e) {
      debugPrint('ERROR cargando tracks: $e');
    }
  }

  Future<void> _loadTracksAndPreviews() async {
    // 1. Cargar tracks si vienen vacíos
    if (widget.album.tracks.isEmpty) {
      try {
        final full = await _spotify.getAlbum(widget.album.id);
        if (!mounted) return;
        setState(() {
          widget.album.tracks.clear();
          widget.album.tracks.addAll(full.tracks);
        });
      } catch (e) {
        debugPrint('ERROR cargando tracks: $e');
      }
    }

    // 2. Cargar previews de iTunes (ahora sí tenemos el nombre del álbum correcto)
    if (!mounted) return;
    try {
      final previews = await _spotify.getAlbumPreviewsFromItunes(
        albumName: widget.album.name,
        artistName: widget.album.artist,
      );
      if (mounted) {
        setState(() {
          _previews = previews;
          _loadingPreviews = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR cargando previews: $e');
      if (mounted) setState(() => _loadingPreviews = false);
    }
  }

  String _previewFor(TrackModel track) {
    final key = track.name.toLowerCase().trim();
    if (_previews.containsKey(key)) return _previews[key]!;
    for (final entry in _previews.entries) {
      if (entry.key.contains(key) || key.contains(entry.key)) {
        return entry.value;
      }
    }
    return '';
  }

  Future<void> _togglePlay(TrackModel track) async {
    final url = _previewFor(track);
    if (url.isEmpty) return;

    if (_playingTrackId == track.id && _isPlaying) {
      await _player.pause();
    } else if (_playingTrackId == track.id && !_isPlaying) {
      await _player.resume();
    } else {
      // play() con UrlSource es más rápido que setSourceUrl + resume
      await _player.stop();
      await _player.play(UrlSource(url));
      if (mounted) {
        setState(() => _playingTrackId = track.id);
        _preloadNext(track);
      }
    }
  }

  // Precarga el audio de la siguiente canción en segundo plano
  void _preloadNext(TrackModel current) {
    final tracks = widget.album.tracks;
    final idx = tracks.indexWhere((t) => t.id == current.id);
    if (idx == -1 || idx + 1 >= tracks.length) return;

    final next = tracks[idx + 1];
    final nextUrl = _previewFor(next);
    if (nextUrl.isEmpty) return;

    // Precargamos sin reproducir usando un player temporal
    final preloader = AudioPlayer();
    preloader.setSourceUrl(nextUrl).then((_) => preloader.dispose());
  }

  Future<void> _loadRating() async {
    final rating = await widget.firestoreService.getRating(widget.album.id);
    if (mounted) setState(() => _rating = rating);
  }

  Future<void> _toggleLike() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _isLiked = !_isLiked;
    });
    try {
      if (_isLiked) {
        await widget.firestoreService.likeAlbum(widget.album);
      } else {
        await widget.firestoreService.unlikeAlbum(widget.album.id);
      }
      widget.album.isLiked = _isLiked;
    } catch (_) {
      if (mounted) setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _setRating(double rating) async {
    final newRating = _rating == rating ? 0.0 : rating;
    setState(() => _rating = newRating);
    widget.album.rating = newRating;
    if (newRating == 0.0) {
      await widget.firestoreService.deleteRating(widget.album.id);
    } else {
      await widget.firestoreService.saveRating(widget.album.id, newRating);
    }
  }

  void _showSaveFolderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FolderPickerSheet(
        album: widget.album,
        firestoreService: widget.firestoreService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final topColor =
        Color.lerp(widget.bgColor, Colors.black, 0.3) ?? Colors.black;
    final bg = Color.lerp(widget.bgColor, Colors.black, 0.55) ?? Colors.black;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, bg, const Color(0xFF0B0F1A)],
            stops: const [0.0, 0.25, 1.0],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // ── Handle ──────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Portada con sombra ───────────────────────────────────────
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.30),
                      blurRadius: 48,
                      spreadRadius: 4,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: album.imageUrl,
                    width: MediaQuery.of(context).size.width * 0.58,
                    height: MediaQuery.of(context).size.width * 0.58,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFF1C1F2E)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // ── Nombre y artista ────────────────────────────────────────
            Text(
              album.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              album.artist,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // ── Pills de metadata ───────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MetaPill(
                  icon: Icons.calendar_today_rounded,
                  label: album.yearFormatted,
                ),
                const SizedBox(width: 8),
                _MetaPill(
                  icon: Icons.access_time_rounded,
                  label: album.durationFormatted,
                ),
                const SizedBox(width: 8),
                _MetaPill(
                  icon: Icons.music_note_rounded,
                  label: '${album.totalTracks} canciones',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Botones de acción ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: 'Me gusta',
                    isActive: _isLiked,
                    onTap: _toggleLike,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.create_new_folder_outlined,
                    label: 'Guardar',
                    isActive: false,
                    onTap: _showSaveFolderDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Estrellas centradas ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => _setRating((i + 1).toDouble()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      i < _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i < _rating ? _accent : Colors.white24,
                      size: 30,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // ── Géneros ─────────────────────────────────────────────────
            if (album.genres.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: album.genres
                    .take(4)
                    .map(
                      (g) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          g,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // ── Separador ───────────────────────────────────────────────
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.07),
              margin: const EdgeInsets.only(bottom: 16),
            ),

            // ── Header tracklist ────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'TRACKLIST',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                if (_loadingPreviews)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Lista de tracks ─────────────────────────────────────────
            ...album.tracks.map((track) {
              final hasPreview = _previewFor(track).isNotEmpty;
              final isThisPlaying = _playingTrackId == track.id && _isPlaying;
              final isThisActive = _playingTrackId == track.id;

              return GestureDetector(
                onTap: hasPreview ? () => _togglePlay(track) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white10, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Número
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${track.trackNumber}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isThisActive ? _accent : Colors.white30,
                            fontSize: 12,
                            fontWeight: isThisActive
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Nombre
                      Expanded(
                        child: Text(
                          track.name,
                          style: TextStyle(
                            color: isThisActive ? _accent : Colors.white,
                            fontSize: 14,
                            fontWeight: isThisActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Duración
                      Text(
                        track.durationFormatted,
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Botón play/pause
                      if (!_loadingPreviews)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isThisPlaying
                                ? _accent
                                : hasPreview
                                ? Colors.white.withOpacity(0.07)
                                : Colors.white.withOpacity(0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isThisPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 17,
                            color: hasPreview ? Colors.white : Colors.white24,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white38),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  static const _accent = Color(0xFF7B6EF6);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isActive
              ? _accent.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? _accent : Colors.white54, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _accent : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Folder Picker (sin cambios) ───────────────────────────────────────────────

class _FolderPickerSheet extends StatefulWidget {
  final AlbumModel album;
  final FirestoreService firestoreService;

  const _FolderPickerSheet({
    required this.album,
    required this.firestoreService,
  });

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  final _newFolderController = TextEditingController();

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  Future<void> _createAndSave() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty) return;
    final folderId = await widget.firestoreService.createFolder(name);
    await widget.firestoreService.saveAlbumToFolder(folderId, widget.album);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guardado en "$name"'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guardar en carpeta',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.firestoreService.foldersStream(),
            builder: (_, snap) {
              final folders = snap.data ?? [];
              if (folders.isEmpty) {
                return const Text(
                  'No tienes carpetas aún',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                );
              }
              return Column(
                children: folders
                    .map(
                      (f) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.folder_rounded,
                          color: Color(0xFF7B6EF6),
                        ),
                        title: Text(
                          f['name'] as String,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          await widget.firestoreService.saveAlbumToFolder(
                            f['id'] as String,
                            widget.album,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Guardado en "${f['name']}"'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newFolderController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nueva carpeta...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _createAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6EF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Crear',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
