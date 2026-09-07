import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import morgan from 'morgan'
import { env } from './config/env'
import { apiRouter } from './routes'

const app = express()

app.use(helmet())
app.use(cors({ origin: env.CORS_ORIGIN, credentials: true }))
app.use(morgan('dev'))
app.use(express.json())

app.get('/health', (_req, res) => res.json({ status: 'ok' }))
app.use('/api', apiRouter)

app.listen(Number(env.PORT), () => {
  console.log(`Backend escuchando en http://localhost:${env.PORT}`)
})
