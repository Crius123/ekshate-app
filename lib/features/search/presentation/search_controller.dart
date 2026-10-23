import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/daily_search_result.dart';
import '../data/search_repository.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Provider controlling debounce duration (defaults to 300ms).
final searchDebounceDurationProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 300);
});

/// Debounced Search Results Provider with 300ms Keystroke Throttle
final debouncedSearchResultsProvider = FutureProvider<List<DailySearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final category = ref.watch(selectedCategoryProvider)?.trim();
  final debounceDuration = ref.watch(searchDebounceDurationProvider);

  // If query is blank and no category is selected, return empty results immediately
  if (query.isEmpty && (category == null || category.isEmpty)) {
    return [];
  }

  // 300ms Debounce Delay with cancellation via ref.onDispose
  var isDisposed = false;
  ref.onDispose(() {
    isDisposed = true;
  });

  if (debounceDuration > Duration.zero) {
    await Future.delayed(debounceDuration);
  }

  if (isDisposed) {
    return [];
  }

  final repository = ref.read(searchRepositoryProvider);
  return repository.search(query, category: category);
});
