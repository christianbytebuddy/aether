import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/services/spotify_auth_service.dart';

class PulsePage extends StatefulWidget {
  const PulsePage({super.key});

  @override
  State<PulsePage> createState() => _PulsePageState();
}

class _PulsePageState extends State<PulsePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _spotifyAuth = SpotifyAuthService();

  bool _spotifyConnected = false;
  bool _loading = false;

  List<Map<String, dynamic>> _topTracks = [];
  List<Map<String, dynamic>> _topArtists = [];
  List<Map<String, dynamic>> _recentlyPlayed = [];
  Map<String, int> _cachedArtistMins = {};

  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);
  static const _accent = Color(0xFF7B6EF6);
  static const _pink = Color(0xFFE91E8C);

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await _spotifyAuth.isConnected();
    if (mounted) setState(() => _spotifyConnected = connected);
    if (connected) _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _spotifyAuth.getTopTracks(),
        _spotifyAuth.getTopArtists(),
        _spotifyAuth.getRecentlyPlayed(),
      ]);
      if (mounted) {
        setState(() {
          _topTracks = List<Map<String, dynamic>>.from(results[0]);
          _topArtists = List<Map<String, dynamic>>.from(results[1]);
          _recentlyPlayed = List<Map<String, dynamic>>.from(results[2]);
          _cachedArtistMins = {};
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectSpotify() async {
    final success = await _spotifyAuth.connectSpotify();
    if (success && mounted) {
      setState(() => _spotifyConnected = true);
      _loadData();
    }
  }

  // ── Cálculos ──────────────────────────────────────────────────────────────

  int _totalMinutes() {
    if (_recentlyPlayed.isEmpty) return 0;
    final total = _recentlyPlayed.fold<int>(
      0,
      (sum, t) => sum + (t['durationMs'] as int),
    );
    return (total / 60000).round();
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }

  Map<String, int> _artistMinutes() {
    if (_cachedArtistMins.isNotEmpty) return _cachedArtistMins;
    final map = <String, int>{};
    for (int i = 0; i < _topArtists.length; i++) {
      final name = _topArtists[i]['name'] as String;
      map[name] = (100 - i * 8).clamp(20, 100);
    }
    _cachedArtistMins = map;
    return map;
  }

  double _artistPercent(String artist) {
    final top3Names = _topArtists
        .take(3)
        .map((a) => a['name'] as String)
        .toList();
    final map = _artistMinutes();
    final top3Total = top3Names.fold<int>(
      0,
      (sum, name) => sum + (map[name] ?? 0),
    );
    if (top3Total == 0) return 0;
    return (map[artist] ?? 0) / top3Total;
  }

  String _topDay() {
    if (_recentlyPlayed.isEmpty) return 'Sin datos';
    const days = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
    ];
    final freq = <int, int>{};
    for (final t in _recentlyPlayed) {
      final playedAt = t['playedAt'] as String;
      final day = DateTime.parse(playedAt).toLocal().weekday % 7;
      freq[day] = (freq[day] ?? 0) + 1;
    }
    final top = freq.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return days[top];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: !_spotifyConnected
            ? _buildConnectScreen()
            : _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : _buildTracker(),
      ),
    );
  }

  Widget _buildConnectScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: _accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aether Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Conecta Spotify para ver tu resumen musical real',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _connectSpotify,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Conectar Spotify',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTracker() {
    final totalMinutes = _totalMinutes();
    final artistMins = _artistMinutes();
    final topArtistNames = _topArtists
        .take(3)
        .map((a) => a['name'] as String)
        .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          backgroundColor: _bg,
          floating: true,
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: _accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aether Tracker',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Tu resumen musical',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white38,
                size: 20,
              ),
              onPressed: _loadData,
            ),
            IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.white24,
                size: 18,
              ),
              onPressed: () async {
                await _spotifyAuth.disconnect();
                if (mounted) setState(() => _spotifyConnected = false);
              },
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildTimeCard(totalMinutes),
              const SizedBox(height: 16),
              _buildSectionTitle('Top Canciones', Icons.music_note_outlined),
              const SizedBox(height: 10),
              ..._topTracks
                  .take(5)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) => _buildTrackTile(entry.key + 1, entry.value)),
              const SizedBox(height: 20),
              _buildSectionTitle('Top Artistas', Icons.mic_none_outlined),
              const SizedBox(height: 10),
              ...topArtistNames.map((name) {
                final artist = _topArtists.firstWhere(
                  (a) => a['name'] == name,
                  orElse: () => <String, dynamic>{'name': name, 'imageUrl': ''},
                );
                final weight = artistMins[name] ?? 0;
                final total = artistMins.values.fold<int>(0, (a, b) => a + b);
                final percent = total > 0 ? weight / total : 0.0;
                return _buildArtistTile(artist, weight, percent);
              }),
              const SizedBox(height: 20),
              if (topArtistNames.isNotEmpty) ...[
                _buildSectionTitle(
                  'Distribución de escucha',
                  Icons.bar_chart_rounded,
                ),
                const SizedBox(height: 10),
                _buildDistributionCard(topArtistNames, artistMins),
                const SizedBox(height: 20),
              ],
              _buildDayCard(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCard(int totalMinutes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 2),
            ),
            child: const Icon(Icons.bolt_rounded, color: _accent, size: 28),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tiempo total de escucha',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                totalMinutes > 0 ? _formatMinutes(totalMinutes) : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Últimas 50 reproducciones',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackTile(int rank, Map<String, dynamic> track) {
    final name = track['name'] as String;
    final artist = track['artist'] as String;
    final durationMs = track['durationMs'] as int;
    final imageUrl = track['imageUrl'] as String? ?? '';
    final mins = durationMs ~/ 60000;
    final secs = (durationMs % 60000) ~/ 1000;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: _accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 44,
                  height: 44,
                  memCacheWidth: 88,
                  memCacheHeight: 88,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFF1C1F2E),
                  ),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F2E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.white24,
                  size: 20,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${mins}m ${secs.toString().padLeft(2, '0')}s',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistTile(
    Map<String, dynamic> artist,
    int minutes,
    double percent,
  ) {
    final name = artist['name'] as String;
    final imageUrl = artist['imageUrl'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 48,
                      height: 48,
                      memCacheWidth: 96,
                      memCacheHeight: 96,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFF1C1F2E),
                      child: const Icon(Icons.person, color: Colors.white24),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percent > 0.25 ? _accent : _pink,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  minutes > 0 ? '${minutes}m' : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(percent * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionCard(
    List<String> artists,
    Map<String, int> artistMins,
  ) {
    final total = artistMins.values.fold<int>(0, (a, b) => a + b);
    final top3Total = artists.fold<int>(
      0,
      (sum, name) => sum + (artistMins[name] ?? 0),
    );
    final othersMs = total - top3Total;
    final othersPercent = total > 0 ? othersMs / total : 0.0;

    final colors = [_accent, _pink, Colors.orangeAccent, Colors.white38];
    final allNames = [...artists, if (othersPercent > 0.01) 'Otros'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  ...artists.asMap().entries.map((e) {
                    final p = total > 0
                        ? (artistMins[e.value] ?? 0) / total
                        : 0.0;
                    return Flexible(
                      flex: (p * 100).round(),
                      child: Container(color: colors[e.key % colors.length]),
                    );
                  }),
                  if (othersPercent > 0.01)
                    Flexible(
                      flex: (othersPercent * 100).round(),
                      child: Container(color: Colors.white24),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: allNames.asMap().entries.map((e) {
              final isOthers = e.value == 'Otros';
              final p = isOthers
                  ? othersPercent
                  : total > 0
                  ? (artistMins[e.value] ?? 0) / total
                  : 0.0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOthers
                          ? Colors.white24
                          : colors[e.key % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.value} ${(p * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard() {
    final day = _topDay();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pink.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _pink.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: _pink,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu día más activo',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                day,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
