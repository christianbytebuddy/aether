import 'package:flutter/material.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:aether/services/firestore_service.dart';
import 'album_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _spotifyService = SpotifyService();
  final _firestoreService = FirestoreService();

  List<AlbumModel> _albums = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final albums = await _spotifyService.getFeed(limit: 10);

      for (final album in albums) {
        album.isLiked = await _firestoreService.isAlbumLiked(album.id);
      }

      if (mounted) setState(() => _albums = albums);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoader();
    if (_error != null) return _buildError();
    if (_albums.isEmpty) return _buildEmpty();

    return Scaffold(
      backgroundColor: Colors.black,

      // ❌ SIN APPBAR
      // ✅ DISEÑO FULLSCREEN + FLOATING TITLE
      body: Stack(
        children: [
          // 🔄 FEED (NO CAMBIA)
          RefreshIndicator(
            onRefresh: _loadFeed,
            color: const Color(0xFF7B6EF6),
            backgroundColor: Colors.black,
            child: PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _albums.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (_, index) => AlbumCard(
                album: _albums[index],
                firestoreService: _firestoreService,
              ),
            ),
          ),

          // ✨ TÍTULO "AETHER" FLOTANTE (IGUAL A LA IMAGEN)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Aether',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7B6EF6), strokeWidth: 2),
            SizedBox(height: 16),
            Text(
              'Cargando tu feed...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white38, size: 48),
              const SizedBox(height: 16),
              const Text(
                'No se pudo cargar el feed',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadFeed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6EF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'No hay álbumes disponibles',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}
