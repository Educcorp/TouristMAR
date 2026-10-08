# Recorrido 360° por escenarios

Cómo funciona el recorrido 360° de punta a punta: qué hace el admin y qué ve el turista. **Lo hace Flutter, en la web y en la app móvil. Unity no participa** (Unity solo hace la RA con marcadores y la RA por geolocalización, ver `ra_geolocalizacion.md`).

## 1. Idea general (como Google Maps / Street View)

```
Mapa → pin del lugar → tarjeta (Cómo llegar · Ver ficha · "Ver en 360°")
                                    │
                                    ▼
             Recorrido360Page (Flutter, web y app móvil)
             widgets/recorrido360/visor_360.dart
                                    │
                                    ▼
                    GET {API}/recorridos  ·  GET {API}/recorridos/{nombre}
```

- Un **recorrido** tiene de 1 a 32 **escenarios**. Cada escenario es una foto 360° equirectangular (2:1) tomada desde un punto.
- Cada escenario tiene **flechas** que llevan a otros escenarios. Las coordenadas de una flecha son ángulos dentro de la foto, no GPS.
- El recorrido se liga a su lugar (`recorridos_360.negocio_id`), y en el mapa sale con **el pin del lugar** (`negocio_profiles.latitud/longitud`).
  - El pin lo fija el admin (`PUT /api/admin/negocios/:id/ubicacion`) o el dueño del negocio desde "Mapa y experiencias" (`PATCH /api/auth/profile/negocios/:id`).
  - El recorrido también guarda un pin propio opcional (`recorridos_360.latitud/longitud`, campo de coordenadas del formulario). **Solo se usa para un recorrido sin lugar**, que sale en el mapa como un pin aparte. Para un recorrido ligado a un lugar se ignora.
  - La **RA por geolocalización no usa nada del recorrido**: usa el pin del lugar y sus puntos de interés (`ra_geo_puntos`).

## 2. Flujo del admin (panel web → Mapa y RA)

1. **Mapa y RA → Registrar lugar** (se despliega con la flecha): nombre, categoría, dirección, **coordenadas** (pegadas de Google Maps o eligiendo el punto en el mapa) y descripción. El lugar aparece en el mapa y en la lista.
2. En la lista, **Revisar** abre la página del lugar (`/admin/mapa/lugar/<id>`). Ahí hay tres secciones que se despliegan con una flecha:
   - **RA por ubicación:** coordenadas y pin del lugar, y dirección.
   - **Recorrido 360°:** "Nuevo recorrido" (ya ligado al lugar y con su pin), y al abrir un recorrido, su editor:
     - **Subir escenarios:** todas las fotos de una vez (hasta 32), ordenadas por nombre de archivo; el primero es la **entrada**. JPG o PNG 2:1, mínimo 1280×640 y máximo 30 MB.
     - **Conectar en orden** crea las flechas 1↔2↔…↔N; en **Colocar flechas** se acomodan tocando el piso donde está el paso.
     - **Fijar vista inicial aquí:** hacia dónde mira el turista al entrar a ese escenario.
     - El interruptor de la lista lo publica u oculta.
   - **RA con marcador:** los marcadores del lugar (agregar, activar/ocultar, borrar).
3. Los recorridos creados antes de este cambio sin lugar aparecen en **Recorridos sin lugar** para asignarlos o borrarlos.

> Una foto 360° vista plana se ve curvada: es normal, es una esfera desplegada (como un mapamundi). Solo se ve "bien" envuelta en el visor.

## 3. Contrato `GET /api/recorridos/{nombre}`

```json
{
  "recorrido": {
    "nombre": "fime_explanada_360",
    "textoParaMostrar": "Facultad de Ingeniería Electromecánica\nRecorrido por la explanada.",
    "negocioId": "",
    "urlPortada": "https://…/min.jpg",
    "escenaInicial": "<id escenario 1>",
    "escenas": [
      {
        "id": "<id>",
        "titulo": "Explanada",
        "descripcion": "",
        "urlImagen": "https://…/<id>.jpg",
        "urlMiniatura": "https://…/<id>_min.jpg",
        "yawInicial": 60,
        "enlaces": [{ "destino": "<id escenario 2>", "yaw": 75, "pitch": -15, "etiqueta": "Edificio FIME" }]
      }
    ]
  }
}
```

**Ángulos (grados), iguales en backend y Flutter:**

| Campo | Rango | Significado |
|---|---|---|
| `yaw` / `yawInicial` | -180…180 | 0 = centro horizontal de la foto; positivo = a la derecha. `yaw = (x / ancho − 0.5) · 360` |
| `pitch` | -90…90 | 0 = horizonte; negativo = hacia el piso (las flechas suelen ir en -15…-25) |

El modelo en Flutter es `RecorridoPublico` (`apps/web/lib/services/recorridos_service.dart`).
