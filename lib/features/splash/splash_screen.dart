import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Fase continua del campo de energía (loop perfectamente cerrado)
  late final AnimationController _fieldController;

  // Respiración sutil del núcleo central vacío
  late final AnimationController _breathController;
  late final Animation<double> _breath;

  // Entrada: fade + scale
  late final AnimationController _entryController;
  late final Animation<double> _entryScale;
  late final Animation<double> _entryOpacity;

  // Salida: fade completo de la pantalla
  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeOut;

  bool _navigationDone = false;

  static const _bg = Color(0xFF0B0F1A);

  @override
  void initState() {
    super.initState();

    _fieldController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _breath = CurvedAnimation(
      parent: _breathController,
      curve: Curves.easeInOutSine,
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeOut = CurvedAnimation(
      parent: _fadeOutController,
      curve: Curves.easeIn,
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 150));
    await _entryController.forward();

    final destination = await _resolveDestination();

    // Deja respirar la animación un momento antes de salir
    await Future.delayed(const Duration(milliseconds: 750));

    await _fadeOutController.forward();
    if (mounted && !_navigationDone) {
      _navigationDone = true;
      Navigator.of(context).pushReplacementNamed(destination);
    }
  }

  Future<String> _resolveDestination() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '/login';
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_complete') ?? false;
    if (!done) return '/onboarding';
    return '/home';
  }

  @override
  void dispose() {
    _fieldController.dispose();
    _breathController.dispose();
    _entryController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _fieldController,
          _breath,
          _entryScale,
          _entryOpacity,
          _fadeOut,
        ]),
        builder: (context, _) {
          return Opacity(
            opacity: 1.0 - _fadeOut.value,
            child: Center(
              child: Opacity(
                opacity: _entryOpacity.value,
                child: Transform.scale(
                  scale: _entryScale.value,
                  child: _AetherLoader(
                    phase: _fieldController.value,
                    breath: _breath.value,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Campo de energía circular: líneas radiales finas distribuidas en los
// 360° completos, cada una animada de forma independiente (longitud,
// opacidad y micro-desfase propios). Una onda continua viaja alrededor
// del círculo dando sensación de órbita/energía viva, sin rotar el
// conjunto como un bloque. Centro completamente vacío.
// ─────────────────────────────────────────────────────────────────────────
class _AetherLoader extends StatelessWidget {
  final double phase; // 0..1, loop continuo y perfectamente cerrado
  final double breath; // 0..1, va y vuelve

  const _AetherLoader({required this.phase, required this.breath});

  static const _accent = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(140, 140),
              painter: _EnergyFieldPainter(phase: phase),
            ),
          ),
          // Núcleo: espacio limpio, solo un punto de luz mínimo que respira
          Container(
            width: 5 + breath * 2,
            height: 5 + breath * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent,
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.5 + breath * 0.25),
                  blurRadius: 12 + breath * 6,
                  spreadRadius: 0.5 + breath,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: -34,
            child: Opacity(
              opacity: 0.75,
              child: Text(
                'AETHER',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyFieldPainter extends CustomPainter {
  final double phase; // 0..1

  _EnergyFieldPainter({required this.phase});

  static const _accent = Color(0xFF8B5CF6);
  static const int _lineCount = 28;

  // Cuántas veces "da la vuelta" la onda de energía por cada ciclo del
  // controller. Debe ser un entero para que el loop sea perfectamente
  // cerrado (sin salto perceptible al reiniciar).
  static const double _waveRevolutions = 2.0;
  static const double _secondaryWaveRevolutions = 3.0;

  // Jitter determinista por línea (misma semilla siempre): pequeñas
  // variaciones de fase, longitud y opacidad para que el conjunto se
  // sienta orgánico en vez de perfectamente uniforme.
  static final List<_LineJitter> _jitter = _buildJitter();

  static List<_LineJitter> _buildJitter() {
    final rnd = math.Random(7);
    return List.generate(_lineCount, (_) {
      return _LineJitter(
        phaseOffset: rnd.nextDouble() * 0.5 - 0.25,
        lengthMul: 0.75 + rnd.nextDouble() * 0.5,
        opacityMul: 0.7 + rnd.nextDouble() * 0.5,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;

    // Radio interno generoso: el centro queda completamente despejado,
    // rodeado por energía, no ocupado por ella.
    final innerRadius = maxRadius * 0.46;
    const baseLength = 0.14;
    const lengthAmplitude = 0.11;

    for (var i = 0; i < _lineCount; i++) {
      final j = _jitter[i];
      final theta = (i / _lineCount) * 2 * math.pi;

      // Onda viajera: combina dos armónicos con distinta velocidad y
      // número de "lóbulos" para un movimiento con más carácter que un
      // simple seno único, sin dejar de ser fluido y continuo.
      final wave1 = math.sin(
        theta * 3 + phase * _waveRevolutions * 2 * math.pi + j.phaseOffset,
      );
      final wave2 = math.sin(
        theta * 5 -
            phase * _secondaryWaveRevolutions * 2 * math.pi +
            j.phaseOffset * 1.7,
      );
      final combined = (wave1 * 0.7 + wave2 * 0.3);
      final energy = (combined + 1) / 2; // 0..1

      final lengthFactor =
          (baseLength + lengthAmplitude * energy) * j.lengthMul;
      final length = maxRadius * lengthFactor;

      final opacity = (0.25 + 0.65 * energy).clamp(0.0, 1.0) * j.opacityMul;
      final strokeWidth = 1.3 + energy * 1.1;

      final dir = Offset(math.cos(theta), math.sin(theta));
      final start = center + dir * innerRadius;
      final end = center + dir * (innerRadius + length);

      // Glow sutil detrás de cada línea
      final glowPaint = Paint()
        ..color = _accent.withValues(alpha: opacity * 0.35)
        ..strokeWidth = strokeWidth + 2.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(start, end, glowPaint);

      // Trazo nítido
      final sharpPaint = Paint()
        ..color = _accent.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, sharpPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyFieldPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _LineJitter {
  final double phaseOffset;
  final double lengthMul;
  final double opacityMul;

  const _LineJitter({
    required this.phaseOffset,
    required this.lengthMul,
    required this.opacityMul,
  });
}
