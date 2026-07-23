import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/auction.dart';

class AuctionsRepository {
  AuctionsRepository(this._ref);
  final Ref _ref;

  Future<Auction> createAuction(
    String userBookId, {
    required double startingPrice,
    double? reservePrice,
    double? buyNowPrice,
    required int durationHours,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/books/$userBookId/auctions', data: {
      'startingPrice': startingPrice,
      'reservePrice': ?reservePrice,
      'buyNowPrice': ?buyNowPrice,
      'durationHours': durationHours,
    });
    return Auction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Auction> getAuction(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/auctions/$id');
    return Auction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Auction> placeBid(String auctionId, double amount) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/auctions/$auctionId/bids', data: {'amount': amount});
    return Auction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Auction> buyNow(String auctionId) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/auctions/$auctionId/buy-now');
    return Auction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> watch(String auctionId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.post('/auctions/$auctionId/watch');
  }

  Future<void> unwatch(String auctionId) async {
    final dio = _ref.read(apiClientProvider).dio;
    await dio.delete('/auctions/$auctionId/watch');
  }

  Future<List<Auction>> getMyBids() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/auctions/my-bids');
    return (response.data as List)
        .map((e) => Auction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Auction>> getMyWatches() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/auctions/my-watches');
    return (response.data as List)
        .map((e) => Auction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final auctionsRepositoryProvider = Provider<AuctionsRepository>((ref) {
  return AuctionsRepository(ref);
});
