import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/firestore_service.dart';
import 'album_detail_sheet.dart';

/// Card de álbum estilo TikTok — ocupa toda la pantalla.
/// Extrae los colores dominantes de la portada y los usa como fondo.
class AlbumCard extends StatefulWidget {
  final AlbumModel album;
  final FirestoreService firestoreService;

  const AlbumCard({
    super.key,
    required this.album,
    required this.firestoreService,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard>
    with AutomaticKeepAliveClientMixin {
  // ── Colores dinámicos ──────────────────────────────────────────────────────
  Color _bgTop = const Color(0xFF0B0F1A);
  Color _bgBottom = const Color(0xFF1C1F2E);
  bool _colorsLoaded = false;

  // ── Estado del álbum ───────────────────────────────────────────────────────
  late bool _isLiked;
  bool _isProcessing = false;

  @override
  bool get wantKeepAlive => true; // Evita reconstruir al volver al slide

  @override
  void initState() {
    super.initState();
    _isLiked = widget.album.isLiked;
    _loadPalette();
  }

  // ── Extrae colores de la portada ──────────────────────────────────────────
  Future<void> _loadPalette() async {
    if (widget.album.imageUrl.isEmpty) return;

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(widget.album.imageUrl),
        size: const Size(200, 200), // Escala pequeña = más rápido en J2
        maximumColorCount: 8,
      );

      if (!mounted) return;

      // Prioridad de color: vibrant → dominant → fallback
      final top =
          generator.vibrantColor?.color ??
          generator.dominantColor?.color ??
          const Color(0xFF0B0F1A);

      final bottom =
          generator.darkVibrantColor?.color ??
          generator.darkMutedColor?.color ??
          const Color(0xFF1C1F2E);

      setState(() {
        _bgTop = top.withOpacity(0.85);
        _bgBottom = bottom;
        _colorsLoaded = true;
      });
    } catch (_) {
      // Si falla la paleta, se queda con el color por defecto — sin crash
    }
  }

  // ── Like ──────────────────────────────────────────────────────────────────
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
      // Revierte si falla
      if (mounted) setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Abre el detalle del álbum ─────────────────────────────────────────────
  void _openDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlbumDetailSheet(
        album: widget.album,
        firestoreService: widget.firestoreService,
        bgColor: _bgBottom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom, Colors.black],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // ── Portada centrada ───────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: _openDetail,
              child: Hero(
                tag: 'album_${widget.album.id}',
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _bgTop.withOpacity(0.6),
                        blurRadius: 40,
                        spreadRadius: 10,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: widget.album.imageUrl,
                      fit: BoxFit.cover,
                      // Placeholder liviano — sin shimmer para ahorrar GPU
                      placeholder: (_, __) => const AspectRatio(
                        aspectRatio: 1,
                        child: ColoredBox(color: Color(0xFF1C1F2E)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF1C1F2E),
                        child: const Icon(
                          Icons.album,
                          color: Colors.white24,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Info del álbum centrada (CORREGIDO) ─────────────────────────────────────────
          Positioned(
            left: 20,
            right: 20, // Ahora ocupa todo el ancho para poder centrar el Column
            bottom: 80,
            child: GestureDetector(
              onTap: _openDetail,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Centrado horizontal
                children: [
                  Text(
                    widget.album.name,
                    textAlign: TextAlign.center, // Texto centrado si hay wrap
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.album.artist,
                    textAlign: TextAlign.center, // Texto centrado
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  // Géneros como chips (Centrados)
                  if (widget.album.genres.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      alignment: WrapAlignment.center, // Chips centrados
                      children: widget.album.genres
                          .take(3)
                          .map(
                            (g) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                g,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),

          // ── Botones laterales derechos (estilo TikTok) ─────────────────────
          // Sigue en la misma posición, pero el Positioned de la info ya no lo tiene en cuenta.

          // ── Hint de swipe (solo si los colores aún no cargaron) ────────────
          if (!_colorsLoaded)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón lateral estilo TikTok
class _SideButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SideButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}
