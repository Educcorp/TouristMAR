# TouristMAR — Guía Turística Digital de Manzanillo

App móvil (Android) + panel web con mapa por categorías, fichas 360°, valoraciones/comentarios y realidad aumentada (QR / marcadores / geolocalización), respaldada por una API centralizada sobre Supabase (PostgreSQL + PostGIS).

## Stack

| Capa | Tecnología |
|---|---|
| Backend / API | Node.js + Express, Prisma (ORM) |
| Base de datos | Supabase (PostgreSQL + PostGIS) |
| App móvil | React Native |
| Módulo AR | Unity (C#) + AR Foundation/ARCore, integrado como *Unity as a Library* dentro de RN |
| Panel web | React + TypeScript |
| Auth | Passport.js + JWT (correo/contraseña) y Google OAuth, o Supabase Auth |
| Storage | Supabase Storage (fotos 360°, imágenes) |
| Notificaciones | Push + SendGrid/Mailchimp (newsletter) |
| QR | `qrcode` (Node), generado en backend |
| Hosting | Railway (backend) + Supabase (BD/Storage) |

## Flujo de datos (regla de oro)

Ni la app móvil, ni Unity, ni el panel web hablan directo con Supabase: **todo pasa por el backend**. Esto centraliza permisos por rol, mantiene el mapa/AR/QR consistentes y evita duplicar lógica de negocio en cliente.

```
Mobile (RN) ──┐
Unity AR ─────┼──> API (Express) ──> Prisma ──> Supabase (Postgres+PostGIS / Storage)
Web (React) ──┘
```

Ciclo de vida de un lugar: `usuario propone → admin revisa → admin toma fotos 360°/genera AR → admin publica → visible para todos` (estados `draft → review → published` en backend).

## Estructura de carpetas

```
apps/
  backend/            API REST (Express), lógica de negocio, auth, RBAC, generación de QR
    src/
      config/          conexión BD, env, Supabase client
      modules/          un submódulo por dominio (lugares, usuarios, comentarios, favoritos, ar, notificaciones)
      middlewares/       auth/roles, validación, manejo de errores
      routes/            definición de endpoints
      jobs/              tareas programadas (newsletter, push)
    prisma/
      migrations/        migraciones versionadas (incluye setup de PostGIS)
      seed/               datos iniciales (mínimo 1 lugar por categoría)

  mobile/             App React Native (Android) — mapa, login, fichas, comentarios, favoritos, form. de registro de lugar
    src/
      screens/
      components/
      navigation/
      services/          clientes HTTP hacia el backend
      ar-bridge/          puente RN <-> Unity as a Library (abrir/cerrar módulo AR, pasar datos de QR/geo)

  ar-module/          Proyecto Unity (C#) — 100% del requisito C# del curso
    Assets/
      Scripts/           lectura de QR, anclaje por geolocalización, marcadores
      Prefabs/
      Scenes/

  web/                Panel web (React + TS) — dashboard, gestión de solicitudes, estadísticas
    src/
      pages/
      components/
      dashboard/          gráficas, lugares más visitados, flags
      services/

packages/
  shared-types/        tipos/DTOs compartidos entre backend, web y mobile (lugar, usuario, rol, review, etc.)
  shared-config/        eslint/tsconfig/prettier compartidos

database/
  scripts/             scripts sueltos de mantenimiento/consultas geoespaciales ad-hoc

docs/                 entregables del protocolo
  srs/                 documento de requerimientos (ISO 830-1998)
  uml/                 diagramas UML / ER
  wireframes/
  manuals/             manual técnico + manual de usuario
  reports/             reporte de protocolo, avances, final
  architecture/         diseño de arquitectura

qa/
  test-cases/          casos de prueba

infra/                config de despliegue (Railway, variables de entorno de ejemplo)
scripts/               scripts de repo (setup, seed, utilidades)
.github/workflows/     CI (a definir)
```

## Roles del equipo → dueño de carpeta

| Rol | Responsabilidad | Carpeta(s) principal(es) |
|---|---|---|
| Backend | API, lógica de negocio, autenticación | `apps/backend/` |
| Base de datos / modelado | Modelo E-R, migraciones, consultas geoespaciales, soporte a backend | `apps/backend/prisma/`, `database/` |
| Tester | Casos de prueba, pruebas funcionales | `qa/` |
| Especialista en AR | Lectura QR/marcadores, geolocalización, módulo AR completo (dueño único de la Tarea 2 del maestro) | `apps/ar-module/`, `apps/mobile/src/ar-bridge/` |
| Frontend web/dashboard | Panel de administración, estadísticas, gestión de solicitudes | `apps/web/` (y soporte en `apps/mobile/` cuando aplique) |
| Líder técnico UX/UI + docs | Mockups, flujos de usuario, documentación, diagramas UML/ER, pruebas funcionales | `docs/`, apoyo transversal en `apps/mobile/` y `apps/web/` |

## Backlog / prioridades (a completar)

- [ ] Tarea 1: login Google + correo/contraseña, registro
- [ ] Tarea 2: lectura AR por cámara (prioridad geolocalización), ≥1 lugar por sección, datos desde BD
- [ ] Investigación: tipo de AR ideal (geolocalización vs QR vs marcadores) — pendiente de confirmar con el maestro qué significa "libros"/"marcadores"
- [ ] CRUD de lugares + categorías
- [ ] Formulario "registrar lugar nuevo" + flujo de aprobación admin
- [ ] Comentarios, valoraciones, favoritos
- [ ] Fotos 360°
- [ ] Dashboard con estadísticas (lugares más visitados, flags)
- [ ] Notificaciones push + newsletter
