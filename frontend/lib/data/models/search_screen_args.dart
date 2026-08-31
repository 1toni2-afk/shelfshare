/// Stă aici, nu în `browse_screen.dart`, fiindcă îl folosește direct routerul
/// (`state.extra as SearchScreenArgs?`) - iar ecranul de căutare e încărcat
/// amânat, deci un import normal dinspre router l-ar fi tras înapoi în
/// bundle-ul inițial (vezi `core/router/deferred_screen.dart`).
/// Argumente opționale trimise ecranului de căutare din alte ecrane (ex.
/// wishlist trimite un titlu, Home trimite un gen din secțiunea Categorii).
class SearchScreenArgs {
  const SearchScreenArgs({
    this.title,
    this.author,
    this.genre,
    this.listingType,
    this.city,
    this.sort,
  });
  final String? title;
  final String? author;
  final String? genre;
  /// „swap" / „sale" / „auction" / „donation" - folosit de sheet-ul
  /// „Filtrează" din Discover.
  final String? listingType;
  final String? city;
  /// „popularity" / „recent" / „oldest" / „distance" - sheet-ul „Sortează"
  /// din Discover. „distance" are efect doar dacă userul are oraș setat în
  /// profil.
  final String? sort;
}
