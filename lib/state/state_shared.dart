import 'dart:async';

import 'package:fabric_flutter/variables.dart';
import 'package:flutter/material.dart';

import '../helper/filter_helper.dart';
import '../helper/log_color.dart';
import '../helper/utils.dart';
import '../serialized/filter_data.dart';

abstract class StateShared extends ChangeNotifier {
  /// initialized after data is called the first time
  bool initialized = false;

  /// errorCount to prevent infinite loops
  int errorCount = 0;

  /// More at [stream]
  /// ignore: close_sinks
  final _controllerStream = StreamController<dynamic>.broadcast();

  /// More at [streamError]
  /// ignore: close_sinks
  final _controllerStreamError = StreamController<String?>.broadcast();

  /// Stream Firestore document data
  Stream<dynamic> get stream => _controllerStream.stream;

  /// Stream Firestore document data
  Stream<String?> get streamError => _controllerStreamError.stream;

  /// Last data assigned
  dynamic privateOldData;

  /// Returns data [data]
  dynamic privateData;

  /// Returns [data] object
  dynamic get data => privateData;

  /// Default Callback function
  void callbackDefault(dynamic data) {}

  /// Callback function
  Function(dynamic data)? _callback;

  /// callback is called every time the data is updated
  Function(dynamic data) get callback => _callback ?? callbackDefault;

  /// callbackFunction is called every time the request is successful
  set callback(Function(dynamic data) f) => _callback = f;

  /// Merge List data
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

  /// Push elements from new requests at the end or updates old ones by id
  /// Use it to get all the previews results for pagination
  bool incrementalPagination = false;

  /// Allow pagination
  bool paginate = false;

  /// Initial Page defines the pagination starting point
  final int initialPage = 1;

  /// Verify if it's possible to paginate
  /// TODO: Verify pagination in case the 'x-total-count' is not present
  /// Old Version: bool get canPaginate => paginate && privateOldData != null && privateOldData.isNotEmpty && ((totalCount / page) >= 1);
  bool get canPaginate => paginate && ((totalCount / (page * limit)) >= 1);

  /// Get total count from the API request, used for pagination
  int totalCount = 0;

  /// Return total number of pages
  int get totalPages => (totalCount / limit).ceil();

  /// Paginate to next page and call
  Future<dynamic> next() async {
    if (loading) return;
    if (!canPaginate) return null;
    initialized = false;
    page = page + 1;
    return call();
  }

  /// Paginate to previous page and call
  Future<dynamic> previous() async {
    if (loading) return;
    if (page <= initialPage) return null;
    initialized = false;
    page = page - 1;
    return call();
  }

  /// Paginate to first page and call
  Future<dynamic> first() async {
    if (loading) return;
    initialized = false;
    page = initialPage;
    return call();
  }

  /// Paginate to last page and call
  Future<dynamic> last() async {
    if (loading) return;
    initialized = false;
    page = totalPages;
    return call();
  }

  /// Change the page limit and call
  Future<dynamic> limitChange(int? value) async {
    if (loading) return;
    initialized = false;
    limit = value;
    data = null;
    page = initialPage;
    return call();
  }

  /// Set data
  set data(dynamic dataObject) {
    /// Basic check to prevent infinite loops
    if (privateOldData == dataObject && privateOldData != null) return;
    // Set data
    privateOldData = dataObject;
    privateData = dataObject;
    _notifyData();
  }

  /// More at [error]
  String? _error;

  /// Error messages related to fetch data
  String? get error => _error;

  /// Default onError function
  void onErrorDefault(String? error) {
    if (error != null) debugPrint(LogColor.error(error));
  }

  /// onError is called every time the request has an error
  Function(String? error)? _onError;

  /// onError is called every time the request has an error
  Function(String? error) get onError => _onError ?? onErrorDefault;

  /// onError is called every time the request has an error
  set onError(Function(String? error) f) => _onError = f;

  /// [error] message
  set error(String? errorMessage) {
    _error = errorMessage;
    notifyListeners();
    onError(errorMessage);
    _controllerStreamError.sink.add(errorMessage);
  }

  /// Loading state
  /// Some processes are running
  bool loading = false;

  /// Pagination
  /// More at [page]
  int pageDefault = 1;

  /// More at limitDefault
  int limitDefault = 10;

  /// More at [selected]
  List<dynamic> selectedItems = [];

  /// Returns the page number
  int get page => pageDefault;

  /// On page change
  void onPageChange(int newPage) {}

  /// Set the page number and trigger filter
  set page(int? value) {
    pageDefault = value ?? initialPage;
    initialized = false;
    loading = false;
    super.notifyListeners();
    onPageChange(pageDefault);
  }

  /// Limit for pagination
  int? _limit;

