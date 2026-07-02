import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:aether/features/echo/echo_game_page.dart';

class EchoPage extends StatefulWidget {
  const EchoPage({super.key});

  @override
  State<EchoPage> createState() => _EchoPageState();
}

class _EchoPageState extends State<EchoPage> {
  final _spotify = SpotifyService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedArtists = [];
  bool _isSearching = false;
  bool _isLoadingSuggested = true;

  static const _bg = Color(0xFF0B0F1A);
  static const _accent = Color(0xFF7B6EF6);
  static const _card = Color(0xFF111827);

  // Artistas sugeridos — ahora solo nombre, sin IDs de Deezer
  static const _suggestedNames = ['TWICE', 'NewJeans', 'Stray Kids'];

  @override
  void initState() {
    super.initState();
    _loadSuggested();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggested() async {
    try {
      final results = await Future.wait(
        _suggestedNames.map((name) async {
          final found = await _spotify.searchArtists(name);
          if (found.isEmpty) return null;
          // Tomamos el primer resultado exacto o el primero disponible
          final match = found.firstWhere(
            (a) => (a['name'] as String).toLowerCase() == name.toLowerCase(),
            orElse: () => found.first,
          );
          return <String, dynamic>{
            'id': match['id'],
            'name': match['name'],
            'imageUrl': match['imageUrl'],
            'deezerArtistId': '',
          };
        }),
      );

      if (mounted) {
        setState(() {
          _suggestedArtists = results
              .whereType<Map<String, dynamic>>()
              .toList();
          _isLoadingSuggested = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSuggested = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    try {
      final results = await _spotify.searchArtists(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _startGame(Map<String, dynamic> artist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DifficultySheet(
        artist: artist,
        onSelect: (seconds) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EchoGamePage(
                artist: artist,
                spotify: _spotify,
                secondsPerRound: seconds,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ECHO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Elige un artista para empezar',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Busca tu artista favorito',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: _card,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white38,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : _buildSuggested(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggested() {
    if (_isLoadingSuggested) {
      return const Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Artistas sugeridos',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: _suggestedArtists
                .map(
                  (artist) => _ArtistTile(
                    artist: artist,
                    onTap: () => _startGame(artist),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('Sin resultados', style: TextStyle(color: Colors.white24)),
      );
    }
    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final artist = _searchResults[i];
        return GestureDetector(
          onTap: () => _startGame(artist),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: artist['imageUrl'] as String? ?? '',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFF1C1F2E)),
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF1C1F2E)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    artist['name'] as String? ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Artista tile ──────────────────────────────────────────────────────────────

class _ArtistTile extends StatelessWidget {
  final Map<String, dynamic> artist;
  final VoidCallback onTap;

  const _ArtistTile({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: artist['imageUrl'] as String? ?? '',
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const ColoredBox(color: Color(0xFF1C1F2E)),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF1C1F2E)),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Text(
                artist['name'] as String? ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal de dificultad ───────────────────────────────────────────────────────

class _DifficultySheet extends StatelessWidget {
  final Map<String, dynamic> artist;
  final void Function(int seconds) onSelect;

  const _DifficultySheet({required this.artist, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            artist['name'] as String? ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Elige la dificultad',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _DifficultyOption(
            label: 'Fácil',
            description: '10 segundos por canción',
            emoji: '😌',
            color: Colors.greenAccent,
            onTap: () => onSelect(10),
          ),
          const SizedBox(height: 12),
          _DifficultyOption(
            label: 'Intermedio',
            description: '8 segundos por canción',
            emoji: '🎯',
            color: const Color(0xFF7B6EF6),
            onTap: () => onSelect(8),
          ),
          const SizedBox(height: 12),
          _DifficultyOption(
            label: 'Difícil',
            description: '5 segundos por canción',
            emoji: '🔥',
            color: Colors.redAccent,
            onTap: () => onSelect(5),
          ),
        ],
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  final String label;
  final String description;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyOption({
    required this.label,
    required this.description,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
