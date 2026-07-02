import 'dart:typed_data';
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
  late final AnimationController _drawController;
  late final Animation<double> _drawProgress;

  late final AnimationController _glowController;
  late final Animation<double> _glowPulse;

  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeOut;

  bool _navigationDone = false;

  @override
  void initState() {
    super.initState();

    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _drawProgress = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeInOutCubic,
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _glowPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeOut = CurvedAnimation(
      parent: _fadeOutController,
      curve: Curves.easeOut,
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 250));
    await _drawController.forward();
    _glowController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1000));
    final destination = await _resolveDestination();
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
    _drawController.dispose();
    _glowController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: AnimatedBuilder(
        animation: Listenable.merge([_drawProgress, _glowPulse, _fadeOut]),
        builder: (context, _) {
          return Opacity(
            opacity: 1.0 - _fadeOut.value,
            child: Center(
              child: CustomPaint(
                size: const Size(220, 240),
                painter: _AetherLogoPainter(
                  drawProgress: _drawProgress.value,
                  glowPulse: _glowPulse.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────
class _AetherLogoPainter extends CustomPainter {
  final double drawProgress;
  final double glowPulse;

  const _AetherLogoPainter({
    required this.drawProgress,
    required this.glowPulse,
  });

  static const int _layers = 7;

  // Colores: exterior más oscuro/azul, interior más claro/violeta
  static const Color _outer = Color(0xFF4A3FC4);
  static const Color _inner = Color(0xFF9D93F8);

  @override
  void paint(Canvas canvas, Size size) {
    final base = _buildBaseA(size.width, size.height);
    final paths = _buildLayers(base, size.width, size.height);

    // ── Glow difuso ──────────────────────────────────────────────────────────
    final glowOpacity = 0.28 + glowPulse * 0.10;
    final glowPaint = Paint()
      ..color = const Color(0xFF7B6EF6).withOpacity(glowOpacity)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    for (final p in paths) {
      _drawPartial(canvas, glowPaint, p, drawProgress);
    }

    // ── Líneas ───────────────────────────────────────────────────────────────
    for (int i = 0; i < paths.length; i++) {
      final t = i / (_layers - 1); // 0=outer, 1=inner
      final color = Color.lerp(_outer, _inner, t)!;
      final sw = 2.5 - t * 1.0; // 2.5px → 1.5px

      final paint = Paint()
        ..color = color
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      _drawPartial(canvas, paint, paths[i], drawProgress);
    }
  }

  // Dibuja solo [progress] fracción del path
  void _drawPartial(Canvas canvas, Paint paint, Path path, double progress) {
    if (progress <= 0) return;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final m in path.computeMetrics()) {
      final len = m.length * progress;
      if (len > 0) canvas.drawPath(m.extractPath(0, len), paint);
    }
  }

  // ── Genera N capas escalando el path base desde su centro ──────────────────
  // Cada capa es la misma forma exacta, solo un poco más pequeña.
  // Esto garantiza líneas perfectamente paralelas.
  List<Path> _buildLayers(Path base, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    const totalShrink = 0.28; // la capa más interior es 28% más pequeña

    return List.generate(_layers, (i) {
      // i=0 → outer (escala 1.0), i=_layers-1 → inner (escala 1-totalShrink)
      final scale = 1.0 - (i / (_layers - 1)) * totalShrink;

      // Matriz: escala centrada en (cx, cy)
      // [scale, 0,     cx*(1-scale)]
      // [0,     scale, cy*(1-scale)]
      final matrix = Float64List(16);
      matrix[0] = scale;
      matrix[5] = scale;
      matrix[10] = 1;
      matrix[15] = 1;
      matrix[12] = cx * (1 - scale);
      matrix[13] = cy * (1 - scale);

      return base.transform(matrix);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BASE A — una sola forma, tamaño completo del canvas
  //
  // Referencia del logo original:
  //   - Apex con arco suave y compacto en la cima
  //   - Patas que se abren ampliamente (triángulo ancho)
  //   - Pata izquierda: al llegar abajo hace una cola que gira a la derecha
  //   - Pata derecha: más recta, termina en diagonal hacia abajo-izquierda
  //   - Barra horizontal curva al ~58% de la altura
  //
  // El path se dibuja como UN SOLO trazo continuo para que la animación
  // de draw-on se vea fluida y sin saltos:
  //   hombro-izq → apex-arco → hombro-der → pata-der → cola-der
  //   (moveTo) barra izq → barra der
  //   (moveTo) hombro-izq → pata-izq → cola-izq
  // ─────────────────────────────────────────────────────────────────────────
  Path _buildBaseA(double w, double h) {
    final path = Path();

    // ── Puntos principales ────────────────────────────────────────────────────

    // Hombros del apex (donde el arco redondeado termina y empiezan las patas)
    // El arco es PEQUEÑO — solo ocupa el 30% central del ancho
    const double shoulderLX = 0.36; // hombro izquierdo X
    const double shoulderLY = 0.20; // hombro izquierdo Y
    const double shoulderRX = 0.64; // hombro derecho X
    const double shoulderRY = 0.20; // hombro derecho Y

    // Control points del arco del apex
    const double apexCtrlY = 0.03; // altura del apex

    // Pata izquierda: se abre hacia la izquierda, base bien abierta
    const double legLX = 0.05; // base pata izquierda X
    const double legLY = 0.87; // base pata izquierda Y
    // Cola izquierda: la curva que gira a la derecha
    const double tailLX = 0.18; // fin de la cola izquierda
    const double tailLY = 0.96; // fin de la cola izquierda

    // Pata derecha: se abre hacia la derecha
    const double legRX = 0.88; // base pata derecha X
    const double legRY = 0.87; // base pata derecha Y
    // Fin pata derecha (diagonal hacia abajo-izquierda)
    const double tipRX = 0.78; // punta inferior derecha X
    const double tipRY = 0.96; // punta inferior derecha Y

    // Barra horizontal
    const double barLX = 0.28;
    const double barLY = 0.60;
    const double barRX = 0.72;
    const double barRY = 0.60;
    const double barMidY = 0.56; // arco suave hacia arriba

    // ── Segmento 1: arco del apex (izq → der) ────────────────────────────────
    path.moveTo(w * shoulderLX, h * shoulderLY);
    path.cubicTo(
      w * 0.42,
      h * apexCtrlY, // ctrl 1
      w * 0.58,
      h * apexCtrlY, // ctrl 2
      w * shoulderRX,
      h * shoulderRY,
    );

    // ── Segmento 2: pata derecha ──────────────────────────────────────────────
    path.cubicTo(
      w * 0.72,
      h * 0.42, // ctrl 1: empieza a abrirse
      w * 0.85,
      h * 0.68, // ctrl 2: muy abierta
      w * legRX,
      h * legRY,
    );
    // Remate inferior derecho (diagonal)
    path.cubicTo(w * 0.90, h * 0.91, w * 0.86, h * 0.94, w * tipRX, h * tipRY);

    // ── Segmento 3: barra (sub-path) ─────────────────────────────────────────
    path.moveTo(w * barLX, h * barLY);
    path.cubicTo(
      w * 0.40,
      h * barMidY,
      w * 0.60,
      h * barMidY,
      w * barRX,
      h * barRY,
    );

    // ── Segmento 4: pata izquierda + cola ────────────────────────────────────
    path.moveTo(w * shoulderLX, h * shoulderLY);
    path.cubicTo(
      w * 0.28,
      h * 0.42, // ctrl 1: empieza a abrirse
      w * 0.12,
      h * 0.68, // ctrl 2: muy abierta a la izquierda
      w * legLX,
      h * legLY,
    );
    // Cola: llega al extremo izquierdo y gira hacia la derecha
    path.cubicTo(
      w * 0.02,
      h * 0.91, // ctrl 1: toca el extremo
      w * 0.03,
      h * 0.96, // ctrl 2: gira
      w * tailLX,
      h * tailLY, // termina más a la derecha
    );

    return path;
  }

  @override
  bool shouldRepaint(_AetherLogoPainter old) =>
      old.drawProgress != drawProgress || old.glowPulse != glowPulse;
}
