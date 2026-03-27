import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:aether/services/auth_service.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/features/home/folder_detail_page.dart';

// ════════════════════════════════════════════════════════════════
//  NAVBAR PRINCIPAL — reemplaza tu Scaffold raíz en main.dart
//
//  USO en main.dart:
//  Donde antes tenías HomePage() o tu pantalla inicial,
//  pon MainNavigation() como home del MaterialApp.
//  Ejemplo:
//    home: MainNavigation(),
// ════════════════════════════════════════════════════════════════

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Reemplaza los _PlaceholderPage con tus páginas reales cuando las tengas.
  // HomePage ya la tienes — impórtala y úsala en index 0.
  late final List<Widget> _pages = [
    const _PlaceholderPage(label: 'Home'), // → reemplaza con HomePage()
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

// ── Navbar ─────────────────────────────────────────────────────────────────────

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

// ── Placeholder para páginas futuras ──────────────────────────────────────────

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

  // Carpetas
  List<Map<String, dynamic>> _folders = [];
  StreamSubscription? _foldersSubscription;

  // Liked albums
  List<AlbumModel> _likedAlbums = [];
  StreamSubscription? _likedSubscription;

  // Input nueva carpeta
  bool _showFolderInput = false;
  final _folderNameController = TextEditingController();
  bool _creatingFolder = false;

  // Colores
  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);
  static const _accent = Color(0xFF7B6EF6);
  static const _surface = Color(0xFF1A1F35);

  @override
  void initState() {
    super.initState();
    _listenFolders();
    _listenLikedAlbums();
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

  // ── Acciones de carpeta ───────────────────────────────────────────────────

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

  Future<void> _signOut() async {
    await _auth.signOut();
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
      child: Column(
        children: [
          // Avatar + datos
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B6EF6), Color(0xFF4A3FC4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Nombre y subtítulo
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
                    const Text(
                      '',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF1E2236), height: 1),
          const SizedBox(height: 20),
          // Seguidores / Siguiendo — por ahora en 0, se implementa después
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat('0', 'SEGUIDORES'),
              Container(width: 1, height: 32, color: const Color(0xFF1E2236)),
              _buildStat('0', 'SIGUIENDO'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // ── Sección Mi Biblioteca ─────────────────────────────────────────────────

  Widget _buildLibrarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado "Mi Biblioteca" + botón +
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

        // Input nueva carpeta (aparece/desaparece)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildFolderInput(),
          crossFadeState: _showFolderInput
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),

        // Lista de carpetas
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

  // ── Sección Álbumes Favoritos ─────────────────────────────────────────────

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
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  album.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _surface,
                    child: const Icon(Icons.album, color: Colors.white12),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
