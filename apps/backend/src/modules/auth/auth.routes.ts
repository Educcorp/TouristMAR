import { Router } from 'express'
import { register, login, me } from './auth.controller'
import { requireAuth } from './auth.middleware'
import { passport } from '../../config/passport'
import { env, isGoogleAuthEnabled } from '../../config/env'
import { signToken } from './auth.service'
import type { User } from '@prisma/client'

export const authRouter = Router()

authRouter.post('/register', register)
authRouter.post('/login', login)
authRouter.get('/me', requireAuth, me)

if (isGoogleAuthEnabled) {
  authRouter.get('/google', passport.authenticate('google', { scope: ['profile', 'email'], session: false }))

  authRouter.get(
    '/google/callback',
    passport.authenticate('google', { session: false, failureRedirect: `${env.CORS_ORIGIN}/?error=google` }),
    (req, res) => {
      const user = req.user as User
      const token = signToken(user.id)
      res.redirect(`${env.CORS_ORIGIN}/?token=${token}`)
    },
  )
} else {
  authRouter.get('/google', (_req, res) => {
    res.status(503).json({ error: 'El login con Google todavía no está configurado en el servidor' })
  })
}
