# TouristMAR — app móvil (Flutter)

Reutiliza la app web completa como paquete (`touristmar_web: path: ../web`) y
solo reemplaza lo que depende de la plataforma (`lib/platform/`): guardado de
la sesión y login con Google. Todo lo de pantallas vive en `apps/web/lib`.

## Correr en un celular (desarrollo)

1. Backend corriendo en la PC: `npm run dev` (o `npm run dev --prefix apps/backend`).
2. Celular y PC en la **misma red Wi-Fi**.
3. Desde la raíz:

   ```bash
   npm run dev:mobile                  # detecta la IP de la PC
   npm run dev:mobile -- -d <device>   # elegir dispositivo (flutter devices)
   ```

   El script pasa `--dart-define=API_URL=http://<IP-de-tu-PC>:5173/api` (el
   mismo 5173 del sitio: `npm run dev` tiene que estar corriendo). Sin eso la
   app no sabe dónde está la API y **nada funciona** (ni el login ni la RA).

Para comprobar la conexión, abre en el navegador del celular la URL que
imprime el script (`http://<IP>:5173/api/marcadores`). Si no carga:

- Firewall de la PC: `sudo ufw allow 5173/tcp` (Linux con ufw).
- Que no estés en una red de invitados / con aislamiento de clientes.

Contra producción: `API_URL=https://<tu-dominio>/api npm run dev:mobile`.

### http vs https

- **Android**: el `http://` sin cifrar solo está permitido en builds de
  **debug** (`android/app/src/debug/AndroidManifest.xml`). Release exige https.
- **iOS**: `NSAllowsLocalNetworking` permite `http://` solo hacia la red local.

## Realidad aumentada

| Experiencia | Dónde | Estado |
|---|---|---|
| Mapa / RA por ubicación / 360° | web y móvil (pantallas compartidas) | Interfaz lista; datos de ejemplo (`LugaresService`) |
| **Marcadores** (usa la cámara) | solo móvil, módulo Unity | Backend y panel admin listos; falta integrar Unity |

Marcadores — cómo encaja todo:

```
Panel admin (web) ──> POST /api/admin/ar/marcadores ──> base + Supabase Storage
App móvil ──> abre Unity y le pasa API_URL ──> Unity: GET {API_URL}/marcadores
```

- Contrato del JSON y guía de Unity: `apps/ar-module/README.md`.
- Mensajes Flutter ⇄ Unity: `lib/ar_bridge/ar_bridge.dart`. Al abrir Unity se
  le manda la **misma** `apiUrl` que usa la app (`ArBridge.configurar(apiBaseUrl: apiUrl, …)`),
  así el módulo AR siempre consulta el mismo backend que el resto de la app.
- Permisos ya declarados: cámara en Android (`CAMERA`) e iOS
  (`NSCameraUsageDescription`).

Pendiente para integrar Unity (necesita el export del proyecto de Unity):

1. Exportar el módulo (flutter_unity_widget → *Export Android/iOS*) a
   `android/unityLibrary` / `ios/UnityLibrary`.
2. Agregar `flutter_unity_widget` a `pubspec.yaml` (antes del export rompe el
   build de Android, porque el plugin espera `:unityLibrary`).
3. En `lib/main.dart`, asignar `ExperienciasLauncher.current` con una
   implementación que abra la pantalla de Unity para `ExperienciaTipo.arMarcador`.
