import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/firestore_service.dart';
import 'album_detail_sheet.dart';

class AlbumCard extends StatefulWidget {
  final AlbumModel album;
  final FirestoreService firestoreService;
  final Color bgColor;

  const AlbumCard({
    super.key,
    required this.album,
    required this.firestoreService,
    required this.bgColor,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _openDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlbumDetailSheet(
        album: widget.album,
        firestoreService: widget.firestoreService,
        bgColor: widget.bgColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final cardSize = MediaQuery.of(context).size.width * 0.78;

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Portada ────────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: widget.album.imageUrl,
                  width: cardSize,
                  height: cardSize,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    width: cardSize,
                    height: cardSize,
                    color: Colors.black26,
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: cardSize,
                    height: cardSize,
                    color: Colors.black26,
                    child: const Icon(
                      Icons.album,
                      color: Colors.white24,
                      size: 48,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Título ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.album.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 8),

              // ── Artista ────────────────────────────────────────────────
              Text(
                widget.album.artist,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              // ── Desliza ────────────────────────────────────────────────
              Text(
                '¡Desliza!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
