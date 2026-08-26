import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../helper/filter_helper.dart';
import '../helper/log_color.dart';
import '../helper/utils.dart';
import '../serialized/filter_data.dart';

/// Provides shared state-management behavior for asynchronous data sources.
///
/// Subclasses use this base class to expose request state through [data],
/// [error], [loading], [stream], and [notifyListeners]. Callers typically
/// listen with widgets such as `AnimatedBuilder`, `ListenableBuilder`, or a
/// provider-based listener, while lower-level consumers can subscribe to
/// [stream] for data changes and [streamError] for failures.
///
/// The class centralizes pagination, query parameters, filter encoding,
/// selection state, debounced notifications, and request lifecycle resets so
/// concrete implementations such as API, document, and collection states can
/// focus on their own fetch logic.
abstract class StateShared extends ChangeNotifier {
  /// Indicates whether the current source has completed its first successful
  /// load.
  ///
  /// Many debounce and lifecycle decisions depend on this flag so initial
  /// updates can be handled more conservatively than subsequent refreshes.
  bool initialized = false;

  /// Counts consecutive errors to guard against retry loops caused by bad
  /// configuration or unstable listeners.
  int errorCount = 0;

  /// Caps streamed response sizes in bytes to avoid processing unexpectedly
  /// large payloads in subclasses that read chunked responses.
  int maxResponseBytes = 1 * 1024 * 1024; // 1 MiB

  /// Broadcasts raw data updates after [_notifyData] finishes its debounce.
  ///
  /// Consumers that need push-style updates without rebuilding from
  /// [notifyListeners] can subscribe to [stream].
  /// ignore: close_sinks
  final _controllerStream = StreamController<dynamic>.broadcast();

  /// Broadcasts error updates whenever [error] changes.
  ///
  /// This is useful for transient UI reactions such as snack bars that should
  /// not depend on a widget rebuild.
  /// ignore: close_sinks
  final _controllerStreamError = StreamController<String?>.broadcast();

  /// Exposes debounced data updates for consumers that prefer a [Stream].
  Stream<dynamic> get stream => _controllerStream.stream;

  /// Exposes debounced error updates for consumers that react to failures.
  Stream<String?> get streamError => _controllerStreamError.stream;

  /// Stores the last value assigned through [data] so identical assignments can
  /// be ignored.
  ///
  /// This lightweight guard prevents easy infinite loops when a listener feeds
  /// the same object back into the state.
  dynamic privateOldData;

  /// Stores the current raw value for [data].
  dynamic privateData;

  /// Returns the current state payload.
  ///
  /// Concrete subclasses usually assign maps, lists, or serialized response
  /// objects here. Listeners rebuild or react when the setter updates it.
  dynamic get data => privateData;

  /// Does nothing when no custom [callback] has been registered.
  void callbackDefault(dynamic data) {}

  /// Stores the callback invoked after debounced data delivery completes.
  Function(dynamic data)? _callback;

  /// Runs after [data] updates have been published.
  ///
  /// Use this for side effects that should happen alongside listener updates,
  /// such as chaining dependent requests or synchronizing external caches.
  Function(dynamic data) get callback => _callback ?? callbackDefault;

  /// Registers the function to invoke after each successful data update.
  set callback(Function(dynamic data) f) => _callback = f;

  /// Merges [toMerge] into [base] by matching entries on their `id` values.
  ///
  /// Existing items are replaced at their current position, while new items are
  /// appended. [base] is left untouched: the result is a new list, so callers do
  /// not need to pass a defensive copy.
  ///
  /// The copy is what makes the merged result observable. Callers assign the
  /// result straight back through [data] — `data = merge(base: data, …)` — and
  /// [data] compares the incoming payload against the value it already holds. If
  /// this method mutated [base] in place, the "new" value and the comparison
  /// baseline would be the same object, so the change could never be detected.
  ///
  /// Only the list itself is copied. The entries are shared with [base] and
  /// [toMerge], which is sufficient here because merging replaces and appends
  /// elements without ever mutating one.
  List<dynamic> merge({
    required List<dynamic> base,
    required List<dynamic> toMerge,
  }) {
    // Copy before mutating: callers pass the state's own list as `base` and
    // assign the result straight back to `data`. Mutating in place would make
    // the "new" value and the comparison baseline the same object, so the
    // change could never be detected.
    List<dynamic> newData = List<dynamic>.from(base);
    // Index existing entries by id once so each incoming item is matched in
    // constant time instead of rescanning the whole list, turning the merge
    // from O(base * toMerge) into O(base + toMerge). First occurrences win, to
    // mirror the previous indexWhere lookup.
    final Map<dynamic, int> indexById = {};
    for (int i = 0; i < newData.length; i++) {
      indexById.putIfAbsent(newData[i]['id'], () => i);
    }
    for (final item in toMerge) {
      dynamic itemID = item['id'];
      final int? itemIndex = indexById[itemID];
      if (itemIndex != null) {
        newData[itemIndex] = item;
      } else {
        indexById[itemID] = newData.length;
        newData.add(item);
      }
    }
    return newData;
  }

