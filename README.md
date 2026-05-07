# Aether

Aether es una app móvil de descubrimiento musical desarrollada en Flutter. 
Combina un feed de álbumes estilo TikTok, una IA musical, comunidad de usuarios y un minijuego de adivinanza de canciones.

## Funcionalidades

- **Home** — Feed vertical de álbumes con gradiente dinámico generado desde la portada
- **Aethra** — IA musical integrada (powered by Gemini)
- **Comunidad** — Usuarios publican playlists, comentan y dan likes en tiempo real
- **Echo** — Minijuego: adivina la canción de tu artista favorito en 5 segundos
- **Perfil** — Biblioteca personal, carpetas, álbumes favoritos y estadísticas de Spotify

## Stack Tecnológico

| Tecnología | Uso |
|---|---|
| Flutter | Framework principal |
| Firebase Auth | Autenticación de usuarios |
| Cloud Firestore | Base de datos en tiempo real |
| Spotify API | Datos de álbumes y artistas |
| Deezer API | Previews de audio para Echo |
| audioplayers | Reproducción de audio |
| cached_network_image | Carga optimizada de imágenes |

## Pantallas

- Login / Registro
- Home (feed de álbumes)
- Aethra (chat con IA musical)
- Comunidad (posts, likes, comentarios)
- Echo (minijuego musical)
- Perfil (biblioteca y estadísticas)

## Cómo correr el proyecto

### Requisitos
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0
- Android Studio o VS Code
- Dispositivo Android o emulador

### Instalación

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/aether.git
cd aether

# Instalar dependencias
flutter pub get

# Correr en dispositivo
flutter run
```

### Variables necesarias
El proyecto usa Firebase y Spotify. Necesitas:
- `google-services.json` en `android/app/` (Firebase)
- Las API keys de Spotify están en `spotify_service.dart` (mover a variables de entorno antes de producción)

## Estructura del proyecto

lib/
├── core/              # Configuración Firebase
├── features/
│   ├── auth/          # Login y registro
│   ├── home/          # Feed principal
│   ├── aethra/        # IA musical
│   ├── community/     # Comunidad
│   └── echo/          # Minijuego
├── models/            # Modelos de datos
├── services/          # Spotify, Firestore, Auth
└── main.dart

## Próximas funcionalidades

- [ ] Pantalla Pulse
- [ ] Moderación de comunidad
- [ ] Foto de perfil real
- [ ] Notificaciones push
- [ ] Modo Extended Quota Spotify

## Autor

Desarrollado por Christian — proyecto académico/personal.
