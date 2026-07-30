/// Linkurile prin care userii pot susține financiar aplicația.
///
/// ShelfShare rulează pe un server de acasă, pe cheltuiala dezvoltatorului -
/// secțiunea „About dev" + butonul „Keep the app alive" duc aici.
///
/// TODO(donations): pe Android varianta finală va fi Google Play Billing
/// (produs consumabil „coffee"), iar pe web PayPal. Până atunci ambele
/// platforme deschid linkurile externe de mai jos; înlocuiește valorile cu
/// conturile reale înainte de release.
class SupportLinks {
  const SupportLinks._();

  /// Buy Me a Coffee - folosit ca destinație implicită pe mobil.
  static const buyMeACoffee = 'https://www.buymeacoffee.com/shelfshare';

  /// PayPal.me - folosit pe web, unde nu există billing de Play Store.
  static const paypal = 'https://www.paypal.com/paypalme/shelfshare';

  /// Adresa de contact a dezvoltatorului, afișată în „About dev".
  static const contactEmail = 'contact@shelfshare.ro';
}
