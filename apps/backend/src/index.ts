import path from 'path'
import fs from 'fs'
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import morgan from 'morgan'
import { env } from './config/env'
import { passport } from './config/passport'
import { apiRouter } from './routes'

const app = express()
const publicDir = path.join(__dirname, '../public')
// Solo en producción: en dev el frontend real corre aparte (Flutter en modo
// desarrollo, ver el script `dev` en package.json). Si no se restringe por
// entorno, un build de Flutter (o restos de builds viejos) que quede suelto
// en `public/` se serviría igual en local y taparía el servidor de Flutter
// real, mostrando una versión vieja o incorrecta del frontend.
const hasFrontendBuild = env.NODE_ENV === 'production' && fs.existsSync(path.join(publicDir, 'index.html'))

app.use(
  helmet({
    contentSecurityPolicy: false,
    frameguard: false,
    // El default de helmet ('no-referrer') hace que el navegador no mande
    // Referer al pedir los mosaicos del mapa, y OpenStreetMap bloquea esas
    // peticiones (devuelve el mosaico "Access blocked"). Este es el default
    // de los navegadores: a otros sitios solo se manda el dominio, sin ruta.
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  }),
)
app.use(cors({ origin: env.CORS_ORIGIN, credentials: true }))
app.use(morgan('dev'))
app.use(express.json())
app.use(passport.initialize())

if (hasFrontendBuild) {
  app.use(express.static(publicDir))
}

app.get('/health', (_req, res) => res.json({ status: 'ok' }))
app.use('/api', apiRouter)

if (hasFrontendBuild) {
  app.get(/^(?!\/api).*/, (_req, res) => {
    res.sendFile(path.join(publicDir, 'index.html'))
  })
}

app.listen(Number(env.PORT), () => {
  console.log(`Backend escuchando en http://localhost:${env.PORT}`)
})
