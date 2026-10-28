import { prisma } from '../../config/prisma'
import { withDbGuard } from '../../config/db-guard'

export class CategoriaDuplicadaError extends Error {}
export class CategoriaNotFoundError extends Error {}

/// Las categorías con cuántos negocios usan cada una (el texto de
/// `negocio_profiles.categoria`, sin distinguir mayúsculas).
export async function listCategorias() {
  return withDbGuard(async () => {
    const [categorias, usos] = await Promise.all([
      prisma.categoriaNegocio.findMany({ orderBy: [{ orden: 'asc' }, { nombre: 'asc' }] }),
      prisma.negocioProfile.groupBy({ by: ['categoria'], _count: { _all: true } }),
    ])
    const porNombre = new Map<string, number>()
    for (const u of usos) {
      const clave = (u.categoria ?? '').trim().toLowerCase()
      porNombre.set(clave, (porNombre.get(clave) ?? 0) + u._count._all)
    }
    return categorias.map((c) => ({
      id: c.id,
      nombre: c.nombre,
      orden: c.orden,
      negocios: porNombre.get(c.nombre.toLowerCase()) ?? 0,
    }))
  })
}

async function assertNombreLibre(nombre: string, exceptoId?: string) {
  const igual = await prisma.categoriaNegocio.findFirst({
    where: { nombre: { equals: nombre, mode: 'insensitive' }, NOT: exceptoId ? { id: exceptoId } : undefined },
    select: { id: true },
  })
  if (igual) throw new CategoriaDuplicadaError('Ya existe una categoría con ese nombre')
}

export async function crearCategoria(nombre: string) {
  return withDbGuard(async () => {
    await assertNombreLibre(nombre)
    const ultima = await prisma.categoriaNegocio.findFirst({ orderBy: { orden: 'desc' }, select: { orden: true } })
    return prisma.categoriaNegocio.create({ data: { nombre, orden: (ultima?.orden ?? -1) + 1 } })
  })
}

/// Renombrar también actualiza los negocios que tenían el nombre viejo, para
/// que sigan agrupados bajo la misma categoría.
export async function renombrarCategoria(id: string, nombre: string) {
  return withDbGuard(async () => {
    const actual = await prisma.categoriaNegocio.findUnique({ where: { id } })
    if (!actual) throw new CategoriaNotFoundError('No se encontró esa categoría')
    await assertNombreLibre(nombre, id)
    return prisma.$transaction(async (tx) => {
      await tx.negocioProfile.updateMany({
        where: { categoria: { equals: actual.nombre, mode: 'insensitive' } },
        data: { categoria: nombre },
      })
      return tx.categoriaNegocio.update({ where: { id }, data: { nombre } })
    })
  })
}

/// Borrar una categoría no toca los negocios: conservan su texto y se pueden
/// reasignar desde su ficha.
export async function borrarCategoria(id: string) {
  return withDbGuard(async () => {
    const { count } = await prisma.categoriaNegocio.deleteMany({ where: { id } })
    if (count === 0) throw new CategoriaNotFoundError('No se encontró esa categoría')
  })
}
