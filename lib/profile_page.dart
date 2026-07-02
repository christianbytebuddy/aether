import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:aether/services/auth_service.dart';
import 'package:aether/services/spotify_auth_service.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/features/home/folder_detail_page.dart';
import 'dart:convert';
import 'package:aether/features/home/album_detail_sheet.dart';
import 'package:aether/features/diary/diary_entry_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    const _PlaceholderPage(label: 'Home'),
    const _PlaceholderPage(label: 'Aethra'),
    const _PlaceholderPage(label: 'Comunidad'),
    const _PlaceholderPage(label: 'Pulse'),
    const _PlaceholderPage(label: 'Echo'),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _AetherNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _AetherNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AetherNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _NavItem(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
      label: 'Aethra',
    ),
    _NavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Comunidad',
    ),
    _NavItem(
      icon: Icons.graphic_eq_outlined,
      activeIcon: Icons.graphic_eq,
      label: 'Pulse',
    ),
    _NavItem(icon: Icons.bolt_outlined, activeIcon: Icons.bolt, label: 'Echo'),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1320),
        border: Border(top: BorderSide(color: Color(0xFF1E2236), width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          key: ValueKey(isActive),
                          size: 22,
                          color: isActive
                              ? const Color(0xFF7B6EF6)
                              : const Color(0xFF3D4466),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? const Color(0xFF7B6EF6)
                              : const Color(0xFF3D4466),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _PlaceholderPage extends StatelessWidget {
  final String label;
  const _PlaceholderPage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: Center(
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF3D4466), fontSize: 18),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  PROFILE PAGE
// ════════════════════════════════════════════════════════════════

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _firestore = FirestoreService();
  final _auth = AuthService();

  List<Map<String, dynamic>> _folders = [];
  StreamSubscription? _foldersSubscription;

  List<AlbumModel> _likedAlbums = [];
  StreamSubscription? _likedSubscription;

  bool _showFolderInput = false;
  final _folderNameController = TextEditingController();
  bool _creatingFolder = false;

  final _spotifyAuth = SpotifyAuthService();
  bool _spotifyConnected = false;
  List<Map<String, dynamic>> _topArtists = [];
  List<Map<String, dynamic>> _topTracks = [];
  bool _loadingStats = false;

  String? _photoUrl;
  bool _uploadingPhoto = false;

  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);
  static const _accent = Color(0xFF7B6EF6);
  static const _surface = Color(0xFF1A1F35);

  @override
  void initState() {
    super.initState();
    _listenFolders();
    _listenLikedAlbums();
    _checkSpotifyConnection();
    _loadPhoto();
  }

  void _listenFolders() {
    _foldersSubscription = _firestore.foldersStream().listen((folders) {
      if (mounted) setState(() => _folders = folders);
    });
  }

  void _listenLikedAlbums() {
    _likedSubscription = _firestore.likedAlbumsStream().listen((albums) {
      if (mounted) setState(() => _likedAlbums = albums);
    });
  }

  @override
  void dispose() {
    _foldersSubscription?.cancel();
    _likedSubscription?.cancel();
    _folderNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirestoreService().getUserDoc(uid);
      final url = doc?['photoBase64'] as String?;
      if (url != null && mounted) setState(() => _photoUrl = url);
    } catch (e) {
      debugPrint('ERROR cargando foto: $e');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 70,
    );
    if (picked == null) return;
    if (mounted) setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirestoreService().saveUserPhoto(uid, base64Str);
      if (mounted) setState(() => _photoUrl = base64Str);
    } catch (e) {
      debugPrint('ERROR FOTO: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _createFolder() async {
    final name = _folderNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _creatingFolder = true);
    try {
      await _firestore.createFolder(name);
      _folderNameController.clear();
      setState(() => _showFolderInput = false);
    } finally {
      if (mounted) setState(() => _creatingFolder = false);
    }
  }

  Future<void> _deleteFolder(String folderId, String folderName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar carpeta',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          '¿Eliminar "$folderName"? Se perderán los álbumes guardados en ella.',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _firestore.deleteFolder(folderId);
  }

  Future<void> _renameFolder(String folderId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Renombrar carpeta',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                await _firestore.renameFolder(folderId, newName);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkSpotifyConnection() async {
    final connected = await _spotifyAuth.isConnected();
    if (mounted) setState(() => _spotifyConnected = connected);
    if (connected) _loadStats();
  }

  Future<void> _connectSpotify() async {
    final success = await _spotifyAuth.connectSpotify();
    if (success && mounted) {
      setState(() => _spotifyConnected = true);
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);
    try {
      final artists = await _spotifyAuth.getTopArtists();
      final tracks = await _spotifyAuth.getTopTracks();
      if (mounted)
        setState(() {
          _topArtists = artists;
          _topTracks = tracks;
          _loadingStats = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _signOut() async => await _auth.signOut();

  String _topSong() {
    if (_topTracks.isEmpty) return '-';
    return _topTracks.first['name'] as String;
  }

  String _topAlbum() {
    if (_topTracks.isEmpty) return '-';
    final freq = <String, int>{};
    for (final t in _topTracks) {
      final album = t['albumName'] as String? ?? '';
      if (album.isNotEmpty) freq[album] = (freq[album] ?? 0) + 1;
    }
    if (freq.isEmpty) return '-';
    return freq.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _topGenre() {
    final genres = <String>[];
    for (final artist in _topArtists) {
      genres.addAll(List<String>.from(artist['genres'] as List? ?? []));
    }
    if (genres.isEmpty) return 'K-pop';
    final freq = <String, int>{};
    for (final g in genres) freq[g] = (freq[g] ?? 0) + 1;
    final top = freq.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return top[0].toUpperCase() + top.substring(1);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? 'Usuario';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildProfileHeader(username, email),
                    const SizedBox(height: 28),
                    _buildLibrarySection(),
                    const SizedBox(height: 28),
                    _buildLikedAlbumsSection(),
                    const SizedBox(height: 28),
                    _buildDiarySection(),
                    const SizedBox(height: 28),
                    _buildStatsSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _bg,
      elevation: 0,
      pinned: false,
      floating: true,
      title: const Text(
        'Perfil',
        style: TextStyle(
          color: _accent,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.logout_rounded,
            color: Colors.white38,
            size: 20,
          ),
          onPressed: _signOut,
          tooltip: 'Cerrar sesión',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Header de perfil ──────────────────────────────────────────────────────

  Widget _buildProfileHeader(String username, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
            child: Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF7B6EF6), Color(0xFF4A3FC4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: _uploadingPhoto
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _photoUrl != null
                      ? ClipOval(
                          child: _photoUrl!.startsWith('data:')
                              ? Image.memory(
                                  base64Decode(_photoUrl!.split(',')[1]),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: _photoUrl!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Center(
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: _card, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Biblioteca ────────────────────────────────────────────────────────────

  Widget _buildLibrarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mi Biblioteca',
              style: TextStyle(
                color: _accent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _showFolderInput = !_showFolderInput),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _showFolderInput ? Icons.close : Icons.add,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'CARPETAS',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildFolderInput(),
          crossFadeState: _showFolderInput
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (_folders.isEmpty && !_showFolderInput)
          _buildEmptyFolders()
        else
          ..._folders.map((folder) => _buildFolderTile(folder)),
      ],
    );
  }

  Widget _buildFolderInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _folderNameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Nombre de la carpeta',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14),
                ),
                onSubmitted: (_) => _createFolder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _creatingFolder ? null : _createFolder,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: _creatingFolder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Crear',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              _folderNameController.clear();
              setState(() => _showFolderInput = false);
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, color: Colors.white38, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile(Map<String, dynamic> folder) {
    final id = folder['id'] as String;
    final name = folder['name'] as String? ?? 'Sin nombre';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FolderDetailPage(folderId: id, folderName: name),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.headphones, color: _accent, size: 20),
          ),
          title: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: const Text(
            'Carpeta',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(
              Icons.chevron_right,
              color: Colors.white38,
              size: 20,
            ),
            color: const Color(0xFF1A1F35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'rename') _renameFolder(id, name);
              if (value == 'delete') _deleteFolder(id, name);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.white54, size: 16),
                    SizedBox(width: 10),
                    Text(
                      'Renombrar',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFolders() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.folder_open, color: Colors.white12, size: 32),
          SizedBox(height: 8),
          Text(
            'Toca + para crear tu primera carpeta',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Álbumes Favoritos ─────────────────────────────────────────────────────

  Widget _buildLikedAlbumsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ÁLBUMES FAVORITOS',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_likedAlbums.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.favorite_border, color: Colors.white12, size: 32),
                SizedBox(height: 8),
                Text(
                  '¡Dale me gusta a álbumes para verlos aquí!',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _likedAlbums.length,
            itemBuilder: (_, i) {
              final album = _likedAlbums[i];
              return GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AlbumDetailSheet(
                    album: album,
                    firestoreService: _firestore,
                    bgColor: const Color(0xFF1C1F2E),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: album.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: _surface),
                    errorWidget: (_, __, ___) => Container(
                      color: _surface,
                      child: const Icon(Icons.album, color: Colors.white12),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ── Diario Musical ────────────────────────────────────────────────────────

  Widget _buildDiarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book_rounded, color: Colors.white54, size: 16),
                SizedBox(width: 8),
                Text(
                  'Diario musical',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    AddDiaryEntrySheet(firestoreService: _firestore),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Agregar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestore.diaryStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white12,
                      size: 36,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Aún no tienes entradas',
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Toca + Agregar para registrar\nun álbum que estás escuchando',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white12, fontSize: 12),
                    ),
                  ],
                ),
              );
            }
            final grouped = <String, List<Map<String, dynamic>>>{};
            for (final entry in entries) {
              final ts = entry['createdAt'];
              final date = ts is Timestamp ? ts.toDate() : DateTime.now();
              grouped.putIfAbsent(_weekLabel(date), () => []).add(entry);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((group) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        group.key,
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...group.value.map((e) => _buildDiaryEntry(e)),
                    const SizedBox(height: 12),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _weekLabel(DateTime date) {
    final now = DateTime.now();
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final d = DateTime(date.year, date.month, date.day);
    final thisWeekStart = DateTime(
      startOfThisWeek.year,
      startOfThisWeek.month,
      startOfThisWeek.day,
    );
    final lastWeekStart = DateTime(
      startOfLastWeek.year,
      startOfLastWeek.month,
      startOfLastWeek.day,
    );
    if (!d.isBefore(thisWeekStart)) return 'Esta semana';
    if (!d.isBefore(lastWeekStart)) return 'Semana pasada';
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return 'Semana del ${date.day} ${months[date.month - 1]}';
  }

  Widget _buildDiaryEntry(Map<String, dynamic> entry) {
    final id = entry['id'] as String;
    final albumName = entry['albumName'] as String? ?? '';
    final albumArtist = entry['albumArtist'] as String? ?? '';
    final albumImage = entry['albumImage'] as String? ?? '';
    final note = entry['note'] as String? ?? '';
    final ts = entry['createdAt'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final dateStr = '${date.day} ${months[date.month - 1]}, ${date.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: albumImage,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const ColoredBox(color: Color(0xFF1C1F2E)),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF1C1F2E)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          albumName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    albumArtist,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        note,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _confirmDeleteDiary(id),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white24,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDiary(String entryId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar entrada',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          '¿Eliminar esta entrada del diario?',
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
              await _firestore.deleteDiaryEntry(entryId);
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

  // ── Estadísticas ──────────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Estadísticas del mes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_spotifyConnected)
              GestureDetector(
                onTap: () async {
                  await _spotifyAuth.disconnect();
                  setState(() {
                    _spotifyConnected = false;
                    _topArtists = [];
                    _topTracks = [];
                  });
                },
                child: const Text(
                  'Desconectar',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_spotifyConnected)
          GestureDetector(
            onTap: _connectSpotify,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1DB954), width: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, color: Color(0xFF1DB954), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Conectar Spotify',
                    style: TextStyle(
                      color: Color(0xFF1DB954),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_loadingStats)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(
                color: Color(0xFF1DB954),
                strokeWidth: 2,
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.music_note_outlined,
                  iconColor: const Color(0xFF7B6EF6),
                  value: _topSong(),
                  label: 'TOP CANCIÓN',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.album_outlined,
                  iconColor: Colors.redAccent,
                  value: _topAlbum(),
                  label: 'TOP ÁLBUM',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.mic_none_outlined,
                  iconColor: Colors.pinkAccent,
                  value: _topArtists.isNotEmpty
                      ? _topArtists.first['name'] as String
                      : '-',
                  label: 'TOP ARTISTA',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.favorite_border,
                  iconColor: Colors.white54,
                  value: _topGenre(),
                  label: 'GÉNERO FAV.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_topArtists.isNotEmpty) ...[
            const Text(
              'Top artistas',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            ..._topArtists
                .take(3)
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: a['imageUrl'] != ''
                              ? CachedNetworkImage(
                                  imageUrl: a['imageUrl'] as String,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: const Color(0xFF1C1F2E),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          a['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
