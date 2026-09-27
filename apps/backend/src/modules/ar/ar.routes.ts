import { Router } from 'express'
import multer from 'multer'
import {
  listMarcadoresPublic,
  createEscaneo,
  listMarcadoresAdmin,
  createMarcadorAdmin,
  updateMarcadorAdmin,
  replaceImagenAdmin,
  deleteMarcadorAdmin,
} from './ar.controller'
import { optionalAuth, requireAuth, requireRole } from '../auth/auth.middleware'

/// Endpoints públicos que consume el módulo de Unity. Sin login: el turista
/// puede usar la cámara AR aunque no tenga cuenta.
export const arRouter = Router()

arRouter.get('/marcadores', listMarcadoresPublic)
arRouter.post('/marcadores/:id/escaneo', optionalAuth, createEscaneo)

// Imágenes grandes rastrean igual de bien que medianas y tardan más en
// descargarse en el celular; 5 MB alcanza de sobra para ~1000–2000 px.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
})

/// Gestión desde el panel web (se monta en /api/admin/ar).
export const arAdminRouter = Router()

arAdminRouter.use(requireAuth, requireRole('admin', 'super_admin'))

arAdminRouter.get('/marcadores', listMarcadoresAdmin)
arAdminRouter.post('/marcadores', upload.single('file'), createMarcadorAdmin)
arAdminRouter.patch('/marcadores/:id', updateMarcadorAdmin)
arAdminRouter.put('/marcadores/:id/imagen', upload.single('file'), replaceImagenAdmin)
arAdminRouter.delete('/marcadores/:id', deleteMarcadorAdmin)
