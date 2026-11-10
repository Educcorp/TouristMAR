import { describe, it, expect, vi, beforeEach } from 'vitest'

vi.mock('dns', () => ({ promises: { resolveMx: vi.fn(), resolve4: vi.fn() } }))

import { promises as dns } from 'dns'
import { dominioDeCorreoExiste } from '../email-domain'

const resolveMx = vi.mocked(dns.resolveMx)
const resolve4 = vi.mocked(dns.resolve4)
const noExiste = () => Object.assign(new Error('no existe'), { code: 'ENOTFOUND' })

beforeEach(() => vi.clearAllMocks())

describe('dominioDeCorreoExiste', () => {
  it('acepta un dominio con registro MX', async () => {
    resolveMx.mockResolvedValue([{ exchange: 'mx.gmail.com', priority: 5 }])
    expect(await dominioDeCorreoExiste('ana@gmail.com')).toBe(true)
  })

  it('rechaza un dominio que no existe', async () => {
    resolveMx.mockRejectedValue(noExiste())
    resolve4.mockRejectedValue(noExiste())
    expect(await dominioDeCorreoExiste('ana@asdfghjkl-no-existe.com')).toBe(false)
  })

  it('acepta un dominio sin MX pero con IP', async () => {
    resolveMx.mockRejectedValue(Object.assign(new Error(), { code: 'ENODATA' }))
    resolve4.mockResolvedValue(['93.184.216.34'])
    expect(await dominioDeCorreoExiste('ana@ejemplo.mx')).toBe(true)
  })

  it('si el DNS falla por otra razón deja pasar el correo', async () => {
    resolveMx.mockRejectedValue(Object.assign(new Error(), { code: 'ETIMEOUT' }))
    expect(await dominioDeCorreoExiste('ana@empresa.com')).toBe(true)
  })

  it('rechaza un correo sin dominio con punto', async () => {
    expect(await dominioDeCorreoExiste('ana@localhost')).toBe(false)
  })
})
