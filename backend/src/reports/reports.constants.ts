import { ReportReason, ReportTargetType } from '@prisma/client';

/**
 * Ce motive se pot alege, în funcție de ce se raportează.
 *
 * Enum-ul din baza de date e unul singur (`ReportReason`), fiindcă `Report` e
 * un singur model - dar listele OFERITE diferă: „profil fals" n-are sens pe o
 * recenzie, iar „conținut fals" n-are sens pe un user. Validarea se face pe
 * server (vezi ReportsService.create), nu doar în interfață, altfel perechea
 * motiv/țintă ar putea ajunge oricum în coada de moderare.
 */
export const REPORT_REASONS_BY_TARGET: Record<
  ReportTargetType,
  ReportReason[]
> = {
  // Conținut: spam / limbaj abuziv / conținut fals / conținut inadecvat / altul
  LISTING: ['SPAM', 'ABUSIVE_LANGUAGE', 'FALSE_CONTENT', 'INAPPROPRIATE', 'OTHER'],
  REVIEW: ['SPAM', 'ABUSIVE_LANGUAGE', 'FALSE_CONTENT', 'INAPPROPRIATE', 'OTHER'],
  GROUP_POST: ['SPAM', 'ABUSIVE_LANGUAGE', 'FALSE_CONTENT', 'INAPPROPRIATE', 'OTHER'],
  CONVERSATION: ['SPAM', 'ABUSIVE_LANGUAGE', 'FALSE_CONTENT', 'INAPPROPRIATE', 'OTHER'],

  // User: comportament abuziv / fraudă (nu respectă schimbul) / profil fals / altul
  USER: ['HARASSMENT', 'SCAM', 'FAKE_PROFILE', 'OTHER'],
  // Un schimb care nu s-a respectat e, în practică, o reclamație despre
  // celălalt participant - aceleași motive ca la user.
  EXCHANGE: ['HARASSMENT', 'SCAM', 'FAKE_PROFILE', 'OTHER'],
};

/**
 * Pragurile de auto-ascundere. Două ferestre, nu una: trei rapoarte într-o zi
 * înseamnă ceva acut (spam, insultă), zece într-o săptămână prind conținutul
 * care supără constant, dar mai lent. Se aplică oricare dintre ele.
 */
export const AUTO_HIDE_RULES = [
  { reports: 3, windowHours: 24 },
  { reports: 10, windowHours: 24 * 7 },
] as const;

/**
 * Ce tipuri de țintă POT fi ascunse automat. Un user nu se ascunde - pentru
 * conturi există suspendarea, care e o decizie umană (vezi AdminService.banUser).
 * O conversație nu se ascunde: e privată oricum, iar raportul păstrează deja
 * un transcript pentru moderator.
 */
export const AUTO_HIDEABLE_TARGETS: ReportTargetType[] = [
  'LISTING',
  'REVIEW',
  'GROUP_POST',
];

/**
 * Motivele care erau oferite pe ORICE țintă înainte de împărțirea de mai sus.
 *
 * Aplicațiile deja instalate trimit în continuare vechiul set (o versiune de
 * Android nu se actualizează în aceeași zi cu serverul), iar un 400 pe un
 * raport perfect legitim ar fi cea mai proastă regresie posibilă exact pe
 * fluxul de siguranță. Deci: validare strictă pentru motivele NOI, care nu pot
 * veni decât de la un client nou, și toleranță pentru cele vechi.
 *
 * De șters când nu mai sunt clienți pe versiuni anterioare listelor per țintă.
 */
export const LEGACY_UNIVERSAL_REASONS: ReportReason[] = [
  'SPAM',
  'SCAM',
  'INAPPROPRIATE',
  'HARASSMENT',
  'OTHER',
];
