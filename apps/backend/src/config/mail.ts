import { env, isMailEnabled } from './env'

/// El servidor no tiene configurado el correo (faltan BREVO_API_KEY / MAIL_FROM).
export class MailNotConfiguredError extends Error {}
/// Brevo rechazó el envío (clave inválida, IP no autorizada, límite diario…).
export class MailSendError extends Error {}

interface Correo {
  para: string
  nombre?: string
  asunto: string
  html: string
  texto: string
}

/**
 * Manda un correo transaccional con la API HTTP de Brevo
 * (https://developers.brevo.com/reference/sendtransacemail).
 * Se usa HTTP y no SMTP porque Railway bloquea los puertos SMTP en los
 * planes Free/Hobby.
 */
export async function enviarCorreo({ para, nombre, asunto, html, texto }: Correo) {
  if (!isMailEnabled) {
    throw new MailNotConfiguredError('El envío de correos no está configurado en el servidor')
  }

  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': env.BREVO_API_KEY!,
      'content-type': 'application/json',
      accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { email: env.MAIL_FROM, name: env.MAIL_FROM_NAME },
      to: [{ email: para, ...(nombre ? { name: nombre } : {}) }],
      subject: asunto,
      htmlContent: html,
      textContent: texto,
    }),
  })

  if (!res.ok) {
    const detalle = await res.text().catch(() => '')
    // Se registra en los logs de Railway para poder diagnosticar (sin la clave).
    console.error(`[mail] Brevo respondió ${res.status}: ${detalle}`)
    throw new MailSendError('No se pudo enviar el correo')
  }
}
