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
const hasFrontendBuild = fs.existsSync(path.join(publicDir, 'index.html'))

app.use(
  helmet({
    contentSecurityPolicy: false,
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
