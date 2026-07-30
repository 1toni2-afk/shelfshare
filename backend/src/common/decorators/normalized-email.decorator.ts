import { applyDecorators } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsEmail } from 'class-validator';

/**
 * Câmp de email normalizat: taie spațiile și coboară la litere mici ÎNAINTE de
 * validare.
 *
 * Ordinea contează. `@IsEmail` respinge o adresă cu spațiu la capăt, iar
 * normalizarea din UsersService#findByEmail se aplică prea târziu - cererea
 * era deja oprită cu „Adresa de email nu este validă". Se întâmplă des la
 * copy-paste dintr-un email sau când tastatura de telefon adaugă un spațiu
 * după completarea automată.
 *
 * Litere mici aici, plus în UsersService, ca orice cale (login, înregistrare,
 * resetare de parolă) să compare adresele la fel - vezi comentariul de acolo
 * pentru de ce login-ul nu trebuie să fie sensibil la majuscule.
 */
export function IsNormalizedEmail() {
  return applyDecorators(
    Transform(({ value }) =>
      typeof value === 'string' ? value.trim().toLowerCase() : value,
    ),
    IsEmail({}, { message: 'Adresa de email nu este validă' }),
  );
}
