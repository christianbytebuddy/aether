import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aether/models/chat_message.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/firestore_service.dart';
import 'package:aether/services/aethra_service.dart';
import 'package:aether/features/home/album_detail_sheet.dart';

class AethraPage extends StatefulWidget {
  final String? conversationId;
  const AethraPage({super.key, this.conversationId});

  @override
  State<AethraPage> createState() => _AethraPageState();
}

class _AethraPageState extends State<AethraPage>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _aethra = AethraService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _db = FirebaseFirestore.instance;

  final List<ChatMessage> _messages = [];
  bool _isThinking = false;
  bool _isLoadingHistory = false;
  late String _conversationId;
  bool _isNewConversation = false;

  // Animación de los tres puntos
  late AnimationController _dotsController;

  static const _bgColor = Color(0xFF0B0F1A);
  static const _accentColor = Color(0xFF7B6EF6);
  static const _cardColor = Color(0xFF1C1F2E);

  static const _suggestions = [
    ('🌙', 'Música para la noche'),
    ('😢', 'Álbumes tristes'),
    ('🎸', 'Similar a Arctic Monkeys'),
    ('💃', 'Para bailar'),
  ];

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    if (widget.conversationId != null) {
      _conversationId = widget.conversationId!;
      _isNewConversation = false;
      _loadHistory();
    } else {
      _conversationId = DateTime.now().millisecondsSinceEpoch.toString();
      _isNewConversation = true;
    }
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  CollectionReference get _messagesRef => _db
      .collection('users')
      .doc(_uid)
      .collection('aethra_conversations')
      .doc(_conversationId)
      .collection('messages');

  DocumentReference get _conversationRef => _db
      .collection('users')
      .doc(_uid)
      .collection('aethra_conversations')
      .doc(_conversationId);

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _isLoadingHistory = true);
    try {
      final snap = await _messagesRef
          .orderBy('createdAt', descending: false)
          .limitToLast(30)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) setState(() => _isLoadingHistory = false);
        return;
      }

      setState(() {
        _messages.addAll(
          snap.docs.map(
            (d) => ChatMessage.fromFirestore(
              d.id,
              d.data() as Map<String, dynamic>,
            ),
          ),
        );
        _isLoadingHistory = false;
      });

      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _saveMessage(ChatMessage msg) async {
    await _messagesRef.doc(msg.id).set(msg.toFirestore());
  }

  Future<void> _updateConversationMeta(String title, String lastMessage) async {
    await _conversationRef.set({
      'title': title,
      'lastMessage': lastMessage,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isThinking) return;

    _textController.clear();

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: true,
      content: query,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isThinking = true;
    });

    await _saveMessage(userMsg);

    if (_isNewConversation || _messages.length == 1) {
      _isNewConversation = false;
      await _updateConversationMeta(
        query.length > 40 ? '${query.substring(0, 40)}...' : query,
        query,
      );
    }

    _scrollToBottom();

    try {
      final result = await _aethra.sendMessageWithResults(query);
      final responseText = result['message'] as String;
      final albums = result['albums'] as List<AlbumModel>;

      final botMsg = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_bot',
        isUser: false,
        content: responseText,
        createdAt: DateTime.now(),
        albums: albums,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(botMsg);
        _isThinking = false;
      });

      await _saveMessage(botMsg);
      await _updateConversationMeta(
        _messages.first.content.length > 40
            ? '${_messages.first.content.substring(0, 40)}...'
            : _messages.first.content,
        responseText.length > 60
            ? '${responseText.substring(0, 60)}...'
            : responseText,
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isThinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBack =
        widget.conversationId != null || Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: _bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(showBack),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _accentColor,
                        strokeWidth: 2,
                      ),
                    )
                  : _messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(),
            ),
            if (_isThinking) _buildThinkingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool showBack) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aethra',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Asistente musical IA',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Burbuja de bienvenida
          _buildAethraBubble(
            '¡Hola! Soy Aethra ✨ Puedo recomendarte música, contarte sobre artistas o ayudarte a descubrir nuevos álbumes. ¿Por dónde empezamos?',
            [],
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Prueba con',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map(
                  (s) => GestureDetector(
                    onTap: () => _sendMessage(s.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _accentColor.withOpacity(0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.$1, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            s.$2,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        // Solo mostrar avatar de Aethra en el primer mensaje de una secuencia
        final showAvatar = !msg.isUser && (i == 0 || _messages[i - 1].isUser);
        return _buildBubble(msg, showAvatar: showAvatar);
      },
    );
  }

  Widget _buildBubble(ChatMessage msg, {bool showAvatar = true}) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar Aethra — solo en primer mensaje de secuencia
          if (!isUser)
            SizedBox(
              width: 28,
              child: showAvatar
                  ? Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  : null,
            ),
          if (!isUser) const SizedBox(width: 8),

          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  _buildAethraBubble(msg.content, msg.albums)
                else
                  _buildUserBubble(msg.content),
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // Burbuja de Aethra con borde izquierdo morado
  Widget _buildAethraBubble(String content, List<AlbumModel> albums) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border(
              left: BorderSide(color: _accentColor.withOpacity(0.6), width: 2),
            ),
          ),
          child: Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        if (albums.isNotEmpty) _buildAlbumCards(albums),
      ],
    );
  }

  // Burbuja del usuario
  Widget _buildUserBubble(String content) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _accentColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Text(
        content,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      ),
    );
  }

  // Tres puntos animados
  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                left: BorderSide(
                  color: _accentColor.withOpacity(0.6),
                  width: 2,
                ),
              ),
            ),
            child: AnimatedBuilder(
              animation: _dotsController,
              builder: (_, __) {
                final t = _dotsController.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // Cada punto se activa en su turno
                    final active = (t * 3).floor() == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: active ? 10 : 6,
                      decoration: BoxDecoration(
                        color: active ? _accentColor : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: _bgColor,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onSubmitted: _sendMessage,
              decoration: InputDecoration(
                hintText: 'Pregúntale a Aethra...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                filled: true,
                fillColor: _cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_textController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cards de álbumes — fila compacta horizontal
  Widget _buildAlbumCards(List<AlbumModel> albums) {
    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 8),
        physics: const ClampingScrollPhysics(),
        itemCount: albums.length,
        itemBuilder: (_, i) {
          final album = albums[i];
          return GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AlbumDetailSheet(
                album: album,
                firestoreService: FirestoreService(),
                bgColor: const Color(0xFF1C1F2E),
              ),
            ),
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: album.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFF1C1F2E)),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF1C1F2E)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          album.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
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
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
