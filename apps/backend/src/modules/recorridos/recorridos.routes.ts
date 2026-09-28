import { Router, type RequestHandler } from 'express'
import multer from 'multer'
import {
  listRecorridosPublic,
  getRecorridoPublic,
  listRecorridosAdmin,
  createRecorridoAdmin,
  updateRecorridoAdmin,
  deleteRecorridoAdmin,
  setEscenaAdmin,
  deleteEscenaAdmin,
} from './recorridos.controller'
import { requireAuth, requireRole } from '../auth/auth.middleware'

/// Endpoints públicos que consume el módulo de Unity (se monta en
/// /api/recorridos). Sin login, igual que los marcadores.
export const recorridosRouter = Router()

recorridosRouter.get('/', listRecorridosPublic)
recorridosRouter.get('/:nombre', getRecorridoPublic)

// Una foto 360° de 8K sale de la cámara con 15–25 MB. Solo se sostiene en
// memoria mientras se optimiza (se guarda ya reducida).
const MAX_MB = 30
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_MB * 1024 * 1024 },
})

/// Como `upload.single('file')`, pero responde un JSON entendible si la foto
/// pasa del límite (por defecto multer dejaría un 500 genérico).
const subirEscena: RequestHandler = (req, res, next) => {
  upload.single('file')(req, res, (err: unknown) => {
    if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ error: `La foto pesa más de ${MAX_MB} MB` })
    }
    if (err) return next(err)
    return next()
  })
}

/// Gestión desde el panel web (se monta en /api/admin/recorridos).
export const recorridosAdminRouter = Router()

recorridosAdminRouter.use(requireAuth, requireRole('admin', 'super_admin'))

recorridosAdminRouter.get('/', listRecorridosAdmin)
recorridosAdminRouter.post('/', createRecorridoAdmin)
recorridosAdminRouter.patch('/:id', updateRecorridoAdmin)
recorridosAdminRouter.delete('/:id', deleteRecorridoAdmin)
// :posicion = 1, 2 o 3 ("Foto 1"…). PUT sube o reemplaza la foto de esa casilla.
recorridosAdminRouter.put('/:id/escenas/:posicion', subirEscena, setEscenaAdmin)
recorridosAdminRouter.delete('/:id/escenas/:posicion', deleteEscenaAdmin)
