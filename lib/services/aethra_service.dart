import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:aether/models/album_model.dart';
import 'package:aether/services/spotify_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AethraService {
  static const _apiKey = 'AIzaSyCA5V2gFfGOAc5qR5Veb7NwBxe55AiQ-p8';
  final _spotify = SpotifyService();

  late final GenerativeModel _model;

  AethraService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 800,
      ),
      systemInstruction: Content.system(
        'Eres Aethra, asistente musical de la app Aether. '
        'Responde SOLO en este JSON, sin markdown, sin texto extra, sin caracteres especiales:\n'
        '{"message":"texto corto sin comas ni comillas","searches":[{"type":"artist","query":"nombre"},{"type":"album","query":"nombre"}]}\n'
        'REGLAS ESTRICTAS:\n'
        '- El campo message: maximo 8 palabras, sin comas, sin comillas internas\n'
        '- Entre 3 y 5 busquedas\n'
        '- Responde en el idioma del usuario\n'
        '- NUNCA inventes artistas o albumes\n'
        '- El JSON debe ser valido y completo siempre',
      ),
    );
  }

  // Devuelve el mensaje de texto
  Future<String> sendMessage(String message) async {
    final result = await sendMessageWithResults(message);
    return result['message'] as String;
  }

  // Devuelve mensaje + álbumes de Spotify
  Future<Map<String, dynamic>> sendMessageWithResults(String message) async {
    // Límite de 20 requests por día
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    final key = 'aethra_count_$today';
    final count = prefs.getInt(key) ?? 0;
    if (count >= 20) {
      return {
        'message': 'Alcanzaste el límite diario. Vuelve mañana ✨',
        'albums': <AlbumModel>[],
      };
    }
    await prefs.setInt(key, count + 1);

    try {
      final response = await _model.generateContent([Content.text(message)]);
      final text = response.text ?? '';

      var clean = text.replaceAll('```json', '').replaceAll('```', '').trim();

      final jsonStart = clean.indexOf('{');
      final jsonEnd = clean.lastIndexOf('}');

      if (jsonStart != -1 && jsonEnd != -1) {
        clean = clean.substring(jsonStart, jsonEnd + 1);
      }

      final parsed = jsonDecode(clean);
      final msg = parsed['message'] as String;
      final searches = parsed['searches'] as List<dynamic>? ?? [];

      // Busca en Spotify en paralelo
      final albums = await _searchSpotify(searches);

      return {'message': msg, 'albums': albums};
    } catch (e) {
      print('AETHRA ERROR: $e');
      return {'message': 'Error: $e', 'albums': <AlbumModel>[]};
    }
  }

  Future<List<AlbumModel>> _searchSpotify(List<dynamic> searches) async {
    try {
      final results = await Future.wait(
        searches.map((s) => _spotify.searchAlbums(s['query'] as String)),
      );
      // Toma el primer resultado de cada búsqueda y elimina duplicados
      final seen = <String>{};
      final albums = <AlbumModel>[];
      for (final list in results) {
        if (list.isNotEmpty) {
          final album = list.first;
          if (seen.add(album.id)) albums.add(album);
        }
      }
      return albums.take(5).toList();
    } catch (_) {
      return [];
    }
  }
}
