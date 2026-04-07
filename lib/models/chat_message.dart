import 'package:aether/models/album_model.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String content;
  final List<AlbumModel> albums;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
    this.albums = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
    'isUser': isUser,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };
}
