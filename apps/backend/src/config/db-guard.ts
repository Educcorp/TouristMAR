import { Prisma } from '@prisma/client'

/// Se lanza cuando una tabla todavía no existe (típico justo después de un
/// deploy antes de correr migraciones) — separado del resto de errores para
/// que los controllers puedan responder 503 en vez de 500 en ese caso.
export class DatabaseNotReadyError extends Error {}

export async function withDbGuard<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn()
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2021') {
      throw new DatabaseNotReadyError(
        'Una tabla no existe todavía en la base de datos. Corre las migraciones de Prisma (npx prisma migrate dev).',
      )
    }
    throw err
  }
}
