# Aether — Descubre música como nunca antes

Aether es una app móvil de descubrimiento musical que combina un feed de álbumes estilo TikTok, una IA musical llamada Aethra, una comunidad de usuarios y Echo, un minijuego donde adivinas canciones de tu artista favorito.

> Desarrollado con Flutter · Firebase · Spotify API · Deezer API

---

## Pantallas

| Pantalla | Descripción |
|---|---|
| **Home** | Feed vertical de álbumes con gradiente dinámico extraído de cada portada |
| **Aethra** | Chat con una IA especializada en música |
| **Comunidad** | Publica playlists, comenta y da likes en tiempo real |
| **Echo** | Minijuego: elige un artista y adivina sus canciones en 5 segundos |
| **Perfil** | Tu biblioteca, carpetas, álbumes favoritos y estadísticas de Spotify |

---

## 🛠️ Requisitos previos

Antes de empezar, asegúrate de tener instalado lo siguiente:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.0.0
- [Android Studio](https://developer.android.com/studio) o [VS Code](https://code.visualstudio.com/)
- Un dispositivo Android físico **o** un emulador Android configurado
- [Git](https://git-scm.com/)

Para verificar que Flutter está correctamente instalado, corre en tu terminal:

```bash
flutter doctor
```

Todos los ítems deben aparecer en verde ✅ (excepto iOS si estás en Windows, eso es normal).

---

## Instalación paso a paso

### 1. Clona el repositorio

```bash
git clone https://github.com/christianbytebuddy/aether.git
cd aether
```

### 2. Instala las dependencias

```bash
flutter pub get
```

### 3. Configura Firebase

Aether usa Firebase para autenticación y base de datos. Necesitas agregar el archivo de configuración:

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Crea un proyecto nuevo o usa uno existente
3. Agrega una app Android con el package name `com.example.aether`
4. Descarga el archivo `google-services.json`
5. Colócalo en la siguiente ruta dentro del proyecto:

android/
└── app/
└── google-services.json  ← aquí

En Firebase Console, activa los siguientes servicios:
- **Authentication** → Método: Email/Contraseña
- **Firestore Database** → Crear base de datos en modo producción

### 4. Configura las reglas de Firestore

En Firebase Console → Firestore → Reglas, pega lo siguiente:

rules_version = '2';
service cloud.firestore {
match /databases/{database}/documents {
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}

match /community_posts/{postId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update, delete: if request.auth != null
    && request.auth.uid == resource.data.uid;

  match /comments/{commentId} {
    allow read: if request.auth != null;
    allow create: if request.auth != null;
  }
}
  }
}

### 5. Corre la app

Nota: Este paso no es obligatorio, sin embargo sí es recomendado para desplegar la app directamente en un dispositivo celular.

Conecta tu dispositivo Android por USB (con depuración USB activada) o inicia un emulador, luego ejecuta:

```bash
flutter run
```

Si tienes varios dispositivos conectados y quieres elegir uno específico:

```bash
flutter devices        # lista los dispositivos disponibles
flutter run -d <id>    # corre en el dispositivo elegido
```

---

## APIs utilizadas

Aether usa dos APIs externas. Las credenciales de Spotify ya están incluidas en el código para facilitar la ejecución, pero se recomienda reemplazarlas por las tuyas propias en producción.

### Spotify API (datos de álbumes y búsqueda de artistas)
1. Ve a [Spotify for Developers](https://developer.spotify.com/dashboard)
2. Crea una app
3. Copia el `Client ID` y `Client Secret`
4. Pégalos en `lib/services/spotify_service.dart`:

```dart
static const _clientId = 'TU_CLIENT_ID';
static const _clientSecret = 'TU_CLIENT_SECRET';
```

### Deezer API (previews de audio para Echo)
No requiere configuración. Es una API pública gratuita que Aether usa automáticamente.

---

## Estructura del proyecto
lib/

├── core/
│   ├── constants.dart
│   └── firebase_options.dart
├── features/
│   ├── auth/
│   │   ├── login_page.dart
│   │   └── register_page.dart
│   ├── home/
│   │   ├── home_page.dart
│   │   ├── album_card.dart
│   │   ├── album_detail_sheet.dart
│   │   └── folder_detail_page.dart
│   ├── aethra/
│   │   └── aethra_page.dart
│   ├── community/
│   │   ├── community_page.dart
│   │   └── post_detail_page.dart
│   └── echo/
│       ├── echo_page.dart
│       ├── echo_game_page.dart
│       └── echo_result_page.dart
├── models/
│   ├── album_model.dart
│   └── chat_message.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── spotify_service.dart
│   ├── spotify_auth_service.dart
│   └── aethra_service.dart
├── profile_page.dart
└── main.dart

---

## Problemas comunes

**La app no compila / flutter doctor muestra errores**
→ Asegúrate de tener el Android SDK instalado y aceptar las licencias con:
```bash
flutter doctor --android-licenses
```

**Error: `google-services.json` no encontrado**
→ Verifica que el archivo esté exactamente en `android/app/google-services.json`

**Error de permisos en Firestore**
→ Verifica que las reglas de Firestore estén correctamente configuradas (paso 4)

**El audio en Echo no suena**
→ Verifica que el dispositivo no esté en silencio y que tenga conexión a internet activa

**Las imágenes no cargan**
→ Verifica la conexión a internet. Las imágenes vienen de Spotify CDN y Deezer CDN

---

## Funcionalidades en desarrollo

- [ ] Pantalla Pulse
- [ ] Moderación de comunidad (rol moderador)
- [ ] Foto de perfil real
- [ ] Notificaciones push
- [ ] Rating de estrellas persistente en Firestore
- [ ] Validación de username único al registrarse
- [ ] Migración de API keys a variables de entorno

---

## Autor

**Christian**  
Proyecto personal — desarrollado con Flutter.

---

## Licencia

Este proyecto es de uso académico. No está destinado a uso comercial.
