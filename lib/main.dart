import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'core/firebase_options.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'features/community/community_page.dart';
import 'package:aether/features/echo/echo_page.dart';
import 'profile_page.dart';
import 'package:aether/services/spotify_auth_service.dart';
import 'package:aether/features/pulse/pulse_page.dart';
import 'package:aether/core/user_session.dart';
import 'package:aether/features/aethra/aethra_history_page.dart';
import 'package:aether/features/splash/splash_screen.dart';
import 'package:aether/features/onboarding/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    debugPrint('DEEP LINK: $uri');
    if (uri.scheme == 'aether' && uri.host == 'spotify-callback') {
      SpotifyAuthService.onCallback?.call(uri.toString());
    }
  });

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
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const _AppWithNav(),
        '/onboarding': (context) => OnboardingPage(
          onComplete: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_complete', true);
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
      },
    );
  }
}

class _AppWithNav extends StatefulWidget {
  const _AppWithNav();

  @override
  State<_AppWithNav> createState() => _AppWithNavState();
}

class _AppWithNavState extends State<_AppWithNav> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    UserSession.instance.load();
  }

  final List<Widget> _pages = [
    const HomePage(),
    const AethraHistoryPage(),
    const CommunityPage(),
    const PulsePage(),
    const EchoPage(),
    const ProfilePage(),
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
      label: 'Tracker',
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
