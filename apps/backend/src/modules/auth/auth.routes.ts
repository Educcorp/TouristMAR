import { Router } from 'express'
import multer from 'multer'
import {
  register,
  login,
  me,
  updateProfile,
  updateNegocio,
  uploadAvatar,
  uploadNegocioPortadaHandler,
  uploadGaleriaImage,
  deleteGaleriaImage,
  createNegocioSuggestion,
  googleMobileLogin,
} from './auth.controller'
import { requireAuth } from './auth.middleware'
import { passport } from '../../config/passport'
import { env, isGoogleAuthEnabled } from '../../config/env'
import { signToken } from './auth.service'
import type { User } from '@prisma/client'

export const authRouter = Router()

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    cb(null, file.mimetype.startsWith('image/'))
  },
})

authRouter.post('/register', register)
authRouter.post('/login', login)
authRouter.get('/me', requireAuth, me)
authRouter.patch('/profile', requireAuth, updateProfile)
authRouter.post('/profile/avatar', requireAuth, upload.single('file'), uploadAvatar)
authRouter.post('/profile/negocios', requireAuth, createNegocioSuggestion)
authRouter.patch('/profile/negocios/:negocioId', requireAuth, updateNegocio)
authRouter.post('/profile/negocios/:negocioId/avatar', requireAuth, upload.single('file'), uploadNegocioPortadaHandler)
authRouter.post('/profile/negocios/:negocioId/galeria', requireAuth, upload.single('file'), uploadGaleriaImage)
authRouter.delete('/profile/negocios/:negocioId/galeria', requireAuth, deleteGaleriaImage)
authRouter.post('/google/mobile', googleMobileLogin)

if (isGoogleAuthEnabled) {
  authRouter.get('/google', passport.authenticate('google', { scope: ['profile', 'email'], session: false }))

  authRouter.get('/google/callback', (req, res, next) => {
    passport.authenticate(
      'google',
      { session: false },
      (err: Error | null, user: User | false, info: { message?: string } | undefined) => {
        if (err) {
          return res.redirect(`${env.CORS_ORIGIN}/?error=google`)
        }
        if (!user) {
          const message = info?.message ? `&message=${encodeURIComponent(info.message)}` : ''
          return res.redirect(`${env.CORS_ORIGIN}/?error=google${message}`)
        }
        const token = signToken(user.id)
        res.redirect(`${env.CORS_ORIGIN}/?token=${token}`)
      },
    )(req, res, next)
  })
} else {
  authRouter.get('/google', (_req, res) => {
    res.status(503).json({ error: 'El login con Google todavía no está configurado en el servidor' })
  })
}
