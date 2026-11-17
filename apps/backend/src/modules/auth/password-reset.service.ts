import crypto from 'crypto'
import bcrypt from 'bcryptjs'
import { prisma } from '../../config/prisma'
import { env } from '../../config/env'
import { withDbGuard } from '../../config/db-guard'
import { enviarCorreo } from '../../config/mail'

/// Minutos que dura un código.
export const MINUTOS_VIGENCIA = 30
/// Intentos fallidos antes de invalidar el código.
export const MAX_INTENTOS = 5
/// Segundos mínimos entre dos códigos para el mismo usuario (evita spam y
/// gastar el límite diario de Brevo).
export const SEGUNDOS_ENTRE_ENVIOS = 60

/// Código incorrecto, caducado, ya usado o agotado: se responden igual para
/// no dar pistas.
export class CodigoInvalidoError extends Error {}

/// Solo se guarda el hash del código (HMAC con el secreto del servidor, ligado
/// al usuario): si alguien lee la tabla no puede usar los códigos.
function hashCodigo(userId: string, codigo: string) {
  return crypto.createHmac('sha256', env.JWT_SECRET).update(`${userId}:${codigo}`).digest('hex')
}

function iguales(a: string, b: string) {
  const ba = Buffer.from(a)
  const bb = Buffer.from(b)
  return ba.length === bb.length && crypto.timingSafeEqual(ba, bb)
}

function correoRecuperacion(nombre: string, codigo: string) {
  const asunto = `Tu código para recuperar tu contraseña: ${codigo}`
  const texto =
    `Hola ${nombre},\n\n` +
    `Tu código para restablecer tu contraseña de TouristMAR es: ${codigo}\n\n` +
    `Caduca en ${MINUTOS_VIGENCIA} minutos y solo se puede usar una vez.\n` +
    `Si tú no lo pediste, ignora este correo: tu contraseña no cambia.\n`
  const html = `<!doctype html>
<html lang="es"><body style="margin:0;background:#F4F7F6;font-family:Arial,Helvetica,sans-serif;color:#0B2A3A">
  <div style="max-width:480px;margin:0 auto;padding:32px 24px">
    <h1 style="font-size:22px;margin:0 0 16px">Recupera tu acceso a TouristMAR</h1>
    <p style="font-size:15px;line-height:1.5;margin:0 0 20px">Hola ${escaparHtml(nombre)}, usa este código en la app para crear una contraseña nueva:</p>
    <div style="font-size:34px;font-weight:bold;letter-spacing:8px;text-align:center;background:#FFFFFF;border:1px solid #D2DDDA;border-radius:12px;padding:18px 0;margin:0 0 20px">${codigo}</div>
    <p style="font-size:14px;line-height:1.5;color:#46636F;margin:0">Caduca en ${MINUTOS_VIGENCIA} minutos y solo se puede usar una vez. Si tú no lo pediste, ignora este correo: tu contraseña no cambia.</p>
  </div>
</body></html>`
  return { asunto, texto, html }
}

const ENTIDADES: Record<string, string> = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }

function escaparHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) => ENTIDADES[c] ?? c)
}

/**
 * Genera un código y lo manda por correo. Si el correo no tiene cuenta (o
 * está bloqueada) no hace nada y tampoco lo dice: la respuesta al cliente es
 * siempre la misma, para no revelar qué correos están registrados.
 */
export async function solicitarRecuperacion(email: string) {
  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { email } })
    if (!user || user.activo === false) return

    const reciente = await prisma.recuperacionPassword.findFirst({
      where: { userId: user.id, createdAt: { gt: new Date(Date.now() - SEGUNDOS_ENTRE_ENVIOS * 1000) } },
    })
    if (reciente) return

    const codigo = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0')

    // Un código nuevo invalida los anteriores que sigan pendientes.
    await prisma.recuperacionPassword.deleteMany({ where: { userId: user.id, usadoEn: null } })
    const registro = await prisma.recuperacionPassword.create({
      data: {
        userId: user.id,
        codigoHash: hashCodigo(user.id, codigo),
        expiraEn: new Date(Date.now() + MINUTOS_VIGENCIA * 60 * 1000),
      },
    })

    try {
      await enviarCorreo({ para: user.email, nombre: user.nombres, ...correoRecuperacion(user.nombres, codigo) })
    } catch (err) {
      // Si no salió el correo, el código no sirve de nada: se borra para que
      // el usuario pueda pedir otro de inmediato.
      await prisma.recuperacionPassword.delete({ where: { id: registro.id } }).catch(() => {})
      throw err
    }
  })
}

/** Verifica el código y cambia la contraseña. */
export async function restablecerPassword(email: string, codigo: string, nuevaPassword: string) {
  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { email } })
    if (!user || user.activo === false) throw new CodigoInvalidoError('El código es incorrecto o ya caducó')

    const registro = await prisma.recuperacionPassword.findFirst({
      where: { userId: user.id, usadoEn: null, expiraEn: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    })
    if (!registro || registro.intentos >= MAX_INTENTOS) {
      throw new CodigoInvalidoError('El código es incorrecto o ya caducó')
    }

    if (!iguales(registro.codigoHash, hashCodigo(user.id, codigo))) {
      const intentos = registro.intentos + 1
      await prisma.recuperacionPassword.update({
        where: { id: registro.id },
        // Al agotar los intentos se marca como usado: hay que pedir otro.
        data: { intentos, ...(intentos >= MAX_INTENTOS ? { usadoEn: new Date() } : {}) },
      })
      throw new CodigoInvalidoError(
        intentos >= MAX_INTENTOS ? 'Demasiados intentos. Pide un código nuevo' : 'El código es incorrecto o ya caducó',
      )
    }

    const passwordHash = await bcrypt.hash(nuevaPassword, 10)
    await prisma.$transaction([
      prisma.user.update({ where: { id: user.id }, data: { passwordHash } }),
      prisma.recuperacionPassword.update({ where: { id: registro.id }, data: { usadoEn: new Date() } }),
      prisma.recuperacionPassword.deleteMany({ where: { userId: user.id, usadoEn: null } }),
    ])
  })
}
