import { Prisma, PrismaClient } from '@prisma/client';

/**
 * Rolul SUPER_ADMIN, citit din AdminRole.
 *
 * `User.isAdmin` nu ajunge: e true și pentru moderatori. Trăiește aici, nu în
 * SuperAdminGuard, ca să poată fi folosit și de servicii - importul de stoc
 * „în numele magazinului X" e un endpoint deschis tuturor (userii își importă
 * propriul CSV), deci verificarea nu se poate face cu un guard pe toată ruta.
 */
export async function isSuperAdmin(
  prisma: PrismaClient | Prisma.TransactionClient,
  userId: string,
): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { adminRole: { select: { name: true } } },
  });
  return user?.adminRole?.name === 'SUPER_ADMIN';
}
