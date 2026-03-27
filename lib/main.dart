import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/firebase_options.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aether',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 🕒 Esperando a Firebase
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0B0F1A),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7B6EF6),
                  strokeWidth: 2,
                ),
              ),
            );
          }

          // ✅ Logueado → entra a la app con navbar
          if (snapshot.hasData) {
            return const _AppWithNav();
          }

          // ❌ No logueado → login
          return const LoginPage();
        },
      ),
    );
  }
}

// Navbar con HomePage real en index 0
class _AppWithNav extends StatefulWidget {
  const _AppWithNav();

  @override
  State<_AppWithNav> createState() => _AppWithNavState();
}

class _AppWithNavState extends State<_AppWithNav> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(), // 0 — Home
    const _Placeholder(label: 'Aethra'), // 1
    const _Placeholder(label: 'Comunidad'), // 2
    const _Placeholder(label: 'Pulse'), // 3
    const _Placeholder(label: 'Echo'), // 4
    const ProfilePage(), // 5 — Perfil
  ];

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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
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
                final isActive = i == _currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = i),
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

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder({required this.label});

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
