import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/auction.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../data/auctions_repository.dart';

class AuctionDetailScreen extends ConsumerStatefulWidget {
  const AuctionDetailScreen({super.key, required this.auctionId});
  final String auctionId;

  @override
  ConsumerState<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends ConsumerState<AuctionDetailScreen> {
  Auction? _auction;
  Object? _error;
  bool _isLoading = true;
  bool _isActing = false;
  final _bidController = TextEditingController();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auction = await ref.read(auctionsRepositoryProvider).getAuction(widget.auctionId);
      if (mounted) setState(() => _auction = auction);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'] is List
            ? (data['message'] as List).join(', ')
            : data['message'].toString();
      }
    }
    return context.l10n.auctionGenericError;
  }

  Future<void> _placeBid() async {
    final amount = double.tryParse(_bidController.text.trim().replaceAll(',', '.'));
    if (amount == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.addBookInvalidPrice)));
      return;
    }
    setState(() => _isActing = true);
    try {
      final updated = await ref.read(auctionsRepositoryProvider).placeBid(widget.auctionId, amount);
      if (mounted) {
        setState(() {
          _auction = updated;
          _bidController.clear();
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.auctionBidPlaced)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _buyNow() async {
    setState(() => _isActing = true);
    try {
      final updated = await ref.read(auctionsRepositoryProvider).buyNow(widget.auctionId);
      if (mounted) {
        setState(() => _auction = updated);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.auctionBoughtNow)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _toggleWatch() async {
    final auction = _auction;
    if (auction == null) return;
    setState(() => _isActing = true);
    try {
      if (auction.isWatching) {
        await ref.read(auctionsRepositoryProvider).unwatch(widget.auctionId);
      } else {
        await ref.read(auctionsRepositoryProvider).watch(widget.auctionId);
      }
      await _load();
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  String _remainingLabel(Auction auction) {
    final l10n = context.l10n;
    if (auction.hasEnded) return l10n.auctionEnded;
    final remaining = auction.endsAt.difference(DateTime.now());
    if (remaining.inHours >= 24) return l10n.auctionEndsInDays(remaining.inDays);
    if (remaining.inHours >= 1) return l10n.auctionEndsInHours(remaining.inHours);
    return l10n.auctionEndsInMinutes(remaining.inMinutes.clamp(1, 59));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.auctionTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const CenteredScrollable(child: CircularProgressIndicator())
              : _error != null
                  ? CenteredScrollable(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage(_error!)),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: _load, child: Text(l10n.commonRetry)),
                        ],
                      ),
                    )
                  : _buildContent(_auction!),
        ),
      ),
    );
  }

  Widget _buildContent(Auction auction) {
    final l10n = context.l10n;
    final book = auction.userBook.book;
    final hasEnded = auction.hasEnded;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(url: book.coverUrl, width: 90, height: 126),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: Theme.of(context).textTheme.titleMedium),
                  if (book.author != null)
                    Text(book.author!, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  if (auction.userBook.owner != null)
                    GestureDetector(
                      onTap: () => context.push(
                        '/users/${auction.userBook.owner!.id}',
                        extra: auction.userBook.owner,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: AppColors.mutedForeground),
                          const SizedBox(width: 4),
                          Text(
                            auction.userBook.owner!.name ?? l10n.commonUnknownUser,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(auction.isWatching ? Icons.bookmark : Icons.bookmark_border),
              onPressed: _isActing ? null : _toggleWatch,
              tooltip: l10n.auctionWatch,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.auctionCurrentPrice, style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          l10n.priceLei(auction.currentPrice.toStringAsFixed(0)),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_remainingLabel(auction), style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          '${auction.bids.length} ${l10n.auctionBidsCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                if (auction.reservePrice != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    auction.reserveMet ? l10n.auctionReserveMet : l10n.auctionReserveNotMet,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: auction.reserveMet ? Colors.green : AppColors.mutedForeground,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (hasEnded) ...[
          Card(
            color: AppColors.accent.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                auction.highestBidder != null && auction.reserveMet
                    ? l10n.auctionEndedWithWinner
                    : l10n.auctionEndedNoWinner,
              ),
            ),
          ),
        ] else if (!auction.isSeller) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bidController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.auctionBidAmountLabel(
                      auction.currentPrice.toStringAsFixed(0),
                    ),
                    suffixText: 'lei',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isActing ? null : _placeBid,
                child: Text(l10n.auctionPlaceBid),
              ),
            ],
          ),
          if (auction.canBuyNow && auction.buyNowPrice != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isActing ? null : _buyNow,
              child: Text(l10n.auctionBuyNowFor(auction.buyNowPrice!.toStringAsFixed(0))),
            ),
          ],
        ],
        const SizedBox(height: 24),
        Text(l10n.auctionBidHistory, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (auction.bids.isEmpty)
          Text(l10n.auctionNoBidsYet, style: Theme.of(context).textTheme.bodySmall)
        else
          ...auction.bids.map(
            (bid) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_outlined),
              title: Text(bid.bidder.displayName(l10n.commonUnknownUser)),
              subtitle: Text(_relativeTime(bid.createdAt)),
              trailing: Text(
                l10n.priceLei(bid.amount.toStringAsFixed(0)),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  String _relativeTime(DateTime time) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    return l10n.timeDaysAgo(diff.inDays);
  }
}
