import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user.dart';
import '../data/profile_repository.dart';

class ActivityFeedState {
  const ActivityFeedState({
    this.events = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.hasError = false,
  });

  final List<ActivityEvent> events;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasError;

  ActivityFeedState copyWith({
    List<ActivityEvent>? events,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? hasError,
  }) {
    return ActivityFeedState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// Feed paginat (vezi getActivityFeed în backend) - fără total count din
/// server, deci `hasMore` se deduce din faptul că ultima pagină a venit
/// plină (== _pageSize); o pagină parțială înseamnă că am ajuns la capăt.
class ActivityFeedController extends Notifier<ActivityFeedState> {
  static const _pageSize = 30;

  @override
  ActivityFeedState build() {
    _load();
    return const ActivityFeedState();
  }

  Future<void> _load() async {
    state = const ActivityFeedState();
    try {
      final events = await ref.read(profileRepositoryProvider).getActivityFeed(limit: _pageSize, offset: 0);
      state = ActivityFeedState(events: events, isLoading: false, hasMore: events.length == _pageSize);
    } catch (_) {
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  Future<void> refresh() => _load();

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final more = await ref
          .read(profileRepositoryProvider)
          .getActivityFeed(limit: _pageSize, offset: state.events.length);
      state = state.copyWith(
        events: [...state.events, ...more],
        isLoadingMore: false,
        hasMore: more.length == _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final activityFeedControllerProvider = NotifierProvider<ActivityFeedController, ActivityFeedState>(
  ActivityFeedController.new,
);
