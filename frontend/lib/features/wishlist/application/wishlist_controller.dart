import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/wishlist_item.dart';
import '../data/wishlist_repository.dart';

class WishlistController extends AsyncNotifier<List<WishlistItem>> {
  @override
  Future<List<WishlistItem>> build() {
    return ref.read(wishlistRepositoryProvider).getWishlist();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(wishlistRepositoryProvider).getWishlist());
  }

  /// Rândul de wishlist care aprinde inima pentru un anunț anume: întâi cel
  /// legat chiar de acel anunț, altfel unul „de titlu" (userBookId null, venit
  /// din Book Match). Fără [userBookId] se caută doar rândul de titlu - un
  /// favorit pus pe anunțul altcuiva nu trebuie să aprindă nimic altundeva.
  WishlistItem? rowFor(String bookId, {String? userBookId}) {
    WishlistItem? titleLevel;
    for (final item in state.value ?? const <WishlistItem>[]) {
      if (item.book.id != bookId) continue;
      if (userBookId != null && item.userBookId == userBookId) return item;
      if (item.userBookId == null) titleLevel = item;
    }
    return titleLevel;
  }

  bool isWishlisted(String bookId, {String? userBookId}) {
    return rowFor(bookId, userBookId: userBookId) != null;
  }

  /// Sursa rândului de wishlist pentru un anunț, sau null dacă nu e pe listă.
  /// Cardurile o folosesc ca să aleagă între inimă (PERSONAL) și iconița de
  /// Book Match - fără un apel separat pe card, lista e deja în memorie.
  WishlistSource? sourceFor(String bookId, {String? userBookId}) {
    return rowFor(bookId, userBookId: userBookId)?.source;
  }

  /// Scoatere necondiționată de pe wishlist, indiferent de sursă - folosită
  /// de butonul „×" din ecranul de Wishlist, unde intenția e mereu eliminarea
  /// (spre deosebire de `toggle`, care pe o sugestie din Book Match o
  /// confirmă ca favorit explicit în loc s-o elimine). Scoate titlul întreg,
  /// deci și eventualele favorite puse pe alte anunțuri ale aceleiași cărți.
  Future<void> removeItem(String bookId) async {
    final repository = ref.read(wishlistRepositoryProvider);
    final current = state.value ?? const [];
    await repository.removeFromWishlist(bookId);
    state = AsyncData(current.where((item) => item.book.id != bookId).toList());
  }

  /// [userBookId] = anunțul de pe care s-a apăsat inima. Favoritul e per
  /// exemplar: dacă „Ion" e listat de trei useri, inima apăsată pe anunțul
  /// unuia nu se mai aprinde și pe celelalte două.
  Future<void> toggle(String bookId, {String? userBookId}) async {
    final repository = ref.read(wishlistRepositoryProvider);
    final current = state.value ?? const [];
    final row = rowFor(bookId, userBookId: userBookId);
    if (row == null) {
      final added = await repository.addToWishlist(bookId, userBookId: userBookId);
      state = AsyncData([added, ...current]);
    } else if (row.source == WishlistSource.bookMatch) {
      // Deja pe wishlist ca sugestie din Book Match (scânteie) - primul tap
      // pe iconiță confirmă alegerea ca favorit explicit (inimă), nu o
      // elimină. Un remove real se face doar din ecranul de Wishlist.
      // Serverul ancorează rândul pe anunțul curent, deci îl înlocuim pe cel
      // vechi după id, nu după carte (titlul poate avea și alte favorite).
      final confirmed = await repository.addToWishlist(bookId, userBookId: userBookId);
      state = AsyncData([
        confirmed,
        ...current.where((item) => item.id != row.id && item.id != confirmed.id),
      ]);
    } else if (row.userBookId != null) {
      await repository.removeListingFromWishlist(row.userBookId!);
      state = AsyncData(current.where((item) => item.id != row.id).toList());
    } else {
      // Rând „de titlu" (fără anunț): serverul scoate titlul întreg, deci
      // și local curățăm tot ce ține de cartea asta.
      await repository.removeFromWishlist(bookId);
      state = AsyncData(current.where((item) => item.book.id != bookId).toList());
    }
  }
}

final wishlistControllerProvider = AsyncNotifierProvider<WishlistController, List<WishlistItem>>(
  WishlistController.new,
);