  /// Appends paginated results instead of replacing earlier pages.
  ///
  /// Enable this when the UI should accumulate previous page results, such as an
  /// infinite list. When disabled, each page load replaces the previous data.
  bool incrementalPagination = false;

  /// Controls whether pagination parameters should be included in requests.
  bool paginate = false;

  /// Defines the first page used when pagination resets.
  final int initialPage = 1;

  /// Reports whether another page is likely available.
  ///
  /// This calculation depends on [totalCount], [page], and [limit]. If an API
  /// does not return total-count metadata, subclasses may need to override the
  /// default behavior or accept optimistic pagination.
  /// TODO: Verify pagination in case the 'x-total-count' is not present
  /// Old Version: bool get canPaginate => paginate && privateOldData != null && privateOldData.isNotEmpty && ((totalCount / page) >= 1);
  bool get canPaginate => paginate && ((totalCount / (page * limit)) >= 1);

  /// Stores the total item count reported by the backing data source.
  int totalCount = 0;

  /// Returns the total number of pages implied by [totalCount] and [limit].
  int get totalPages => (totalCount / limit).ceil();

  /// Advances to the next page and triggers [call] when pagination allows it.
  ///
  /// The method returns `null` when pagination is disabled, already exhausted,
  /// or a request is still loading.
  Future<dynamic> next() async {
    if (loading) return;
    if (!canPaginate) return null;
    initialized = false;
    page = page + 1;
    return call();
  }

  /// Moves to the previous page and triggers [call].
  ///
  /// Nothing happens while loading or when the state is already on the first
  /// page.
  Future<dynamic> previous() async {
    if (loading) return;
    if (page <= initialPage) return null;
    initialized = false;
    page = page - 1;
    return call();
  }

  /// Resets pagination to [initialPage] and reloads data through [call].
  Future<dynamic> first() async {
    if (loading) return;
    initialized = false;
    page = initialPage;
    return call();
  }

  /// Jumps to [totalPages] and reloads data through [call].
  Future<dynamic> last() async {
    if (loading) return;
    initialized = false;
    page = totalPages;
    return call();
  }

  /// Changes [limit], clears the current page state, and triggers [call].
  ///
  /// Passing `null` restores [limitDefault]. The current [data] is cleared so
  /// widgets do not accidentally render items from an incompatible page size.
  Future<dynamic> limitChange(int? value) async {
    if (loading) return;
    initialized = false;
    limit = value;
    data = null;
    page = initialPage;
    return call();
  }

