import 'dart:convert';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? photoBase64;
  final String letter;
  final double radius;

  const UserAvatar({
    super.key,
    required this.photoBase64,
    required this.letter,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final data = photoBase64!.contains(',')
            ? photoBase64!.split(',')[1]
            : photoBase64!;
        final bytes = base64Decode(data);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF7B6EF6),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
