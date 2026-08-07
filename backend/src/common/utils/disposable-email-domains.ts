// Non-exhaustive list of well-known disposable/temporary email providers,
// blocked at registration only (not login - we don't want to lock out
// accounts that registered before this list existed).
const DISPOSABLE_EMAIL_DOMAINS = new Set([
  '10minutemail.com',
  '10minutemail.net',
  '20minutemail.com',
  'guerrillamail.com',
  'guerrillamail.net',
  'guerrillamail.org',
  'guerrillamail.biz',
  'guerrillamailblock.com',
  'sharklasers.com',
  'mailinator.com',
  'mailinator.net',
  'mailinator.org',
  'tempmail.com',
  'temp-mail.org',
  'temp-mail.io',
  'tempinbox.com',
  'throwawaymail.com',
  'yopmail.com',
  'yopmail.fr',
  'yopmail.net',
  'trashmail.com',
  'trashmail.net',
  'fakeinbox.com',
  'getnada.com',
  'moakt.com',
  'dispostable.com',
  'mintemail.com',
  'maildrop.cc',
  'mohmal.com',
  'emailondeck.com',
  '33mail.com',
  'discard.email',
  'spamgourmet.com',
]);

export function isDisposableEmailDomain(email: string): boolean {
  const domain = email.split('@')[1]?.toLowerCase().trim();
  return !!domain && DISPOSABLE_EMAIL_DOMAINS.has(domain);
}