  /// Compares two payloads for structural equality.
  ///
  /// Firestore and HTTP responses allocate a fresh [Map] or [List] for every
  /// snapshot, and Dart's default `==` on collections is referential. A plain
  /// `==` guard therefore never matched, so every identical snapshot still
  /// notified every listener. [identical] is checked first as a cheap fast path
  /// before falling back to a deep comparison.
  static bool _isSameData(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Iterable || a is Map || b is Iterable || b is Map) {
      return const DeepCollectionEquality().equals(a, b);
    }
    return a == b;
  }

  /// Assigns new state data and publishes the change.
  ///
  /// A *fresh* payload that is structurally equal to the current value is
  /// ignored, so listeners are not rebuilt for a snapshot that renders
  /// identically.
  ///
  /// Reassigning the object the state already holds always notifies. [data] and
  /// [privateOldData] reference the same instance, so anything mutated in place
  /// is already reflected in the comparison baseline and a structural comparison
  /// could only ever report "unchanged". With no baseline left to compare
  /// against, the payload is assumed to have changed.
  ///
  /// **Never reassign [data] from a listener without a condition that
  /// terminates.** A listener that runs `state.data = state.data`
  /// unconditionally recurses without bound: the assignment notifies, the
  /// notification re-enters this setter, and the same-instance path notifies
  /// again. Measured under `flutter test`, where notification is synchronous,
  /// this overflows the stack, and the resulting `StackOverflowError` is
  /// reported through `FlutterError` rather than thrown where a `try`/`catch`
  /// around the assignment could contain it. In a release build the debounce in
  /// [_notifyData] turns the same pattern into an endless timer loop that
  /// rebuilds forever instead of crashing.
  ///
  /// This is a real behaviour change: the previous guard compared references, so
  /// the same assignment used to be swallowed silently. Any listener that writes
  /// back to [data] must first check that the value actually needs changing —
  /// for example by comparing the field it is about to set — or it must write
  /// through a path that does not notify.
  set data(dynamic dataObject) {
    // When the caller hands back the object the state already holds, the
    // comparison baseline is that same object: anything mutated in place is
    // already reflected in it, so a structural comparison can only ever report
    // "unchanged". There is no baseline left to compare against, so assume the
    // payload changed and notify. Dropping the notification here is what made
    // in-place edits and merge() results invisible to listeners.
    final bool sameInstance = identical(privateData, dataObject);
    if (!sameInstance &&
        privateOldData != null &&
        _isSameData(privateOldData, dataObject)) {
      return;
    }
    privateOldData = dataObject;
    privateData = dataObject;
    // A new payload invalidates anything memoized against the previous one.
    // cachedSerialize keys on identical(), which cannot see a same-instance
    // reassignment, so the memo has to be dropped explicitly.
    invalidateSerialized();
    invalidateCopy();
    _notifyData();
  }

  /// Stores the latest fetch error.
  String? _error;

  /// Returns the current fetch error, if any.
  String? get error => _error;

  /// Logs errors when no custom [onError] handler has been provided.
  void onErrorDefault(String? error) {
    if (error != null) debugPrint(LogColor.error(error));
  }

  /// Stores the callback invoked whenever [error] changes.
  Function(String? error)? _onError;

  /// Runs every time the state records a request error.
  ///
  /// Use this to centralize reporting, analytics, or user feedback without
  /// duplicating error-handling code in each listener.
  Function(String? error) get onError => _onError ?? onErrorDefault;

  /// Registers a custom error handler.
  set onError(Function(String? error) f) => _onError = f;

  /// Updates the current error message and notifies all error listeners.
  ///
  /// Duplicate messages are ignored so consumers do not react twice to the same
  /// failure.
  ///
  /// After [dispose] has been called this is a silent no-op.  When
  /// [debounceTime] is `0` or less the listener notification is ordinarily
  /// synchronous; however, if this setter is called during a widget build the
  /// notification is deferred to the next post-frame callback to avoid the
  /// `setState() or markNeedsBuild() called during build` assertion.
  set error(String? errorMessage) {
    if (_disposed) return;
    if (_error == errorMessage) return;
    _error = errorMessage;
    notifyListeners();
    _safeOnError(errorMessage);
    _controllerStreamError.sink.add(errorMessage);
  }

  /// Invokes [onError] safely, routing any exception it throws to a debug
  /// log instead of letting it escape the [error] setter — a throwing
  /// listener must not prevent [_controllerStreamError] from still
  /// publishing the failure.
  void _safeOnError(String? errorMessage) {
    try {
      onError(errorMessage);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(LogColor.error('StateShared.onError threw: $error'));
      }
    }
  }

  /// Tracks whether any asynchronous work is currently in progress.
  bool _loading = false;

  /// Returns whether the state is busy processing a request or subscription.
  bool get loading => _loading;

  /// Updates the loading flag and notifies listeners when it changes.
  set loading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  /// Stores the current page number.
  int pageDefault = 1;

  /// Stores the default page size used when no custom [limit] is set.
  int limitDefault = 10;

  /// Stores the identifiers selected by the current UI session.
  ///
  /// Selection is intentionally kept outside [data] so list widgets can track
  /// bulk actions without mutating the fetched payload itself.
  List<dynamic> selectedItems = [];

  /// Returns the current page number.
  int get page => pageDefault;

  /// Responds to page changes.
  ///
  /// Subclasses can override this hook to cancel subscriptions or refresh
  /// derived state before a new page is fetched.
  void onPageChange(int newPage) {}

  /// Updates the page number, resets initialization state, and triggers
  /// [onPageChange].
  set page(int? value) {
    if (value == pageDefault) return;
    pageDefault = value ?? initialPage;
    initialized = false;
    loading = false;
    notifyListeners();
    onPageChange(pageDefault);
  }

  /// Stores the active page-size override.
  int? _limit;

  /// Returns the active page size.
  int get limit => _limit ?? limitDefault;

  /// Updates the page size and notifies listeners.
  ///
  /// Passing `null` falls back to [limitDefault].
  set limit(int? value) {
    if (value == _limit) return;
    _limit = value ?? limitDefault;
    notifyListeners();
  }

  /// Returns the first `search` query parameter, when present.
  String? get search =>
      Utils.valuesFromQueryKey(queryParameters, 'search')?.first;

  /// Returns all `searchBy` query parameters.
  List<String>? get searchBy =>
      Utils.valuesFromQueryKey(queryParameters, 'searchBy');

  /// Returns the first `order` query parameter.
  String? get order =>
      Utils.valuesFromQueryKey(queryParameters, 'order')?.first;

  /// Returns the first `sort` query parameter.
  String? get sort => Utils.valuesFromQueryKey(queryParameters, 'sort')?.first;

  /// Controls whether [queryParameters] should expose stored parameters.
  ///
  /// Keeping this `false` lets a state maintain local filter and pagination
  /// state without automatically leaking those values into outgoing requests.
  bool passParameters = false;

  /// Lists additional query-parameter names that should survive sanitization.
  List<String> parametersList = [];

  /// Stores the raw custom query parameters assigned to this state.
  Map<String, List<String>> _queryParameters = {};

  /// Returns the effective query parameters for the next request.
  ///
  /// The returned map is synthesized from [_queryParameters], [filters], [sql],
  /// and pagination values. Only parameters explicitly allowed by the setter are
  /// preserved, which prevents build-time noise or unrelated URL keys from
  /// leaking into data requests.
  Map<String, List<String>> get queryParameters {
    if (!passParameters) return {};
    Map<String, List<String>> queryParametersBase = _queryParameters;
    if (filters.isNotEmpty) {
      // Merge filter parameter
      final filterParameter = FilterHelper.encode(filters);
      if (filterParameter != null) {
        queryParametersBase = {
          ...queryParametersBase,
          'filters': [filterParameter],
        };
      }
      if (sql != null) {
        // Merge SQL parameters
        queryParametersBase = {
          ...queryParametersBase,
          'sql': [sql!],
        };
      }
    }
    if (paginate) {
      // Add default values for pagination
      queryParametersBase = {
        ...queryParametersBase,
        'page': [page.toString()],
        'limit': [limit.toString()],
      };
    }

    return queryParametersBase;
  }

  /// Accepts a new set of query parameters after sanitizing known keys.
  ///
  /// This setter also restores pagination and filter state from the incoming
  /// values. It intentionally avoids [notifyListeners] because these parameters
  /// are often assigned during widget builds, where rebuild-triggering feedback
  /// loops are easy to create.
  ///
  /// Warning: Do not set parameters on build time. Use initState or other lifecycle methods
  set queryParameters(Map<String, List<String>>? p) {
    Map<String, List<String>> parameters = p != null && p.isNotEmpty ? p : {};

    /// The parameters that will be returned, everything else is ignored
    Map<String, List<String>> passingQueryParameters = {};
    List<String> parametersToPass = [
      'search',
      'searchBy',
      'status',
      'order',
      'sort',
      'filters',
      'page',
      'limit',
      ...parametersList,
    ];
    for (int i = 0; i < parametersToPass.length; i++) {
      final key = parametersToPass[i];
      final value = parameters[key];
      if (value != null && (value.isNotEmpty && value.first.isNotEmpty)) {
        passingQueryParameters[key] = value;
      }
    }

    /// Get page from query
    final pageFromQuery = passingQueryParameters['page'];
    final newPage = pageFromQuery != null
        ? int.tryParse(pageFromQuery.first)
        : null;
    pageDefault = newPage ?? page;

    /// Get limit from query
    final limitFromQuery = passingQueryParameters['limit'];
    final newLimit = limitFromQuery != null
        ? int.tryParse(limitFromQuery.first)
        : null;
    if (newLimit != null) limit = newLimit;

    try {
      /// Get filters
      final queryFilters = passingQueryParameters['filters'];
      final queryFilter =
          queryFilters != null &&
              (queryFilters.isNotEmpty && queryFilters.first.isNotEmpty)
          ? queryFilters.first
          : null;
      _filters = FilterHelper.decode(queryFilter);
    } catch (e) {
      _filters = [];
      debugPrint(
        LogColor.error('!!! decode filters from query: ${e.toString()}'),
      );
    }

    // Remove filter parameters
    passingQueryParameters.remove('sql');
    passingQueryParameters.remove('filters');

    // Remove pagination parameters
    passingQueryParameters.remove('page');
    passingQueryParameters.remove('limit');

    /// Set the parameters directly
    _queryParameters = passingQueryParameters;
    // Do not notifyListeners. It can cause an infinite loops because the queryParameters are set in the build method
  }

  /// Merges additional query parameters into the current set.
  ///
  /// Warning: Do not set parameters on build time. Use initState or other lifecycle methods
  set mergeQueryParameters(Map<String, List<String>> p) {
    queryParameters = Utils.mergeQueryParameters(queryParameters, p);
  }

  /// Adds or removes an identifier from the current selection.
  ///
  /// Duplicate selections are collapsed after each update so bulk actions can
  /// rely on [selected] containing unique identifiers.
  void selectId(dynamic id, bool value) {
    if (value) {
      selectedItems.add(id);
    } else {
      selectedItems.removeWhere((item) => item == id);
    }
    selectedItems = selectedItems.toSet().toList();
    notifyListeners();
  }

  /// Returns whether [id] is currently selected.
  bool isSelected(dynamic id) {
    return selectedItems.contains(id);
  }

  /// Returns the selected identifiers.
  List<dynamic> get selected => selectedItems;

  /// Replaces the current selection.
  ///
  /// Passing `null` clears all selected items.
  ///
  /// The unchanged-selection guard is skipped when the caller hands back the
  /// very list this state already holds, because [selected] exposes
  /// [selectedItems] directly: a read-mutate-write round trip compares that
  /// list against itself and can only ever report "unchanged", which would
  /// swallow a real mutation. This mirrors the same-instance escape hatch used
  /// by the [data] setter.
  set selected(List<dynamic>? items) {
    final newItems = items ?? [];
    final bool sameInstance = identical(selectedItems, newItems);
    // Skip the notify when the selection is unchanged; the setter is commonly
    // re-assigned from a parent rebuild with an equivalent list.
    if (!sameInstance &&
        const DeepCollectionEquality().equals(selectedItems, newItems)) {
      return;
    }
    selectedItems = newItems;
    notifyListeners();
  }

  /// Selects every item in [data] that exposes an `id` field.
  ///
  /// This is intended for list-like states. If [data] is `null`, the method
  /// simply clears the current selection.
  void selectAll() {
    selectedItems = [];
    if (data == null) return;
    for (final item in data) {
      if (item['id'] != null) selectedItems.add(item['id']);
    }
    notifyListeners();
  }

  /// Performs the primary one-shot fetch for this state.
  ///
  /// Subclasses implement the actual data-source interaction. They should set
  /// [loading], [error], [initialized], and [data] consistently so listeners can
  /// react in the same way regardless of the backing store.
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {}

  /// Starts a long-lived listener for this state.
  ///
  /// Use this for streams such as Firestore snapshots or server-sent updates.
  /// Consumers should call it once during a widget lifecycle, then rely on
  /// [notifyListeners] and [stream] for subsequent propagation.
  Future<dynamic> listen() async {}

  /// Resets transient state to its default values.
  ///
  /// When [notify] is `true`, the reset propagates through the [data] setter so
  /// data streams and listeners observe the cleared value. When `false`, the raw
  /// backing field is reset quietly, which is useful while reconfiguring a state
  /// before a follow-up fetch.
  void clear({bool notify = false}) {
    _error = null;
    errorCount = 0;
    initialized = false;
    pageDefault = initialPage;
    selectedItems = [];
    privateOldData = null;
    totalCount = 0;
    _loading = false;
    scrollOffset = 0.0;
    _timerNotify?.cancel();
    _timerData?.cancel();
    invalidateSerialized();
    if (notify) {
      data = null;
    } else {
      privateData = null;
    }
    _copy = null;
    _copyDirty = true;
    _edit = false;
  }

  /// Names the filter group used when generating SQL expressions.
  ///
  /// Concrete states can override this to keep filters scoped to the correct
  /// table or collection in shared filter UIs.
  String filterGroup = 'filters';

  /// Defines the SQL dialect variant generated from [filters].
  SQLQueryType sqlQueryType = SQLQueryType.sql;

  /// Stores the active list of structured filters.
  List<FilterData> _filters = [];

  /// Returns the active structured filters.
  List<FilterData> get filters => _filters;

  /// Replaces the active filters and notifies listeners.
  set filters(List<FilterData> newFilters) {
    _filters = newFilters;
    notifyListeners();
  }

  /// Serializes [filters] into an encoded SQL fragment.
  ///
  /// Returns `null` when encoding fails, which lets callers degrade gracefully
  /// instead of breaking the entire request pipeline.
  String? get sql {
    try {
      return FilterHelper.toSQLEncoded(
        table: filterGroup,
        filterData: filters,
        sqlQueryType: sqlQueryType,
      );
    } catch (e) {
      debugPrint(LogColor.error('sql decode error: $e'));
      return null;
    }
  }

  /// Applies [newFilters], optionally merges them, and triggers follow-up work.
  ///
  /// This helper resets the current request state, sanitizes filters through
  /// [FilterHelper.filter], and can optionally refetch data or redirect the UI.
  /// The delayed actions give ongoing animations and route transitions time to
  /// finish before fresh state propagates.
  List<FilterData> applyFilters(
    List<FilterData> newFilters, {
    bool redirect = false,
    bool fetch = false,
    BuildContext? context,
    Uri? uri,
    bool merge = false,
  }) {
    clear();
    List<FilterData> baseFilters = merge
        ? FilterHelper.merge(filters: filters, merge: newFilters)
        : newFilters;
    baseFilters = FilterHelper.filter(filters: baseFilters, strict: true);
    filters = baseFilters;
    if (fetch) {
      Future.delayed(const Duration(milliseconds: 400)).whenComplete(() {
        // Guard mirrors the adjacent redirect path's context.mounted check: the
        // delay outlives the caller's frame, so the state may have been disposed
        // by the time this fires.
        if (_disposed) return;
        call();
      });
    }
    if (redirect) {
      assert(context != null, 'context can\'t be null for if redirect is true');
      assert(uri != null, 'uri can\'t be null for if redirect is true');
      // Use 300+ milliseconds to ensure animations completes
      Future.delayed(const Duration(milliseconds: 400)).whenComplete(() {
        // The delay outlives the caller's frame, so the element backing the
        // captured context may already be gone by the time this runs.
        if (!context!.mounted) return;
        Utils.pushNamedFromQuery(
          context: context,
          uri: uri!,
          queryParameters: {
            ...queryParameters,
            'page': [],
            'limit': [],
            'sql': [],
          },
        );
      });
    }
    return filters;
  }

  /// Returns the state payload converted into a domain-specific representation.
  dynamic get serialized;

  /// Holds the source reference that produced [_serializedCache].
  Object? _serializedSource;

  /// Holds the last value returned by [cachedSerialize].
  Object? _serializedCache;

  /// Tracks whether [_serializedCache] holds a real result.
  ///
  /// A dedicated flag is required because `null` is a legitimate cached value
  /// and `null` is also a legitimate [_serializedSource].
  bool _serializedCached = false;

  /// Memoizes an expensive [serialized] conversion against its [source].
  ///
  /// [serialized] is typically read many times per update — at least once by
  /// each listening widget build plus any internal consumers — while [data] is
  /// replaced by a brand new object on every fetch. Rebuilding the domain model
  /// on each read repeats every `fromJson` call, sort, and filter for no gain.
  ///
  /// Pass the value that the conversion derives from as [source] (usually
  /// [data]) and the conversion itself as [build]. While [source] stays
  /// *identical* — reference equality, not structural equality — the previously
  /// built value is returned. As soon as the state assigns a new [data] object
  /// the identity check fails and [build] runs again, so the cache cannot go
  /// stale.
  ///
  /// A `null` [source] is cached like any other value, which keeps repeated
  /// reads cheap while a state is still empty. [clear] invalidates the cache.
  ///
  /// Example:
  ///
  /// ```dart
  /// @override
  /// List<UserData> get serialized => cachedSerialize(data, () {
  ///   final items = (data as List<dynamic>? ?? [])
  ///       .map(UserData.fromJson)
  ///       .toList();
  ///   items.sort((a, b) => a.name.compareTo(b.name));
  ///   return items;
  /// });
  /// ```
  ///
  /// [build] is only invoked on a cache miss, so it may safely be expensive.
  /// Exceptions thrown by [build] propagate to the caller and leave the previous
  /// cache entry untouched.
  @protected
  T cachedSerialize<T>(Object? source, T Function() build) {
    if (_bypassSerializedCache) return build(); // fresh, not memoized
    if (_serializedCached && identical(_serializedSource, source)) {
      return _serializedCache as T;
    }
    final result = build();
    _serializedSource = source;
    _serializedCache = result;
    _serializedCached = true;
    return result;
  }

  /// Drops any value memoized through [cachedSerialize].
  ///
  /// Call this when a subclass mutates the payload in place instead of assigning
  /// a new [data] object, because in-place mutation cannot be detected by the
  /// identity check.
  @protected
  void invalidateSerialized() {
    _serializedSource = null;
    _serializedCache = null;
    _serializedCached = false;
  }

  // ---------------------------------------------------------------------------
  // Mutable working draft — copy
  // ---------------------------------------------------------------------------

  /// Backing value for [copy].
  dynamic _copy;

  /// Whether [_copy] must be rebuilt from [serialized] on the next read.
  ///
  /// Starts `true` so the first access forces a build.
  bool _copyDirty = true;

  /// When `true`, [cachedSerialize] skips the memo and calls [build] directly,
  /// producing a fresh instance that is independent of the memoized [serialized].
  bool _bypassSerializedCache = false;

  /// A mutable working draft that is always an instance of [serialized].
  ///
  /// The draft is built lazily on the first access after [data] changes and is
  /// `null` when [data] is `null`. Rebuilding is deferred to the accessor so
  /// the [data] setter never triggers a listener notification during a widget
  /// build phase.
  ///
  /// **Identity stability.** Once built, repeated reads return the *same
  /// instance* until [data] changes or [clear] is called. Field mutations on
  /// the returned object therefore persist across reads:
  ///
  /// ```dart
  /// state.copy.name = 'draft';
  /// print(state.copy.name); // 'draft'
  /// ```
  ///
  /// **Type shape.** `serialized` (and therefore `copy`) is always either a
  /// single model instance (`MyModel`) or a list of model instances
  /// (`List<MyModel>`), depending on the subclass.  The base field is `dynamic`
  /// because this class cannot know which shape a given subclass produces; use
  /// subclass narrowing (see below) to avoid casts at call sites.
  ///
  /// **Subclass narrowing.** Concrete states may override the getter to expose
  /// a typed surface without a cast at every call site. Getter-only narrowing
  /// (inheriting the dynamic setter) is the simplest form:
  ///
  /// ```dart
  /// // Single-model subclass
  /// @override
  /// MyModel? get copy => super.copy as MyModel?;
  ///
  /// // List subclass
  /// @override
  /// List<MyModel>? get copy => super.copy as List<MyModel>?;
  /// ```
  ///
  /// When the setter also needs narrowing, the parameter must be `covariant`:
  ///
  /// ```dart
  /// @override
  /// set copy(covariant MyModel? value) => super.copy = value;
  /// ```
  ///
  /// **No listener notifications.** Neither direct field mutation nor assigning
  /// `copy =` notifies listeners — the draft is local UI state. Callers are
  /// responsible for calling their own `setState` (or equivalent) when they
  /// want the UI to reflect an in-progress edit. Persist changes by calling the
  /// relevant save method; discard them by calling [clear] or reassigning
  /// [data].
  ///
  /// **Edits are discarded when data updates.** When a new payload arrives
  /// (e.g. from a live Firestore snapshot), the draft is invalidated and the
  /// next read returns a fresh instance from the new payload. Any in-progress
  /// field edits that were not saved are silently dropped. This is the
  /// intentional behaviour — "re-instantiate from the updated data" — but
  /// callers should be aware that a background update while a user is editing a
  /// form will discard the unsaved edits.
  dynamic get copy {
    if (_copyDirty) {
      _copy = data == null ? null : _freshSerialized();
      _copyDirty = false;
    }
    return _copy;
  }

  /// Replaces the working draft without notifying listeners.
  set copy(dynamic value) {
    _copy = value;
    _copyDirty = false;
  }

  /// Marks the working draft as stale so the next [copy] read rebuilds it.
  ///
  /// The [data] setter calls this automatically. Subclasses that mutate [data]
  /// in place can call it to force a rebuild on the next access.
  @protected
  void invalidateCopy() {
    _copyDirty = true;
  }

  /// Returns a fresh instance of [serialized] that is independent of the
  /// memoized value, so mutating the draft cannot corrupt the canonical object.
  ///
  /// Bypasses [cachedSerialize]'s memo for the duration of the call and
  /// restores the flag in a `finally` so a throwing [serialized] cannot
  /// leave the bypass stuck on.
  dynamic _freshSerialized() {
    _bypassSerializedCache = true;
    try {
      return serialized;
    } finally {
      _bypassSerializedCache = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Edit mode
  // ---------------------------------------------------------------------------

  /// Tracks whether the state is currently open for editing.
  bool _edit = false;

  /// Returns whether the state is currently open for editing.
  ///
  /// This flag is purely local UI state: it does not gate any write and never
  /// changes on its own when a new payload arrives. Views typically bind it to
  /// an "Edit" / "Done" toggle and use it to decide whether to render form
  /// fields or read-only content.
  bool get edit => _edit;

  /// Enters or leaves edit mode, invalidates the [copy] draft, and notifies
  /// listeners.
  ///
  /// Entering edit mode marks the draft dirty so the next [copy] read returns a
  /// fresh instance from the current payload. Leaving edit mode marks the draft
  /// dirty again so any in-progress mutations are discarded on the next read.
  ///
  /// Reassigning the current value is a no-op, so a rebuild that re-applies the
  /// same flag will not discard an actively-used draft.
  ///
  /// Subclasses that need to capture or clear extra state (e.g. [StateDocument]
  /// which needs to perform its own logic before delegating) should
  /// override this setter, perform their own work **before** calling
  /// `super.edit = value`, and then delegate. This ordering guarantees that
  /// listeners observe a fully consistent state: when the notification fires,
  /// all subclass fields are already up to date.
  set edit(bool value) {
    if (_edit == value) return;
    invalidateCopy();
    _edit = value;
    notifyListeners();
  }

  /// Clears edit mode and invalidates the [copy] draft without notifying
  /// listeners.
  ///
  /// Use this from [StateDocument.revert] and [StateDocument.save] where the
  /// caller unconditionally calls [notifyListeners] immediately afterwards, so
  /// an additional notification from the [edit] setter would be redundant.
  @protected
  void exitEdit() {
    _edit = false;
    invalidateCopy();
  }

  /// Stores the debounced listener timer used by [notifyListeners].
  Timer? _timerNotify;

  /// Tracks how many listener notifications have been coalesced.
  int debounceCountNotify = 0;

  /// Stores the debounced data timer used by [_notifyData].
  Timer? _timerData;

  /// Tracks how many data updates have been coalesced.
  int debounceCountData = 0;

  /// Defines the normal debounce interval in milliseconds.
  ///
  /// The default value of `10` coalesces rapid property updates (for example,
  /// a burst of HTTP or Firestore events) so that listeners and widgets rebuild
  /// at most once per debounce window.
  ///
  /// Setting this to `0` or less opts out of debouncing: every call to
  /// [notifyListeners] and every [data] or [error] assignment dispatches
  /// synchronously.  **Caveat:** if a dispatch lands during the Flutter build
  /// phase (i.e. while a widget is building), the notification is automatically
  /// deferred to the next post-frame callback instead of being issued inline, to
  /// avoid the `setState() or markNeedsBuild() called during build` assertion.
  /// Consumers relying on synchronous delivery must not trigger a notify from
  /// inside a `build` method when `debounceTime <= 0`.
  int debounceTime = 10;

  /// Defines the longer debounce interval used before the first successful load.
  int get debounceTimeNotInitialized => 500;

  /// Invokes [callback] safely, routing any exception it throws to a debug
  /// log instead of letting it escape [_publishData] and interrupt the
  /// listener notification or the [stream] emission that accompany it.
  void _safeCallback(dynamic data) {
    try {
      callback(data);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(LogColor.error('StateShared.callback threw: $error'));
      }
    }
  }

  /// Delivers the current data to every channel a consumer can observe.
  ///
  /// [stream] subscribers, [ChangeNotifier] listeners and [callback] are always
  /// served together. Routing every delivery path through this one method is
  /// what keeps a debounced publish and an immediate publish indistinguishable
  /// to a consumer.
  void _publishData() {
    if (_disposed) return;
    // Guard against "setState() called during build" on the immediate
    // (debounceTime <= 0) data path.  The deferred callback re-checks
    // _disposed because the state may be disposed before the post-frame fires.
    // The try/catch is scoped to just the phase probe so that errors from
    // sink.add or super.notifyListeners() propagate normally.
    SchedulerPhase? buildPhase;
    try {
      buildPhase = SchedulerBinding.instance.schedulerPhase;
    } catch (_) {
      // Binding not yet initialised; publish synchronously.
    }
    if (buildPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _controllerStream.sink.add(privateData);
        super.notifyListeners();
        _safeCallback(privateData);
      });
      return;
    }
    _controllerStream.sink.add(privateData);
    super.notifyListeners();
    _safeCallback(privateData);
  }

  /// Publishes [data] changes with debouncing.
  ///
  /// Bursts of updates are coalesced so widgets do not thrash during
  /// stream-heavy workflows. Setting [debounceTime] to `0` or less opts out and
  /// publishes immediately, which still emits on [stream] and still invokes
  /// [callback] — the two paths differ only in *when* they deliver, never in
  /// *what* they deliver.
  void _notifyData() {
    if (_disposed) return;
    // Publish immediately when debouncing is disabled. Any timer already in
    // flight is dropped so a stale deferred delivery cannot arrive afterwards.
    if (debounceTime <= 0) {
      _timerData?.cancel();
      _timerData = null;
      debounceCountData = 0;
      _publishData();
      return;
    }
    // Make custom debounce effective only after the first call otherwise use 10ms as minimum
    int finalDebounceTime = debounceCountData > 0 ? debounceTime : 50;
    // If the first call is not initialized, use minimum debounce time
    if (!initialized) finalDebounceTime = debounceTimeNotInitialized;
    // Increment shared debounce count, cancel shared timer and start a new one
    debounceCountData++;
    _timerData?.cancel();
    _timerData = Timer(Duration(milliseconds: finalDebounceTime), () {
      debounceCountData = 0;
      _publishData();
    });
  }

  /// Notifies widget listeners with the same debounce strategy used for data.
  ///
  /// Subclasses call this indirectly through property setters so rapid state
  /// transitions coalesce into fewer rebuilds.
  ///
  /// **Post-dispose behaviour:** once [dispose] has been called this method is a
  /// silent no-op.  In debug mode a diagnostic is printed so callers can detect
  /// a leaked reference to a disposed state object.
  ///
  /// **Build-phase behaviour when `debounceTime <= 0`:** the notification is
  /// normally synchronous, but if it is triggered during
  /// [SchedulerPhase.persistentCallbacks] (i.e. while a widget is executing its
  /// `build` method) the dispatch is deferred to the next post-frame callback to
  /// prevent `setState() or markNeedsBuild() called during build`.  The
  /// deferred callback re-checks the disposed flag, so disposal between the call
  /// and the post-frame fires is safe.  Callers that require synchronous
  /// delivery must not trigger a notify from inside a `build` method when
  /// `debounceTime <= 0`.
  @override
  void notifyListeners() {
    // Exit silently when the object has already been disposed.  A post-dispose
    // call would otherwise schedule a Timer whose callback reaches
    // super.notifyListeners() on a disposed ChangeNotifier, tripping its
    // debugAssertNotDisposed check.  Emitting a debug-only diagnostic surfaces
    // genuine consumer bugs (leaking a reference to a disposed state) without
    // throwing in release builds.
    if (_disposed) {
      if (kDebugMode) {
        debugPrint(LogColor.error(
          'StateShared.notifyListeners() called after dispose() on $runtimeType.'
          ' This is a bug in the caller.',
        ));
      }
      return;
    }
    // Notify immediately when debouncing is disabled. Any timer already in
    // flight is dropped so a stale deferred notification cannot arrive after.
    if (debounceTime <= 0) {
      _timerNotify?.cancel();
      _timerNotify = null;
      debounceCountNotify = 0;
      // Guard against "setState() called during build."  The debounced path
      // naturally defers past the build phase via a Timer; the immediate path
      // needs an explicit check.  The try/catch is scoped to just the phase
      // probe: when the binding is not yet initialised (pure unit-test contexts
      // that do not call TestWidgetsFlutterBinding.ensureInitialized()) the
      // probe throws, the catch falls through, and we dispatch inline — safe
      // because there is no active framework to violate.  The addPostFrameCallback
      // call and the super.notifyListeners() call are outside the catch so any
      // error they raise propagates normally.
      SchedulerPhase? buildPhase;
      try {
        buildPhase = SchedulerBinding.instance.schedulerPhase;
      } catch (_) {
        // Binding not yet initialised; dispatch inline.
      }
      if (buildPhase == SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_disposed) return;
          super.notifyListeners();
        });
        return;
      }
      super.notifyListeners();
      return;
    }
    // Make custom debounce effective only after the first call otherwise use 10ms as minimum
    int finalDebounceTime = debounceCountNotify > 0 ? debounceTime : 50;
    // If the first call is not initialized, use minimum debounce time
    if (!initialized) finalDebounceTime = debounceTimeNotInitialized;
    // Increment debounce count, cancel timer and start a new one
    debounceCountNotify++;
    _timerNotify?.cancel();
    _timerNotify = Timer(Duration(milliseconds: finalDebounceTime), () {
      debounceCountNotify = 0;
      super.notifyListeners();
    });
  }

  /// Remembers the scroll offset for the current section.
  ///
  /// Views can persist this value before navigation and restore it when the user
  /// returns, which keeps list-heavy workflows feeling continuous.
  double scrollOffset = 0.0;

  /// Whether [dispose] has been called.
  ///
  /// Set to `true` at the very start of [dispose], before any teardown, so
  /// every guarded dispatch site can test it and exit early. Cancelling the
  /// in-flight timers in [dispose] is not sufficient on its own: a notify or
  /// publish issued *after* [dispose] has already run creates a brand-new timer
  /// that nothing will ever cancel.
  bool _disposed = false;

  /// Releases streams and timers held by the state.
  ///
  /// Sets [_disposed] before tearing down resources so every guarded path
  /// can exit early rather than operating on closed controllers or a disposed
  /// [ChangeNotifier].
  @override
  void dispose() {
    _disposed = true;
    _controllerStream.close();
    _controllerStreamError.close();
    _timerNotify?.cancel();
    _timerData?.cancel();
    super.dispose();
  }
}
