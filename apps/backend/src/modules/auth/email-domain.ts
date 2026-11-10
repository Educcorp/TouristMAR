import { promises as dns } from 'dns'

/// ¿El dominio del correo existe y puede recibir correo? Se pide su registro
/// MX (o, si no tiene, una IP: el estándar permite entregar ahí). Atrapa
/// correos inventados como `ana@asdfgh.com`. Si el DNS no contesta a tiempo
/// (sin red, servidor caído) se acepta: mejor dejar pasar un correo que
/// bloquear a todos los que se registran.
export async function dominioDeCorreoExiste(email: string, timeoutMs = 4000): Promise<boolean> {
  const dominio = email.split('@')[1]?.trim().toLowerCase()
  if (!dominio || !dominio.includes('.')) return false

  const consulta = (async () => {
    try {
      const mx = await dns.resolveMx(dominio)
      if (mx.some((r) => r.exchange && r.exchange !== '.')) return true
    } catch (err) {
      if (!esNoExiste(err)) return true
    }
    try {
      const ips = await dns.resolve4(dominio)
      return ips.length > 0
    } catch (err) {
      return !esNoExiste(err)
    }
  })()

  let timer: NodeJS.Timeout | undefined
  const limite = new Promise<boolean>((resolve) => {
    timer = setTimeout(() => resolve(true), timeoutMs)
  })
  try {
    return await Promise.race([consulta, limite])
  } finally {
    clearTimeout(timer)
  }
}

/// Solo "el dominio no existe / no tiene ese registro" cuenta como inválido;
/// cualquier otro error (timeout, sin red) no es culpa del correo.
function esNoExiste(err: unknown) {
  const code = (err as NodeJS.ErrnoException)?.code
  return code === 'ENOTFOUND' || code === 'ENODATA' || code === 'ENONAME'
}
