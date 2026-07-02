import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:aether/features/echo/echo_result_page.dart';

class EchoGamePage extends StatefulWidget {
  final Map<String, dynamic> artist;
  final SpotifyService spotify;
  final int secondsPerRound;

  const EchoGamePage({
    super.key,
    required this.artist,
    required this.spotify,
    required this.secondsPerRound,
  });

  @override
  State<EchoGamePage> createState() => _EchoGamePageState();
}

class _EchoGamePageState extends State<EchoGamePage> {
  static const _totalRounds = 5;
  static const _accent = Color(0xFF7B6EF6);
  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);

  int get _roundDuration => widget.secondsPerRound;

  final _player = AudioPlayer();
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = true;
  bool _isLoadingRound = false;

  int _round = 0;
  int _score = 0;
  int _secondsLeft = 5;
  Timer? _timer;

  Map<String, dynamic>? _currentTrack;
  List<String> _options = [];
  String? _selectedOption;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _player.setPlayerMode(PlayerMode.mediaPlayer);
    _loadTracks();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    try {
      final tracks = await widget.spotify.getArtistTopTracks(
        widget.artist['name'] as String,
        deezerArtistId: widget.artist['deezerArtistId'] as String?,
      );

      if (tracks.length < 4) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: _card,
              title: const Text(
                'Sin previews disponibles',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Este artista no tiene suficientes previews para jugar. Prueba con otro artista.',
                style: TextStyle(color: Colors.white60),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Volver', style: TextStyle(color: _accent)),
                ),
              ],
            ),
          );
        }
        return;
      }
      tracks.shuffle();
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
        _startRound();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _startRound() async {
    if (_round >= _totalRounds) {
      _goToResults();
      return;
    }

    _timer?.cancel();
    await _player.stop();

    final track = _tracks[_round];

    final wrongTracks = _tracks.where((t) => t['id'] != track['id']).toList()
      ..shuffle();
    final wrong = wrongTracks.take(3).map((t) => t['name'] as String).toList();
    final options = [...wrong, track['name'] as String]..shuffle();

    if (mounted) setState(() => _isLoadingRound = true);

    try {
      final previewUrl = track['previewUrl'] as String? ?? '';

      if (previewUrl.isEmpty) {
        if (mounted) setState(() => _round++);
        _startRound();
        return;
      }

      precacheImage(
        NetworkImage(track['imageUrl'] as String? ?? ''),
        context,
      ).catchError((_) {});

      await _player.play(UrlSource(previewUrl));

      // Espera hasta 3s a que confirme que está reproduciendo
      int waitMs = 0;
      while (waitMs < 3000) {
        if (_player.state == PlayerState.playing) break;
        await Future.delayed(const Duration(milliseconds: 100));
        waitMs += 100;
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _currentTrack = track;
      _options = options;
      _selectedOption = null;
      _answered = false;
      _secondsLeft = _roundDuration;
      _isLoadingRound = false;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        if (!_answered) _autoFail();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _autoFail() {
    _timer?.cancel();
    _player.stop();
    setState(() => _answered = true);
  }

  void _selectOption(String option) {
    if (_answered) return;
    _timer?.cancel();
    _player.stop();
    final correct = option == (_currentTrack!['name'] as String);
    if (correct) _score++;
    setState(() {
      _selectedOption = option;
      _answered = true;
    });
  }

  void _nextRound() {
    setState(() => _round++);
    _startRound();
  }

  void _goToResults() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EchoResultPage(
          artist: widget.artist,
          score: _score,
          total: _totalRounds,
          spotify: widget.spotify,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingRound || _currentTrack == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _accent, strokeWidth: 2),
              const SizedBox(height: 16),
              Text(
                _isLoading
                    ? 'Cargando canciones de\n${widget.artist['name']}...'
                    : 'Preparando ronda...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final track = _currentTrack!;
    final artistName = widget.artist['name'] as String;
    final correctName = track['name'] as String;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF7B6EF6), size: 20),
                  const SizedBox(width: 4),
                  const Text(
                    'ECHO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Ronda ${_round + 1}/$_totalRounds',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

            // ── Progress bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_round + 1) / _totalRounds,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(_accent),
                  minHeight: 4,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Portada con timer ─────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF1C1F2E),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: track['imageUrl'] as String? ?? '',
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFF1C1F2E)),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF1C1F2E)),
                    ),
                  ),
                ),
                if (!_answered)
                  Positioned(
                    top: -12,
                    right: -12,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_secondsLeft',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Artista + pregunta ────────────────────────────────────────
            Text(
              artistName.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '¿Qué canción es esta?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 28),

            // ── Opciones ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ..._options.asMap().entries.map((entry) {
                      final i = entry.key;
                      final option = entry.value;
                      final label = String.fromCharCode(65 + i);
                      return _OptionButton(
                        label: label,
                        text: option,
                        state: _answered
                            ? option == correctName
                                  ? _OptionState.correct
                                  : option == _selectedOption
                                  ? _OptionState.wrong
                                  : _OptionState.neutral
                            : _selectedOption == option
                            ? _OptionState.selected
                            : _OptionState.neutral,
                        onTap: () => _selectOption(option),
                      );
                    }),
                    const Spacer(),
                    if (_answered)
                      GestureDetector(
                        onTap: _nextRound,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Siguiente',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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

enum _OptionState { neutral, selected, correct, wrong }

class _OptionButton extends StatelessWidget {
  final String label;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color labelBg;
    Color textColor;

    switch (state) {
      case _OptionState.correct:
        bgColor = const Color(0xFF1A3A2A);
        labelBg = Colors.green;
        textColor = Colors.greenAccent;
        break;
      case _OptionState.wrong:
        bgColor = const Color(0xFF3A1A1A);
        labelBg = Colors.redAccent;
        textColor = Colors.redAccent;
        break;
      case _OptionState.selected:
        bgColor = const Color(0xFF1C1F3A);
        labelBg = const Color(0xFF7B6EF6);
        textColor = Colors.white;
        break;
      case _OptionState.neutral:
        bgColor = const Color(0xFF111827);
        labelBg = const Color(0xFF2A2D45);
        textColor = Colors.white70;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: labelBg, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
