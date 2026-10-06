# Recorrido 360° por escenarios

Cómo funciona el recorrido 360° de punta a punta: qué hace el admin, qué ve el turista y qué hay que configurar en Unity para que se vea igual que en la web.

## 1. Idea general (como Google Maps / Street View)

```
Mapa → pin del lugar → tarjeta (Cómo llegar · Ver ficha · "Ver en 360°")
                                                   │
                     ┌─────────────────────────────┴────────────────────────────┐
             Teléfono con Unity                                       Web (o teléfono sin Unity)
   MainActivity → UnityPlayerGameActivity                         Recorrido360Page (Flutter)
   extras: escena=recorrido, parametro=<nombre>,                  widgets/recorrido360/visor_360.dart
           apiBaseUrl=<API>
                     └──────────────► GET {API}/recorridos/{nombre} ◄────────────┘
```

- Un **recorrido** tiene de 1 a 32 **escenarios**. Cada escenario es una foto 360° equirectangular (2:1) tomada desde un punto.
- Cada escenario tiene **flechas** que llevan a otros escenarios. Las coordenadas de una flecha son ángulos dentro de la foto, no GPS.
- Las **coordenadas GPS son del lugar**, no del recorrido: son el pin del negocio en el mapa (`negocio_profiles.latitud/longitud`). El recorrido solo se liga al lugar (`recorridos_360.negocio_id`). Por eso no se capturan coordenadas al crear un recorrido.
  - El pin lo fija el admin desde el formulario del recorrido ("Fijar en el mapa", `PUT /api/admin/negocios/:id/ubicacion`).
  - El dueño del negocio también lo puede fijar desde "Mapa y experiencias" (`PATCH /api/auth/profile/negocios/:id`).
  - La RA por ubicación usa ese mismo pin; los marcadores RA no usan coordenadas.

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

**Ángulos (grados), iguales en backend, Flutter y Unity:**

| Campo | Rango | Significado |
|---|---|---|
| `yaw` / `yawInicial` | -180…180 | 0 = centro horizontal de la foto; positivo = a la derecha. `yaw = (x / ancho − 0.5) · 360` |
| `pitch` | -90…90 | 0 = horizonte; negativo = hacia el piso (las flechas suelen ir en -15…-25) |

Modelos C#: `Assets/Scripts/AR/ModelosRecorrido.cs`. Ojo: JsonUtility exige que los nombres coincidan **exacto**.

## 4. Unity: qué configurar

Scripts nuevos: `Assets/Scripts/Recorrido/VisorRecorrido360.cs` y `FlechaRecorrido360.cs`. Hacen lo mismo que el visor de Flutter. No están compilados en CI: ábrelos en Unity y revisa la consola.

### Escena "Recorrido"
1. **Main Camera** en (0,0,0), *Clear Flags = Skybox*, *Field of View* = 75.
2. **Material** nuevo `Recorrido360.mat`:
   - Shader `Skybox/Panoramic`
   - *Mapping*: **Latitude Longitude Layout**
   - *Image Type*: **360 Degrees**
   - *Rotation*: 0
   - Sin textura: la pone el script.
3. Un GameObject **VisorRecorrido** con `VisorRecorrido360`:
   - *Camara* = Main Camera; *Material Panoramico* = `Recorrido360.mat`; *Prefab Flecha* = el de abajo.
   - *Ajuste Yaw*: 0 (ver calibración).
   - *Recorrido Por Defecto*: el nombre de un recorrido real, para probar en el Editor. *Api Base Url Por Defecto*: `http://localhost:4000/api`.
4. **Canvas** (Screen Space – Overlay), con el mismo diseño que la app:
   - Arriba a la izquierda, una tarjeta negra al 55 % con esquinas redondeadas:
     - Botón ← que llama a `Salir()`.
     - `textoTitulo` (blanco, negrita, 15) y `textoEscena` (blanco 70 %, 12) → "Explanada · 1 de 16".
   - Arriba a la derecha, un botón ⟲ que llama a `VistaInicial()`.
   - Abajo a la izquierda, `panelDescripcion` + `textoDescripcion`.
   - Una `Image` negra a pantalla completa con `CanvasGroup` (alpha 0, *Blocks Raycasts* apagado) → campo *Fundido*.
   - Un spinner → *Indicador Cargando*.
   - Opcional, la tira de escenarios: botones que llaman a `IrAEscenarioIndice(i)`.
5. Que la escena "Arranque" abra "Recorrido" cuando el extra `escena` sea `recorrido`, igual que ya lo hace hoy. El script lee `parametro` y `apiBaseUrl` directo del Intent. Si ya existe `ParametrosApp.cs`, se puede usar ese.

### Prefab `FlechaRecorrido`
- Raíz con `FlechaRecorrido360` + **SphereCollider** (radio 0.35). Sin collider no se puede tocar.
- Hijo: **Canvas World Space** (escala 0.002), con:
  - Círculo blanco (alpha 0.92) de 48 px, borde de 3 px azul `#1D4ED8` y una flecha ↑ azul.
  - Debajo, una píldora negra al 60 % con el TMP `etiqueta` (blanco, 12, semibold) → campos *Etiqueta* y *Fondo Etiqueta*.
- El script la orienta siempre hacia la cámara.

### Calibración (una sola vez)
1. Abre en el Editor un recorrido cuya foto tenga algo reconocible justo en el **centro** de la imagen plana. Por ejemplo, en la foto de la FIME el camino con la cruz verde está al centro.
2. En el panel, deja ese escenario con *vista inicial* 0°.
3. Dale Play: la cámara debe mirar ese objeto. Si mira a otro lado, prueba *Ajuste Yaw* = 90, -90 o 180 hasta que coincida. Con eso coinciden también todas las flechas que puso el admin.
4. Comprueba el sentido: en el panel pon una flecha a la **derecha** del centro. En Unity también debe quedar a la derecha.

### Player Settings
- *Allow downloads over HTTP*: solo en desarrollo; producción usa https.
- Android: minSdk 29, igual que el módulo de RA.
- Texturas: una foto de 1280×640 pesa ~140 KB y ocupa ~3 MB en GPU. El script guarda solo la actual y sus vecinas.
