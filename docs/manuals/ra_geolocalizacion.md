# RA por geolocalización

Cómo funciona la realidad aumentada basada en geolocalización (Location-based AR / GPS AR) de punta a punta: qué hace el admin, qué ve el turista, qué API consumen Flutter y Unity, y qué hay que configurar en Unity.

## 1. Idea general: capas por distancia

Cada lugar tiene **puntos de interés** (la entrada de FIME, su explanada, un mural…). Cada punto tiene sus coordenadas y **dos radios**:

| Distancia del turista al punto | Qué ve | Quién lo hace |
|---|---|---|
| Fuera del `radioVisible` | Guía: "El punto más cercano está a 500 m hacia el norte" | Flutter |
| Dentro del `radioVisible` (≈100 m) | **Marcador flotante** en la cámara, en la dirección real del punto, con título, resumen y distancia. Si el punto no está en la vista: "Gira a la derecha 90°" | Flutter |
| Dentro del `radioCercano` (≈5–10 m) | **Guía completa** (información, imagen, audio) y, si el lugar tiene marcadores de imagen, el botón **"Abrir RA con marcadores"** | Flutter → **Unity** |

A corta distancia el GPS ya no es preciso (falla 5–15 m). Por eso la experiencia de alta precisión la hacen los **marcadores de imagen** colocados en el lugar, que reconoce Unity con ARCore.

Si un lugar no tiene puntos dados de alta, **su pin hace de punto único** (radio visible de 100 m y cercano de 10 m, con la descripción del lugar). Así cualquier lugar con pin ya tiene RA por geolocalización.

```
Ficha del lugar / "Cómo llegar"
        │
        ▼
RA por geolocalización (Flutter: cámara + GPS + brújula)      ← web y app móvil
  GET {API}/ra/lugares/{lugarId}
        │  al entrar al radioCercano y si tieneMarcadores
        ▼
"Abrir RA con marcadores" → Unity, escena "marcadores"        ← solo app móvil
  extras: escena=marcadores, lugarId={lugarId}, apiBaseUrl={API}
  GET {API}/marcadores?negocioId={lugarId}
```

**El lugar siempre se identifica por su `id`**, el mismo en Flutter, en Unity y en la base de datos. Ejemplo: FIME = `f24442e4-6613-4427-99df-a7f962d6b99e`.

## 2. Admin (panel web → Mapa y RA)

1. **Mapa y RA → Revisar** abre el lugar (`/admin/mapa/lugar/<id>`).
2. Despliega **RA por geolocalización**:
   - Arriba, el **pin y la dirección del lugar**: "Guardar ubicación".
   - Abajo, **Puntos de interés**, con un mapa en el que cada punto tiene dos círculos: el claro es el radio visible y el fuerte el radio cercano.
3. **Agregar punto**:
   - **Título** y **resumen**: se leen desde lejos, en el marcador flotante.
   - **Guía completa**: se abre al llegar.
   - **Imagen** y **audio** (opcionales): enlace `https://…` a un JPG/PNG y a un MP3.
   - **Coordenadas**: pegadas de Google Maps (`19.1239, -104.4000`) o tocando el mapa.
   - **Radio visible** (20–500 m) y **radio cercano** (3–100 m, siempre menor).
4. Cada punto se puede editar, ocultar o borrar.
5. Para el paso a Unity: da de alta los marcadores del lugar en **RA con marcador**, ligados a ese lugar. Con al menos uno activo, la API marca `tieneMarcadores: true`.

## 3. API (pública, sin login)

La API está en el **5173**, junto con el sitio:

| Entorno | Base |
|---|---|
| Tu PC (`npm run dev`) | `http://localhost:5173/api` |
| Celular en la misma red Wi-Fi | `http://<IP-de-la-PC>:5173/api` |
| Producción | `https://touristmar-production.up.railway.app/api` |

`{API}` es solo la **base**: los endpoints van después (`{API}/ra/lugares/{lugarId}`). Abrir la base sola (`https://touristmar-production.up.railway.app/api`) responde un JSON con `"estado": "ok"` y la lista de rutas públicas; sirve para comprobar que la API está arriba. Una ruta que no existe responde `404` con `{"error": "No existe GET /api/…"}`, siempre en JSON.

### `GET {API}/ra/lugares/{lugarId}`

```json
{
  "lugar": {
    "id": "f24442e4-6613-4427-99df-a7f962d6b99e",
    "nombre": "Facultad de ingenieria electromecanica",
    "categoria": "Otro",
    "textoParaMostrar": "Facultad de ingenieria electromecanica\nUniversidad de Colima Campus El Naranjo",
    "direccion": "Carretera Manzanillo-Cihuatlán kilómetro 20, El Naranjo, 28860 Manzanillo, Col.",
    "urlPortada": "https://…/portada?v=…",
    "latitud": 19.12397051892223,
    "longitud": -104.4000125955125,
    "puntos": [
      {
        "id": "f24442e4-6613-4427-99df-a7f962d6b99e",
        "titulo": "Facultad de ingenieria electromecanica",
        "resumen": "Universidad de Colima Campus El Naranjo",
        "detalle": "Universidad de Colima Campus El Naranjo",
        "urlImagen": "https://…/portada?v=…",
        "urlAudio": "",
        "latitud": 19.12397051892223,
        "longitud": -104.4000125955125,
        "radioVisible": 100,
        "radioCercano": 10
      }
    ],
    "radioMetros": 100,
    "tieneMarcadores": false
  }
}
```

