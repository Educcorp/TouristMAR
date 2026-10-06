import sharp from 'sharp'

export class EscenaImagenInvalidaError extends Error {}

/// 4096×2048 es el tamaño de textura que aguantan bien los celulares de gama
/// media (y el máximo que conviene descargar por datos): una foto 360° de 8K
/// sale de la cámara con 15–25 MB y aquí queda en ~1–2 MB.
export const ESCENA_ANCHO_MAX = 4096
/// 1280×640 es lo que exporta la app de captura que usa el equipo (no hay
/// opción de más resolución). Se ve algo suave al hacer zoom, pero por
/// debajo de esto ya se nota pixelada en el visor.
export const ESCENA_ANCHO_MIN = 1280
const MINIATURA_ANCHO = 640

/// Tolerancia para el 2:1: algunas cámaras/apps de unión exportan unos
/// píxeles de más o de menos (p. ej. 6080×3040 exacto, pero 5760×2881).
const PROPORCION_MIN = 1.9
const PROPORCION_MAX = 2.1

export interface EscenaProcesada {
  imagen: Buffer
  miniatura: Buffer
  ancho: number
  alto: number
}

/// Valida que sea una foto 360° equirectangular (JPG/PNG, 2:1) y genera las
/// dos versiones que se guardan: la escena optimizada para Unity y una
/// miniatura para el panel. El original de la cámara nunca se guarda.
export async function procesarEscena(buffer: Buffer): Promise<EscenaProcesada> {
  const meta = await sharp(buffer)
    .metadata()
    .catch(() => {
      throw new EscenaImagenInvalidaError('No se pudo leer la imagen (usa una foto JPG o PNG)')
    })
  if (meta.format !== 'jpeg' && meta.format !== 'png') {
    throw new EscenaImagenInvalidaError('Formato no soportado para una escena 360° (usa JPG o PNG)')
  }

  // Orientación EXIF 5–8 = la foto está girada 90°: el ancho real es el alto.
  const girada = (meta.orientation ?? 1) >= 5
  const anchoOriginal = (girada ? meta.height : meta.width) ?? 0
  const altoOriginal = (girada ? meta.width : meta.height) ?? 0
  const proporcion = altoOriginal > 0 ? anchoOriginal / altoOriginal : 0

  if (proporcion < PROPORCION_MIN || proporcion > PROPORCION_MAX) {
    throw new EscenaImagenInvalidaError(
      `La foto mide ${anchoOriginal}×${altoOriginal}: una foto 360° equirectangular debe medir el doble de ancho que de alto (2:1)`,
    )
  }
  if (anchoOriginal < ESCENA_ANCHO_MIN) {
    throw new EscenaImagenInvalidaError(
      `La foto mide ${anchoOriginal}×${altoOriginal}: se necesitan al menos ${ESCENA_ANCHO_MIN}×${ESCENA_ANCHO_MIN / 2} px`,
    )
  }

  // Siempre 2:1 exacto (ancho par): la esfera de Unity mapea la textura
  // completa, así que unos píxeles de más se verían como una costura.
  const ancho = Math.min(anchoOriginal, ESCENA_ANCHO_MAX) & ~1
  const alto = ancho / 2

  const base = sharp(buffer).rotate()
  const [imagen, miniatura] = await Promise.all([
    base
      .clone()
      .resize({ width: ancho, height: alto, fit: 'fill' })
      // JPG baseline (no progresivo): lo decodifica cualquier versión de
      // Unity en Android/iOS. Por eso no `mozjpeg: true` (fuerza progresivo),
      // sino sus optimizaciones de tamaño una por una. Sin metadatos
      // (EXIF/GPS) — no hacen falta.
      .jpeg({
        quality: 82,
        progressive: false,
        trellisQuantisation: true,
        overshootDeringing: true,
        optimiseCoding: true,
        quantisationTable: 3,
      })
      .toBuffer(),
    base
      .clone()
      .resize({ width: MINIATURA_ANCHO, height: MINIATURA_ANCHO / 2, fit: 'fill' })
      .jpeg({ quality: 70, mozjpeg: true })
      .toBuffer(),
  ])

  return { imagen, miniatura, ancho, alto }
}
