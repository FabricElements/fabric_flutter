import 'dart:async';

import 'package:fabric_flutter/variables.dart';
import 'package:flutter/material.dart';

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
  /// Existing items are replaced in place, while new items are appended. This
  /// method intentionally mutates and returns [base], which keeps pagination and
  /// stream-merge flows fast but means callers should pass a defensive copy when
  /// they must preserve the original list.
  List<dynamic> merge({
    required List<dynamic> base,
    required List<dynamic> toMerge,
  }) {
    List<dynamic> newData = base;
    for (final item in toMerge) {
      dynamic itemID = item['id'];
      int itemIndex = newData.indexWhere((element) => element['id'] == itemID);
      if (itemIndex >= 0) {
        newData[itemIndex] = item;
      } else {
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

  /// Assigns new state data and publishes the change.
  ///
  /// Reassigning the same non-null object is ignored to reduce accidental
  /// recursive updates.
  set data(dynamic dataObject) {
    /// Basic check to prevent infinite loops
    if (privateOldData == dataObject && privateOldData != null) return;
    // Set data
    privateOldData = dataObject;
    privateData = dataObject;
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
  set error(String? errorMessage) {
    if (_error == errorMessage) return;
    _error = errorMessage;
    notifyListeners();
    onError(errorMessage);
    _controllerStreamError.sink.add(errorMessage);
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
  set selected(List<dynamic>? items) {
    selectedItems = items ?? [];
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
    if (notify) {
      data = null;
    } else {
      privateData = null;
    }
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
        call();
      });
    }
    if (redirect) {
      assert(context != null, 'context can\'t be null for if redirect is true');
      assert(uri != null, 'uri can\'t be null for if redirect is true');
      // Use 300+ milliseconds to ensure animations completes
      Future.delayed(const Duration(milliseconds: 400)).whenComplete(() {
        Utils.pushNamedFromQuery(
          context: context!,
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

  /// Stores the debounced listener timer used by [notifyListeners].
  Timer? _timerNotify;

  /// Tracks how many listener notifications have been coalesced.
  int debounceCountNotify = 0;

  /// Stores the debounced data timer used by [_notifyData].
  Timer? _timerData;

  /// Tracks how many data updates have been coalesced.
  int debounceCountData = 0;

  /// Defines the normal debounce interval in milliseconds.
  int debounceTime = 10;

  /// Defines the longer debounce interval used before the first successful load.
  int get debounceTimeNotInitialized => 500;

  /// Publishes [data] changes with debouncing.
  ///
  /// Tests bypass debouncing for determinism, while production code batches
  /// bursts of updates so widgets do not thrash during stream-heavy workflows.
  void _notifyData() {
    // Do not debounce in test mode
    if (kIsTest) {
      _controllerStream.sink.add(privateData);
      super.notifyListeners();
      callback(privateData);
      return;
    }
    // Do not debounce if debounceTime is 0
    if (debounceTime <= 0) {
      super.notifyListeners();
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
      _controllerStream.sink.add(privateData);
      super.notifyListeners();
      callback(privateData);
    });
  }

  /// Notifies widget listeners with the same debounce strategy used for data.
  ///
  /// Subclasses call this indirectly through property setters so rapid state
  /// transitions coalesce into fewer rebuilds.
  @override
  void notifyListeners() {
    // Do not debounce in test mode
    if (kIsTest) {
      super.notifyListeners();
      return;
    }
    // Do not debounce if debounceTime is 0
    if (debounceTime <= 0) {
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

  /// Releases streams and timers held by the state.
  @override
  void dispose() {
    _controllerStream.close();
    _controllerStreamError.close();
    _timerNotify?.cancel();
    super.dispose();
  }
}