  /// Returns the limit number
  int get limit => _limit ?? limitDefault;

  /// Set the [limit] number and trigger filter
  set limit(int? value) {
    _limit = value ?? limitDefault;
    super.notifyListeners();
  }

  /// Returns the trade
  String? get search =>
      Utils.valuesFromQueryKey(queryParameters, 'search')?.first;

  /// Returns searchBy
  List<String>? get searchBy =>
      Utils.valuesFromQueryKey(queryParameters, 'searchBy');

  /// Returns order
  String? get order =>
      Utils.valuesFromQueryKey(queryParameters, 'order')?.first;

  /// Returns sort
  String? get sort => Utils.valuesFromQueryKey(queryParameters, 'sort')?.first;

  /// Define if the parameters are passed or ignored
  bool passParameters = false;

  /// List of custom parameters to pass in addition to the default parameters
  List<String> parametersList = [];

  /// List of query parameters
  Map<String, List<String>> _queryParameters = {};

  /// Return only the parameters when required and only what you need with [parametersList]
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

  /// Set the list of parameters
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

  /// Merge list of parameters
  /// Warning: Do not set parameters on build time. Use initState or other lifecycle methods
  set mergeQueryParameters(Map<String, List<String>> p) {
    queryParameters = Utils.mergeQueryParameters(queryParameters, p);
  }

  /// selectId select item by id
  void selectId(dynamic id, bool value) {
    if (value) {
      selectedItems.add(id);
    } else {
      selectedItems.removeWhere((item) => item == id);
    }
    selectedItems = selectedItems.toSet().toList();
    super.notifyListeners();
  }

  /// isSelected returns true if the id is selected
  bool isSelected(dynamic id) {
    return selectedItems.contains(id);
  }

  /// selected returns a list of selected id's
  List<dynamic> get selected => selectedItems;

  /// Set selected items with a list of id's or an empty array to reset the value
  set selected(List<dynamic>? items) {
    selectedItems = items ?? [];
    super.notifyListeners();
  }

  /// selectAll select all available items on [data]
  void selectAll() {
    selectedItems = [];
    if (data == null) return;
    for (final item in data) {
      if (item['id'] != null) selectedItems.add(item['id']);
    }
    super.notifyListeners();
  }

  /// async function to process request
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {}

  /// Make call and listen for changes
  Future<dynamic> listen() async {}

  /// Clear and reset default values
  void clear({bool notify = false}) {
    _error = null;
    errorCount = 0;
    initialized = false;
    pageDefault = initialPage;
    selectedItems = [];
    privateOldData = null;
    totalCount = 0;
    loading = false;
    _timerNotify?.cancel();
    _timerData?.cancel();
    if (notify) {
      data = null;
    } else {
      privateData = null;
    }
  }

  /// Filters
  /// Used to identify the table/collection id
  String filterGroup = 'filters';

  /// Define the type of sql query generated
  SQLQueryType sqlQueryType = SQLQueryType.sql;

  List<FilterData> _filters = [];

  /// get filters from query
  List<FilterData> get filters => _filters;

  /// set filters and notify listeners
  set filters(List<FilterData> newFilters) {
    _filters = newFilters;
    notifyListeners();
  }

  /// Get SQL
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

  /// Merge, apply filters and call endpoint
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

  /// Get serialized data
  dynamic get serialized;

  /// Debounce timers and counters
  Timer? _timerNotify;
  int debounceCountNotify = 0;
  Timer? _timerData;
  int debounceCountData = 0;

  /// Debounce time in milliseconds
  int debounceTime = 300;

  /// Notify data with debounce
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
      _controllerStream.sink.add(privateData);
      super.notifyListeners();
      callback(privateData);
      return;
    }

    // Make custom debounce effective only after the first call otherwise use 100ms as minimum
    int finalDebounceTime = debounceCountData > 0 ? debounceTime : 300;
    // If the first call is not initialized, use minimum debounce time
    if (!initialized) finalDebounceTime = 500;

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

  /// Notify listeners with debounce
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
    int finalDebounceTime = debounceCountNotify > 0 ? debounceTime : 100;
    // If the first call is not initialized, use minimum debounce time
    if (!initialized) finalDebounceTime = 500;
    // Increment debounce count, cancel timer and start a new one
    debounceCountNotify++;
    _timerNotify?.cancel();
    _timerNotify = Timer(Duration(milliseconds: finalDebounceTime), () {
      debounceCountNotify = 0;
      super.notifyListeners();
    });
  }

  /// Dispose streams and cancel timer
  @override
  void dispose() {
    _controllerStream.close();
    _controllerStreamError.close();
    _timerNotify?.cancel();
    super.dispose();
  }
}
