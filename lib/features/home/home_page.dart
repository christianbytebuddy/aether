import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'album_card.dart';
import 'package:aether/features/onboarding/onboarding_page.dart';
import 'package:aether/features/home/search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _spotifyService = SpotifyService();
  final _firestoreService = FirestoreService();
  late final PageController _pageController = PageController();

  List<AlbumModel> _albums = [];
  bool _isLoading = true;
  bool _showOnboarding = false;
  String? _error;

  final Map<int, List<Color>> _palettes = {};

  Color _bgTop = const Color(0xFF0B0F1A);
  Color _bgBottom = const Color(0xFF0B0F1A);
  int _currentIndex = 0;

  static const _cacheKey = 'feed_cache';
  static const _cacheTimeKey = 'feed_cache_time';
  static const _cacheDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final completedLocally = prefs.getBool('onboarding_complete') ?? false;

    if (completedLocally) {
      debugPrint('→ Yendo directo al feed');
      _loadFeed();
      return;
    }

    final hasPrefs = await _firestoreService.hasPreferences();
    debugPrint('hasPreferences en Firestore: $hasPrefs');

    if (!mounted) return;

    if (!hasPrefs) {
      debugPrint('→ Mostrando onboarding');
      setState(() {
        _showOnboarding = true;
        _isLoading = false;
      });
    } else {
      debugPrint('→ Guardando flag y cargando feed');
      await prefs.setBool('onboarding_complete', true);
      _loadFeed();
    }
  }

  Future<List<AlbumModel>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey);
      if (cacheTime == null) return null;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(cacheTime);
      if (DateTime.now().difference(savedAt) > _cacheDuration) return null;
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AlbumModel.fromCacheJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToCache(List<AlbumModel> albums) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = albums.map((a) => a.toCacheJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(list));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
    } catch (_) {}
  }

  Future<void> _loadFeed({bool forceRefresh = false}) async {
    if (mounted)
      setState(() {
        _isLoading = true;
        _error = null;
      });
    try {
      List<AlbumModel>? albums;

      if (!forceRefresh) albums = await _loadFromCache();

      if (albums == null) {
        final prefs = await _firestoreService.getPreferences();
        final genres = List<String>.from(prefs['genres'] as List? ?? []);
        final artists = List<String>.from(prefs['artists'] as List? ?? []);

        if (genres.isNotEmpty || artists.isNotEmpty) {
          albums = await _spotifyService.getPersonalizedFeed(
            genres: genres,
            artists: artists,
            limit: 20,
          );
        } else {
          albums = await _spotifyService.getFeed(limit: 10);
        }
        await _saveToCache(albums);
      }

      final likedResults = await Future.wait(
        albums.map((a) => _firestoreService.isAlbumLiked(a.id)),
      );
      for (var i = 0; i < albums.length; i++) {
        albums[i].isLiked = likedResults[i];
      }

      if (mounted) {
        setState(() => _albums = albums!);
        _loadPaletteFor(0);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPaletteFor(int index) async {
    if (_palettes.containsKey(index)) return;
    if (index < 0 || index >= _albums.length) return;
    final url = _albums[index].imageUrl;
    if (url.isEmpty) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(150, 150),
        maximumColorCount: 6,
      );
      if (!mounted) return;
      final colors = [
        generator.vibrantColor?.color ?? const Color(0xFF0B0F1A),
        generator.darkVibrantColor?.color ??
            generator.darkMutedColor?.color ??
            const Color(0xFF0B0F1A),
      ];
      _palettes[index] = colors;
      if (index == _currentIndex) {
        setState(() {
          _bgTop = colors[0];
          _bgBottom = colors[1];
        });
      }
    } catch (_) {}
  }

  void _onPageChanged(int index) {
    _currentIndex = index;
    _loadPaletteFor(index + 1);
    if (_palettes.containsKey(index)) {
      setState(() {
        _bgTop = _palettes[index]![0];
        _bgBottom = _palettes[index]![1];
      });
    } else {
      _loadPaletteFor(index);
    }
  }

  void _openEditPreferences() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.95,
        child: OnboardingPage(
          onComplete: () async {
            Navigator.pop(context);
            await _clearCache();
            _palettes.clear();
            _loadFeed(forceRefresh: true);
          },
          isEditing: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoader();
    if (_error != null) return _buildError();

    if (_showOnboarding) {
      return OnboardingPage(
        onComplete: () async {
          // Guardar que ya completó el onboarding
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_complete', true);
          setState(() => _showOnboarding = false);
          _loadFeed();
        },
      );
    }

    if (_albums.isEmpty) return _buildEmpty();

    return _AnimatedGradientBackground(
      topColor: _bgTop,
      bottomColor: _bgBottom,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _albums.length,
              physics: const ClampingScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (_, index) => AlbumCard(
                album: _albums[index],
                firestoreService: _firestoreService,
                bgColor: _palettes[index] != null
                    ? _palettes[index]![1]
                    : const Color(0xFF0B0F1A),
              ),
            ),

            // ── Logo Aether ───────────────────────────────────────────────
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

            // ── Lupa ──────────────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchPage()),
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white60,
                    size: 18,
                  ),
                ),
              ),
            ),

            // ── Logo Aether ───────────────────────────────────────────────
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

            // ── Botón editar preferencias ─────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: _openEditPreferences,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white60,
                    size: 18,
                  ),
                ),
              ),
            ),

            // ── Botón editar preferencias ─────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: _openEditPreferences,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white60,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0F1A),
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
      backgroundColor: const Color(0xFF0B0F1A),
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
                onPressed: () => _loadFeed(forceRefresh: true),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.music_off_rounded,
                color: Colors.white24,
                size: 52,
              ),
              const SizedBox(height: 16),
              const Text(
                'No encontramos álbumes\npara tus gustos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prueba cambiando tus géneros o artistas favoritos',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _openEditPreferences,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B6EF6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Cambiar preferencias',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _loadFeed(forceRefresh: true),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedGradientBackground extends ImplicitlyAnimatedWidget {
  final Color topColor;
  final Color bottomColor;
  final Widget child;

  const _AnimatedGradientBackground({
    required this.topColor,
    required this.bottomColor,
    required this.child,
  }) : super(
         duration: const Duration(milliseconds: 600),
         curve: Curves.easeInOut,
       );

  @override
  ImplicitlyAnimatedWidgetState<_AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends AnimatedWidgetBaseState<_AnimatedGradientBackground> {
  ColorTween? _topTween;
  ColorTween? _bottomTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _topTween =
        visitor(
              _topTween,
              widget.topColor,
              (value) => ColorTween(begin: value as Color),
            )
            as ColorTween?;

    _bottomTween =
        visitor(
              _bottomTween,
              widget.bottomColor,
              (value) => ColorTween(begin: value as Color),
            )
            as ColorTween?;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _topTween?.evaluate(animation) ?? widget.topColor,
            _bottomTween?.evaluate(animation) ?? widget.bottomColor,
          ],
        ),
      ),
      child: widget.child,
    );
  }
}
