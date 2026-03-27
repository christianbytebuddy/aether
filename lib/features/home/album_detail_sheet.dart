import 'package:flutter/material.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/firestore_service.dart';

/// Bottom sheet con el detalle completo del álbum.
/// Se abre al tocar la portada o el botón de info.
class AlbumDetailSheet extends StatefulWidget {
  final AlbumModel album;
  final FirestoreService firestoreService;
  final Color bgColor;

  const AlbumDetailSheet({
    super.key,
    required this.album,
    required this.firestoreService,
    required this.bgColor,
  });

  @override
  State<AlbumDetailSheet> createState() => _AlbumDetailSheetState();
}

class _AlbumDetailSheetState extends State<AlbumDetailSheet> {
  bool _isLiked = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.album.isLiked;
  }

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
      if (mounted) setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSaveFolderDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FolderPickerSheet(
        album: widget.album,
        firestoreService: widget.firestoreService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final bgColor = widget.bgColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Portada pequeña + info
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    album.imageUrl,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        album.artist,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Año y duración
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white38,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            album.yearFormatted,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.access_time,
                            color: Colors.white38,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            album.durationFormatted,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Géneros
            if (album.genres.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: album.genres
                    .take(4)
                    .map(
                      (g) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          g,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Botones de acción
            Row(
              children: [
                // Like
                Expanded(
                  child: _ActionButton(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    label: _isLiked ? 'Te gusta' : 'Me gusta',
                    color: _isLiked ? Colors.redAccent : Colors.white70,
                    onTap: _toggleLike,
                  ),
                ),
                const SizedBox(width: 12),
                // Guardar en carpeta
                Expanded(
                  child: _ActionButton(
                    icon: Icons.create_new_folder_outlined,
                    label: 'Guardar',
                    color: Colors.white70,
                    onTap: _showSaveFolderDialog,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tracklist
            Row(
              children: [
                const Icon(Icons.queue_music, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Tracklist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${album.totalTracks} canciones',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...album.tracks.map(
              (track) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${track.trackNumber}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        track.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      track.durationFormatted,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
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
}

/// Botón de acción (like, guardar)
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// Sheet para elegir o crear una carpeta
class _FolderPickerSheet extends StatefulWidget {
  final AlbumModel album;
  final FirestoreService firestoreService;

  const _FolderPickerSheet({
    required this.album,
    required this.firestoreService,
  });

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  final _newFolderController = TextEditingController();

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  Future<void> _createAndSave() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty) return;

    final folderId = await widget.firestoreService.createFolder(name);
    await widget.firestoreService.saveAlbumToFolder(folderId, widget.album);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guardado en "$name"'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guardar en carpeta',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Carpetas existentes
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.firestoreService.foldersStream(),
            builder: (_, snap) {
              final folders = snap.data ?? [];
              if (folders.isEmpty) {
                return const Text(
                  'No tienes carpetas aún',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                );
              }
              return Column(
                children: folders
                    .map(
                      (f) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.folder,
                          color: Color(0xFF7B6EF6),
                        ),
                        title: Text(
                          f['name'] as String,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          await widget.firestoreService.saveAlbumToFolder(
                            f['id'] as String,
                            widget.album,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Guardado en "${f['name']}"'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),

          const Divider(color: Colors.white12),
          const SizedBox(height: 8),

          // Crear carpeta nueva
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newFolderController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nueva carpeta...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _createAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6EF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Crear',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
