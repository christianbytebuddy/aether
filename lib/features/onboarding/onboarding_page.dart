import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:aether/services/spotify_service.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isEditing;
  const OnboardingPage({
    super.key,
    required this.onComplete,
    this.isEditing = false,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _firestoreService = FirestoreService();
  final _spotifyService = SpotifyService();
  final _pageController = PageController();
  final _searchController = TextEditingController();

  int _currentPage = 0;
  bool _isSaving = false;
  bool _isSearching = false;

  final Set<String> _selectedGenres = {};
  final Set<String> _selectedArtists = {};
  List<Map<String, dynamic>> _searchResults = [];

  static const _accent = Color(0xFF7B6EF6);
  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);

  static const _genres = [
    {'name': 'K-Pop', 'emoji': '🎵', 'query': 'k-pop'},
    {'name': 'Pop', 'emoji': '⭐', 'query': 'pop'},
    {'name': 'Hip-Hop', 'emoji': '🎤', 'query': 'hip-hop'},
    {'name': 'R&B', 'emoji': '🎶', 'query': 'r&b'},
    {'name': 'Rock', 'emoji': '🎸', 'query': 'rock'},
    {'name': 'Electrónica', 'emoji': '🎧', 'query': 'electronic'},
    {'name': 'Reggaeton', 'emoji': '🔥', 'query': 'reggaeton'},
    {'name': 'Jazz', 'emoji': '🎷', 'query': 'jazz'},
    {'name': 'Clásica', 'emoji': '🎻', 'query': 'classical'},
    {'name': 'Latin', 'emoji': '💃', 'query': 'latin'},
    {'name': 'Indie', 'emoji': '🌿', 'query': 'indie'},
    {'name': 'Metal', 'emoji': '⚡', 'query': 'metal'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchArtists(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    try {
      final results = await _spotifyService.searchArtists(query.trim());
      if (mounted)
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _nextPage() {
    if (_currentPage == 1 &&
        _selectedGenres.isEmpty &&
        _selectedArtists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige al menos un género o artista'),
          backgroundColor: Color(0xFF1C1F2E),
        ),
      );
      return;
    }
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _firestoreService.savePreferences(
        genres: _selectedGenres.toList(),
        artistNames: _selectedArtists.toList(),
      );
      widget.onComplete();
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildNavButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          if (_currentPage > 0)
            GestureDetector(
              onTap: _prevPage,
              child: Container(
                width: 48,
                height: 52,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: _currentPage == 2 ? _save : _nextPage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _currentPage == 2 ? '¡Empezar!' : 'Continuar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 6),
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= _currentPage ? _accent : Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Páginas ───────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildGenresPage(),
                  _buildArtistsPage(),
                  _buildReadyPage(),
                ],
              ),
            ),

            // ── Botones — se ocultan cuando el teclado está visible ───────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: MediaQuery.of(context).viewInsets.bottom > 0
                  ? const SizedBox.shrink()
                  : _buildNavButtons(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Página 1: Géneros ─────────────────────────────────────────────────────

  Widget _buildGenresPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isEditing
                ? 'Actualiza tus\ngéneros favoritos'
                : '¿Qué música\nte mueve?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Opcional — puedes saltar este paso',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: _genres.length,
              itemBuilder: (_, i) {
                final genre = _genres[i];
                final name = genre['name'] as String;
                final emoji = genre['emoji'] as String;
                final selected = _selectedGenres.contains(name);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedGenres.remove(name);
                    } else {
                      _selectedGenres.add(name);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? _accent : _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? _accent : Colors.white10,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Página 2: Artistas ────────────────────────────────────────────────────

  Widget _buildArtistsPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isEditing
                ? 'Actualiza tus\nartistas favoritos'
                : '¿Quiénes son\ntus artistas?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Opcional — puedes saltar este paso',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: _searchArtists,
            decoration: InputDecoration(
              hintText: 'Busca un artista...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: _card,
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white38,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_selectedArtists.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedArtists
                  .map(
                    (name) => GestureDetector(
                      onTap: () =>
                          setState(() => _selectedArtists.remove(name)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.close,
                              color: Colors.white70,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 2,
                    ),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mic_none_rounded,
                          color: Colors.white12,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Busca tus artistas favoritos'
                              : 'Sin resultados',
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final artist = _searchResults[i];
                      final name = artist['name'] as String? ?? '';
                      final imageUrl = artist['imageUrl'] as String? ?? '';
                      final isSelected = _selectedArtists.contains(name);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedArtists.remove(name);
                          } else {
                            _selectedArtists.add(name);
                          }
                          _searchController.clear();
                          _searchResults = [];
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accent.withOpacity(0.15)
                                : _card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? _accent : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const ColoredBox(
                                    color: Color(0xFF1C1F2E),
                                  ),
                                  errorWidget: (_, __, ___) => const ColoredBox(
                                    color: Color(0xFF1C1F2E),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                color: isSelected ? _accent : Colors.white24,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Página 3: Listo ───────────────────────────────────────────────────────

  Widget _buildReadyPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.headphones_rounded,
                color: _accent,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              '¡Todo listo!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Tu feed está personalizado\nbased en tus gustos musicales.\n¡Descubre música hecha para ti!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TUS PREFERENCIAS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._selectedGenres.map(
                      (g) => _PreferenceChip(label: g, color: _accent),
                    ),
                    ..._selectedArtists.map(
                      (a) => _PreferenceChip(label: a, color: Colors.white24),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _PreferenceChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PreferenceChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == Colors.white24 ? Colors.white60 : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
