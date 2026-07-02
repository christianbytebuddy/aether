import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:aether/features/home/album_detail_sheet.dart';
import 'package:aether/features/community/post_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _spotify = SpotifyService();
  final _firestore = FirestoreService();
  Timer? _debounce;

  List<AlbumModel> _albums = [];
  List<Map<String, dynamic>> _posts = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);
  static const _accent = Color(0xFF7B6EF6);

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _albums = [];
          _posts = [];
          _hasSearched = false;
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    try {
      // Álbumes y posts en paralelo
      final results = await Future.wait([
        _spotify.searchAlbums(query.trim()),
        _firestore.searchPosts(query.trim()),
      ]);

      if (!mounted) return;
      setState(() {
        _albums = results[0] as List<AlbumModel>;
        _posts = results[1] as List<Map<String, dynamic>>;
        _isSearching = false;
        _hasSearched = true;
      });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      onChanged: _onChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar álbumes o posts...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: _card,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white38,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _onChanged('');
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // ── Resultados ────────────────────────────────────────────────
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _accent,
                        strokeWidth: 2,
                      ),
                    )
                  : !_hasSearched
                  ? _buildEmptyState()
                  : (_albums.isEmpty && _posts.isEmpty)
                  ? _buildNoResults()
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search, color: Colors.white12, size: 52),
          const SizedBox(height: 16),
          const Text(
            'Busca álbumes o posts\nde la comunidad',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_off_rounded, color: Colors.white12, size: 52),
          const SizedBox(height: 16),
          Text(
            'Sin resultados para\n"${_searchController.text}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Álbumes ──────────────────────────────────────────────────────
        if (_albums.isNotEmpty) ...[
          _buildSectionHeader('Álbumes', _albums.length),
          const SizedBox(height: 10),
          ..._albums.take(8).map((album) => _buildAlbumTile(album)),
          const SizedBox(height: 24),
        ],

        // ── Posts ─────────────────────────────────────────────────────────
        if (_posts.isNotEmpty) ...[
          _buildSectionHeader('Posts de comunidad', _posts.length),
          const SizedBox(height: 10),
          ..._posts.take(8).map((post) => _buildPostTile(post)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumTile(AlbumModel album) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AlbumDetailSheet(
          album: album,
          firestoreService: _firestore,
          bgColor: const Color(0xFF1C1F2E),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: album.imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const ColoredBox(color: Color(0xFF1C1F2E)),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF1C1F2E)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTile(Map<String, dynamic> post) {
    final title = post['title'] as String? ?? '';
    final username = post['username'] as String? ?? 'Usuario';
    final rawAlbums = (post['albums'] as List<dynamic>?) ?? [];
    final firstImage = rawAlbums.isNotEmpty
        ? (rawAlbums.first as Map<String, dynamic>)['imageUrl'] as String? ?? ''
        : '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PostDetailPage(post: post, firestoreService: _firestore),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Miniatura del primer álbum del post
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: firstImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: firstImage,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFF1C1F2E)),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF1C1F2E)),
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFF1C1F2E),
                      child: const Icon(
                        Icons.people_outline,
                        color: Colors.white24,
                        size: 22,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'por $username',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