- **Nunca hay `null`**: lo que falta llega como `""`, porque el `JsonUtility` de Unity no maneja `null`.
- **`puntos` nunca viene vacío**: sin puntos dados de alta, trae el pin del lugar.
- **`radioMetros`** existe solo por compatibilidad con la primera versión del contrato; en código nuevo se usa `puntos`.
- **`404`**: el lugar no existe, no está aprobado o no tiene pin.
- **Otras formas:**
  - `GET {API}/ra/lugares`: todos los lugares con pin, en `{ "lugares": [ … ] }`.
  - `GET {API}/ra/lugares?buscar=electromecanica`: busca por nombre, sin importar acentos ni mayúsculas.

### `GET {API}/marcadores?negocioId={lugarId}`

Los marcadores de imagen de ese lugar, con el mismo contrato de siempre (`{ "marcadores": [ { "nombre", "urlImagen", "textoParaMostrar" } ] }`). Sin `negocioId` devuelve todos, como antes.

## 4. App móvil → Unity

`MainActivity.kt` abre Unity (`UnityPlayerGameActivity`) con estos **extras del Intent**:

| Extra | Valor |
|---|---|
| `escena` | `marcadores`, `recorrido` o `geo` |
| `parametro` | en `recorrido`: nombre del recorrido; en `geo`: id del lugar |
| `apiBaseUrl` | la misma API que usa la app (ej. `https://touristmar-production.up.railway.app/api`) |
| `lugarId` | **id del lugar** (siempre que se abre desde un lugar) |

Por defecto la RA por geolocalización la hace **Flutter**. Si algún día la quieren en Unity, se compila la app con `--dart-define=RA_GEO_EN_UNITY=true`: la app abre la escena `geo` de Unity con `parametro` = id del lugar.

## 5. Unity: qué configurar

Scripts del repo, en `apps/ar-module/Assets/Scripts/`:

| Script | Para qué |
|---|---|
| `Bridge/ParametrosApp.cs` | Lee los extras (`Escena`, `Parametro`, `ApiBaseUrl`, `LugarId`). En el Editor usa valores por defecto (API `http://localhost:5173/api`, lugar FIME). |
| `Bridge/Arranque.cs` | Escena **Arranque**, la primera en *Build Profiles → Scene List*: carga la escena según `escena`. Escribe en el Inspector los nombres de tus escenas. |
| `AR/ModelosLugarRA.cs` | Clases del JSON de `/ra/lugares` (`DatosLugarRA`, `DatosPuntoRA`, …). |
| `AR/CargadorLugarRA.cs` | Pide `/ra/lugares/{lugarId}`. Nunca deja `puntos` en `null`: si la respuesta viene en el formato anterior, arma el punto con el pin. |
| `AR/MarcadorDinamico.cs` + `Bridge/PuenteApp.cs` | Escena de marcadores: con `lugarId` baja solo los marcadores de ese lugar. |

Ejemplo de lectura de los puntos (escena `geo`, si la hacen en Unity):

```csharp
StartCoroutine(CargadorLugarRA.Cargar(ParametrosApp.ApiBaseUrl, ParametrosApp.LugarId,
    lugar =>
    {
        foreach (var p in lugar.puntos)
        {
            // distancia <= p.radioVisible → marcador flotante (p.titulo, p.resumen)
            // distancia <= p.radioCercano → pasar a los marcadores de imagen del lugar
        }
    },
    error => Debug.LogWarning(error)));
```

## 6. Probar

1. **Prueba con FIME:** `https://touristmar-production.up.railway.app/api/ra/lugares/f24442e4-6613-4427-99df-a7f962d6b99e`. Abierta en el navegador debe mostrar el JSON de arriba.
2. **Web:** ficha del lugar → Experiencias inmersivas → RA por geolocalización. Necesita `https` (o `localhost`) para la cámara y la ubicación.
3. **App móvil:** `npm run dev:mobile` (contra tu PC) o compilar con `--dart-define=API_URL=https://touristmar-production.up.railway.app/api`.
4. **Unity en el Editor:** sin app, `ParametrosApp` usa la API local y FIME.

## 7. Problemas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `NullReferenceException` en `lugar.puntos` | La API está en la versión anterior (sin `puntos`) | Usar `CargadorLugarRA`, o desplegar la versión nueva |
| Unity: "Insecure connection not allowed" | URL con `http://` | *Player → Allow downloads over HTTP* (solo en desarrollo) |
| El celular no conecta a la PC | Firewall o red distinta | `sudo ufw allow 5173/tcp`; misma red Wi-Fi |
| El marcador flotante sale desviado | Brújula sin calibrar | Mover el celular en forma de "8" |
| No aparece "Abrir RA con marcadores" | El lugar no tiene marcadores activos (`tieneMarcadores: false`) | Darlos de alta en Mapa y RA → RA con marcador |
