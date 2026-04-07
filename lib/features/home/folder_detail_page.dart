import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:aether/features/home/album_detail_sheet.dart';

class FolderDetailPage extends StatefulWidget {
  final String folderId;
  final String folderName;

  const FolderDetailPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  final _firestore = FirestoreService();
  final _spotify = SpotifyService();
  final _searchController = TextEditingController();

  bool _searchMode = false;
  bool _isSearching = false;
  List<AlbumModel> _searchResults = [];
  Set<String> _savedAlbumIds = {};

  static const _bgColor = Color(0xFF0B0F1A);
  static const _accentColor = Color(0xFF7B6EF6);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchMode = !_searchMode;
      if (!_searchMode) {
        _searchController.clear();
        _searchResults = [];
        _isSearching = false;
      }
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _spotify.searchAlbums(query.trim());
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo conectar con Spotify'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveAlbum(AlbumModel album) async {
    await _firestore.saveAlbumToFolder(widget.folderId, album);
    if (mounted) {
      setState(() => _savedAlbumIds.add(album.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${album.name}" guardado en ${widget.folderName}'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _searchMode
              ? TextField(
                  key: const ValueKey('search'),
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: _accentColor,
                  onChanged: _search,
                  decoration: const InputDecoration(
                    hintText: 'Buscar álbum en Spotify...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                )
              : Align(
                  key: const ValueKey('title'),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.folderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                ),
        ),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _searchMode ? Icons.close : Icons.search,
                key: ValueKey(_searchMode),
                color: _searchMode ? _accentColor : Colors.white54,
                size: 22,
              ),
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _searchMode ? _buildSearchBody() : _buildFolderBody(),
    );
  }

  Widget _buildSearchBody() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: _accentColor, strokeWidth: 2),
      );
    }
    if (_searchController.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: Colors.white12, size: 48),
            SizedBox(height: 12),
            Text(
              'Escribe el nombre de un álbum o artista',
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados para "${_searchController.text}"',
          style: const TextStyle(color: Colors.white24, fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) {
        final album = _searchResults[i];
        final alreadySaved = _savedAlbumIds.contains(album.id);
        return _SearchResultRow(
          album: album,
          alreadySaved: alreadySaved,
          onSave: alreadySaved ? null : () => _saveAlbum(album),
        );
      },
    );
  }

  Widget _buildFolderBody() {
    return StreamBuilder<List<AlbumModel>>(
      stream: _firestore.folderAlbumsStream(widget.folderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _accentColor,
              strokeWidth: 2,
            ),
          );
        }

        final albums = snapshot.data ?? [];

        // Actualiza fuera del build para evitar rebuilds en cascada
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _savedAlbumIds = albums.map((a) => a.id).toSet();
          }
        });

        if (albums.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.album_outlined, color: Colors.white12, size: 48),
                SizedBox(height: 12),
                Text(
                  'No hay álbumes en esta carpeta',
                  style: TextStyle(color: Colors.white24, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  'Toca la lupa para buscar y agregar',
                  style: TextStyle(color: Colors.white12, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          itemCount: albums.length,
          itemBuilder: (_, i) => _AlbumRow(
            album: albums[i],
            firestore: _firestore,
            folderId: widget.folderId,
          ),
        );
      },
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  final AlbumModel album;
  final bool alreadySaved;
  final VoidCallback? onSave;

  const _SearchResultRow({
    required this.album,
    required this.alreadySaved,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: CachedNetworkImage(
                imageUrl: album.imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(
                  width: 70,
                  height: 70,
                  child: ColoredBox(color: Color(0xFF1A1F35)),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 70,
                  height: 70,
                  color: const Color(0xFF1A1F35),
                  child: const Icon(
                    Icons.album,
                    color: Colors.white12,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    album.artist,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    album.yearFormatted,
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: alreadySaved
                  ? const Tooltip(
                      message: 'Ya está en esta carpeta',
                      child: Icon(
                        Icons.check_circle,
                        color: Color(0xFF7B6EF6),
                        size: 22,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white54,
                        size: 22,
                      ),
                      onPressed: onSave,
                      tooltip: 'Guardar en carpeta',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumRow extends StatelessWidget {
  final AlbumModel album;
  final FirestoreService firestore;
  final String folderId;

  const _AlbumRow({
    required this.album,
    required this.firestore,
    required this.folderId,
  });

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlbumDetailSheet(
        album: album,
        firestoreService: firestore,
        bgColor: const Color(0xFF111827),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Quitar álbum',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        content: Text(
          '¿Quitar "${album.name}" de esta carpeta?',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await firestore.removeAlbumFromFolder(folderId, album.id);
            },
            child: const Text(
              'Quitar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openDetail(context),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: CachedNetworkImage(
                  imageUrl: album.imageUrl,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox(
                    width: 70,
                    height: 70,
                    child: ColoredBox(color: Color(0xFF1A1F35)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 70,
                    height: 70,
                    color: const Color(0xFF1A1F35),
                    child: const Icon(
                      Icons.album,
                      color: Colors.white12,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      album.artist,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${album.yearFormatted} · ${album.totalTracks} canciones',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white24,
                  size: 20,
                ),
                onPressed: () => _confirmRemove(context),
                tooltip: 'Quitar de carpeta',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
