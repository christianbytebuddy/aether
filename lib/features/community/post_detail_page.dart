import 'dart:async';
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
    setState(() => _isTogglingLike = true);
    try {
      await widget.firestoreService.togglePostLike(postId, isLiked);
    } catch (e) {
      debugPrint('ERROR en toggleLike: $e');
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
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
    List<dynamic> currentAlbums,
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
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _EditPostSheet(
                      firestoreService: widget.firestoreService,
                      postId: postId,
                      initialTitle: currentTitle,
                      initialDescription: currentDescription,
                      initialAlbums: currentAlbums
                          .map(
                            (a) => AlbumModel(
                              id:
                                  (a as Map<String, dynamic>)['id']
                                      as String? ??
                                  '',
                              name: a['name'] as String? ?? '',
                              artist: a['artist'] as String? ?? '',
                              imageUrl: a['imageUrl'] as String? ?? '',
                              year: 0,
                              totalTracks: 0,
                              durationMs: 0,
                              genres: [],
                              tracks: [],
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            if (_uid == postOwnerUid || _isAdmin)
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
                            rawAlbums,
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
                                        placeholder: (_, __) =>
                                            const ColoredBox(
                                              color: Color(0xFF1C1F2E),
                                            ),
                                        errorWidget: (_, __, ___) =>
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

// ── Sheet de edición completa ─────────────────────────────────────────────────

class _EditPostSheet extends StatefulWidget {
  final FirestoreService firestoreService;
  final String postId;
  final String initialTitle;
  final String initialDescription;
  final List<AlbumModel> initialAlbums;

  const _EditPostSheet({
    required this.firestoreService,
    required this.postId,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialAlbums,
  });

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final TextEditingController _searchController = TextEditingController();
  final _spotify = SpotifyService();
  Timer? _debounce;

  late List<AlbumModel> _selectedAlbums;
  List<AlbumModel> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;

  static const _accent = Color(0xFF7B6EF6);
  static const _card = Color(0xFF1C1F2E);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _selectedAlbums = List<AlbumModel>.from(widget.initialAlbums);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final results = await _spotify.searchAlbums(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    if (_selectedAlbums.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await widget.firestoreService.updatePost(
        postId: widget.postId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        albums: _selectedAlbums,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Editar publicación',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSaving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Guardar',
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
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Título de tu playlist...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: _card,
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
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Describe tu playlist...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: _card,
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
                  if (_selectedAlbums.isNotEmpty) ...[
                    const Text(
                      'Álbumes',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        itemCount: _selectedAlbums.length,
                        itemBuilder: (_, i) {
                          final album = _selectedAlbums[i];
                          return Stack(
                            children: [
                              Container(
                                width: 90,
                                margin: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: album.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const ColoredBox(
                                      color: Color(0xFF1C1F2E),
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        const ColoredBox(
                                          color: Color(0xFF1C1F2E),
                                        ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedAlbums.removeAt(i),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'Buscar álbumes para agregar...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: _card,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 20,
                      ),
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
                  const SizedBox(height: 12),
                  if (_isSearching)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: CircularProgressIndicator(
                          color: _accent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (_searchResults.isEmpty &&
                      _searchController.text.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                    )
                  else
                    ..._searchResults.map((album) {
                      final isSelected = _selectedAlbums.any(
                        (a) => a.id == album.id,
                      );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: album.imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const ColoredBox(color: Color(0xFF1C1F2E)),
                          ),
                        ),
                        title: Text(
                          album.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          album.artist,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        trailing: GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              setState(
                                () => _selectedAlbums.removeWhere(
                                  (a) => a.id == album.id,
                                ),
                              );
                            } else {
                              setState(() => _selectedAlbums.add(album));
                            }
                          },
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                            color: isSelected ? _accent : Colors.white38,
                            size: 24,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
