import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:aether/features/echo/echo_game_page.dart';

class EchoResultPage extends StatelessWidget {
  final Map<String, dynamic> artist;
  final int score;
  final int total;
  final SpotifyService spotify;

  const EchoResultPage({
    super.key,
    required this.artist,
    required this.score,
    required this.total,
    required this.spotify,
  });

  static const _accent = Color(0xFF7B6EF6);
  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);

  String _getMessage() {
    final pct = score / total;
    if (pct == 1.0) return '¡Eres un fan legendario! 🏆';
    if (pct >= 0.8) return '¡Casi perfecto, sigue así!';
    if (pct >= 0.6) return 'No está mal, ¡sigue escuchando!';
    if (pct >= 0.4) return 'Aún queda música por descubrir 🎵';
    return 'Parece que debes escuchar más...';
  }

  // Porcentaje inventado divertido basado en score
  String _getFanPercentage() {
    // Cuanto más aciertas, mejor ranking
    const percentages = [
      'Top 82%',
      'Top 65%',
      'Top 48%',
      'Top 22%',
      'Top 8%',
      'Top 1%',
    ];
    return percentages[score.clamp(0, 5)];
  }

  @override
  Widget build(BuildContext context) {
    final artistName = artist['name'] as String? ?? '';
    final imageUrl = artist['imageUrl'] as String? ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // ── Trofeo ───────────────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _accent,
                  size: 54,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                '¡Ronda completada!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _getMessage(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),

              const SizedBox(height: 32),

              // ── Stats card ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Aciertos + porcentaje
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$score/$total',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'ACIERTOS',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.white12),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _getFanPercentage(),
                                style: const TextStyle(
                                  color: _accent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'DE FANS',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),

                    // Artista
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const ColoredBox(color: Color(0xFF1C1F2E)),
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: Color(0xFF1C1F2E)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artistName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Artista',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Indicadores de ronda (círculos) ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  total,
                  (i) => Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < score ? _accent : Colors.white12,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // ── Botones ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EchoGamePage(artist: artist, spotify: spotify),
                          ),
                          (route) => route.isFirst,
                        );
                        // En realidad queremos ir al EchoGamePage — pop dos veces y push
                        Navigator.popUntil(context, (r) => r.isFirst);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Jugar de nuevo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.popUntil(context, (r) => r.isFirst),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Otro artista',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
