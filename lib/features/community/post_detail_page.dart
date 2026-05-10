import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:aether/features/home/album_detail_sheet.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:aether/core/user_avatar.dart';

const _adminUids = {'E4Sqmc5kOfQq6WvfFc52O3T3mDZ2'};

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final FirestoreService firestoreService;

  const PostDetailPage({
    super.key,
    required this.post,
    required this.firestoreService,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _spotifyService = SpotifyService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSendingComment = false;
  bool _isTogglingLike = false;

  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);
  static const _accent = Color(0xFF7B6EF6);

  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isAdmin => _adminUids.contains(_uid);

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(String postId, bool isLiked) async {
    if (_isTogglingLike) return;
    _isTogglingLike = true;
    try {
      await widget.firestoreService.togglePostLike(postId, isLiked);
    } catch (e) {
      debugPrint('ERROR en toggleLike: $e');
    } finally {
      _isTogglingLike = false;
    }
  }

  Future<void> _sendComment(String postId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment) return;
    setState(() => _isSendingComment = true);
    try {
      await widget.firestoreService.addComment(postId: postId, text: text);
      _commentController.clear();
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  void _showOptionsMenu(
    BuildContext context,
    String postId,
    String currentTitle,
    String currentDescription,
    String postOwnerUid,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (_uid == postOwnerUid)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.white70),
                title: const Text(
                  'Editar publicación',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditSheet(
                    context,
                    postId,
                    currentTitle,
                    currentDescription,
                  );
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Eliminar publicación',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, postId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    String postId,
    String currentTitle,
    String currentDescription,
  ) {
    final titleCtrl = TextEditingController(text: currentTitle);
    final descCtrl = TextEditingController(text: currentDescription);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                const Text(
                  'Editar publicación',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Título',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1C1F2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Descripción',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1C1F2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: isSaving
                        ? null
                        : () async {
                            if (titleCtrl.text.trim().isEmpty) return;
                            setModal(() => isSaving = true);
                            try {
                              await widget.firestoreService.updatePost(
                                postId: postId,
                                title: titleCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                              );
                              if (mounted) Navigator.pop(ctx);
                            } finally {
                              if (mounted) setModal(() => isSaving = false);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Guardar cambios',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar publicación',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          '¿Estás seguro? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.firestoreService.deletePost(postId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(
    BuildContext context,
    String postId,
    String commentId,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar comentario',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          '¿Eliminar este comentario?',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.firestoreService.deleteComment(
                postId: postId,
                commentId: commentId,
              );
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} days ago';
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.post['id'] as String;

    return StreamBuilder<Map<String, dynamic>>(
      stream: widget.firestoreService.postStream(postId),
      builder: (context, snapshot) {
        final post = snapshot.data ?? widget.post;
        final username = post['username'] as String? ?? 'Usuario';
        final avatarLetter = post['avatarLetter'] as String? ?? 'U';
        final photoBase64 = post['photoBase64'] as String?;
        final title = post['title'] as String? ?? '';
        final description = post['description'] as String? ?? '';
        final rawAlbums = (post['albums'] as List<dynamic>?) ?? [];
        final likedBy = List<String>.from(post['likedBy'] ?? []);
        final likesCount = (post['likes'] as int?) ?? 0;
        final isLiked = likedBy.contains(_uid);
        final postOwnerUid = post['uid'] as String? ?? '';

        return Scaffold(
          backgroundColor: _bg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                      const Spacer(),
                      if (_uid == postOwnerUid || _isAdmin) ...[
                        GestureDetector(
                          onTap: () => _showOptionsMenu(
                            context,
                            postId,
                            title,
                            description,
                            postOwnerUid,
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          UserAvatar(
                            photoBase64: photoBase64,
                            letter: avatarLetter,
                            radius: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Contenido scrollable ──────────────────────────────────
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // ── Me gusta ──────────────────────────────────────
                      InkWell(
                        onTap: _isTogglingLike
                            ? null
                            : () => _toggleLike(postId, isLiked),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? _accent : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Me gusta',
                                style: TextStyle(
                                  color: isLiked ? _accent : Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_formatCount(likesCount)} Likes',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Álbumes ──────────────────────────────────────────
                      ...rawAlbums.map((raw) {
                        final albumData = raw as Map<String, dynamic>;
                        final album = AlbumModel(
                          id: albumData['id'] as String? ?? '',
                          name: albumData['name'] as String? ?? '',
                          artist: albumData['artist'] as String? ?? '',
                          imageUrl: albumData['imageUrl'] as String? ?? '',
                          year: 0,
                          totalTracks: 0,
                          durationMs: 0,
                          genres: [],
                          tracks: [],
                        );

                        return GestureDetector(
                          onTap: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF7B6EF6),
                                ),
                              ),
                            );
                            try {
                              final fullAlbum = await _spotifyService
                                  .getAlbumById(album.id);
                              if (context.mounted) {
                                Navigator.pop(context);
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => AlbumDetailSheet(
                                    album: fullAlbum,
                                    firestoreService: widget.firestoreService,
                                    bgColor: const Color(0xFF1C1F2E),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: FutureBuilder<double>(
                              future: widget.firestoreService.getRating(
                                album.id,
                              ),
                              builder: (context, snap) {
                                final rating = snap.data ?? 0.0;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: album.imageUrl,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => const ColoredBox(
                                          color: Color(0xFF1C1F2E),
                                        ),
                                        errorWidget: (_, _, _) =>
                                            const ColoredBox(
                                              color: Color(0xFF1C1F2E),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                          const SizedBox(height: 2),
                                          Text(
                                            album.artist,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (i) => Icon(
                                                i < rating
                                                    ? Icons.star_rounded
                                                    : Icons
                                                          .star_outline_rounded,
                                                color: i < rating
                                                    ? Colors.white70
                                                    : Colors.white24,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // ── Comentarios ──────────────────────────────────────
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: widget.firestoreService.commentsStream(postId),
                        builder: (context, snapshot) {
                          final comments = snapshot.data ?? [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Comentarios',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_formatCount(comments.length)} Comentarios',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...comments.map((c) => _buildComment(c, postId)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // ── Input comentario ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: _card,
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: '¿Qué opinas de este post?',
                            hintStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _sendComment(postId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: _isSendingComment
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Comentar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComment(Map<String, dynamic> comment, String postId) {
    final avatarLetter = comment['avatarLetter'] as String? ?? 'U';
    final username = comment['username'] as String? ?? 'Usuario';
    final text = comment['text'] as String? ?? '';
    final createdAt = comment['createdAt'];
    final commentId = comment['id'] as String? ?? '';
    final commentOwnerUid = comment['uid'] as String? ?? '';
    final photoBase64 = comment['photoBase64'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            photoBase64: photoBase64,
            letter: avatarLetter,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(createdAt),
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    if (_uid == commentOwnerUid || _isAdmin)
                      GestureDetector(
                        onTap: () =>
                            _confirmDeleteComment(context, postId, commentId),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white24,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
