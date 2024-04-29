import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helper/filter_helper.dart';
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
  callbackDefault(dynamic data) {}

  /// Callback function
  Function(dynamic data)? _callback;

  /// callback is called every time the data is updated
  Function(dynamic data) get callback => _callback ?? callbackDefault;

  /// callbackFunction is called every time the request is successful
  set callback(Function(dynamic data) f) => _callback = f;

  /// Merge List data
  List<dynamic> merge(
      {required List<dynamic> base, required List<dynamic> toMerge}) {
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
    data = paginate ? [] : null;
    page = initialPage;
    return call();
  }

  /// Set data
  set data(dynamic dataObject) {
    if (privateOldData == dataObject) return;
    privateOldData = dataObject;
    privateData = dataObject;
    _controllerStream.sink.add(dataObject);
    callback(dataObject);
    if (initialized) notifyListeners();
  }

  /// More at [error]
  String? _error;

  /// Error messages related to fetch data
  String? get error => _error;

  /// Default onError function
  onErrorDefault(String? error) {
    if (kDebugMode) {
      if (error != null) print('Error: $error');
    }
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
    if (errorMessage != null) {
      onError(errorMessage);
      _controllerStreamError.sink.addError(errorMessage);
    }
  }

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
    onPageChange(pageDefault);
  }

  /// Limit for pagination
  int? _limit;

  /// Returns the limit number
  int get limit => _limit ?? limitDefault;

  /// Set the [limit] number and trigger filter
  set limit(int? value) {
    _limit = value ?? limitDefault;
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
    final newPage =
        pageFromQuery != null ? int.tryParse(pageFromQuery.first) : null;
    pageDefault = newPage ?? page;

    /// Get limit from query
    final limitFromQuery = passingQueryParameters['limit'];
    final newLimit =
        limitFromQuery != null ? int.tryParse(limitFromQuery.first) : null;
    if (newLimit != null) limit = newLimit;

    try {
      /// Get filters
      final queryFilters = passingQueryParameters['filters'];
      final queryFilter = queryFilters != null &&
              (queryFilters.isNotEmpty && queryFilters.first.isNotEmpty)
          ? queryFilters.first
          : null;
      _filters = FilterHelper.decode(queryFilter);
    } catch (e) {
      _filters = [];
      debugPrint('!!! decode filters from query: ${e.toString()}');
    }

    // Remove filter parameters
    passingQueryParameters.remove('sql');
    passingQueryParameters.remove('filters');

    // Remove pagination parameters
    passingQueryParameters.remove('page');
    passingQueryParameters.remove('limit');
    _queryParameters = passingQueryParameters;
  }

  /// Merge list of parameters
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
    if (initialized) notifyListeners();
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
    if (initialized) notifyListeners();
  }

  /// selectAll select all available items on [data]
  void selectAll() {
    selectedItems = [];
    if (data == null) return;
    for (final item in data) {
      selectedItems.add(item['id']);
    }
    if (initialized) notifyListeners();
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
    privateOldData = paginate ? [] : null;
    totalCount = 0;
    loading = false;
    if (notify) {
      data = paginate ? [] : null;
    } else {
      privateData = paginate ? [] : null;
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

  set filters(List<FilterData> newFilters) {
    _filters = newFilters;
    if (initialized) notifyListeners();
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
      debugPrint('sql decode error: $e');
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
    List<FilterData> baseFilters = merge
        ? FilterHelper.merge(
            filters: filters,
            merge: newFilters,
          )
        : newFilters;
    baseFilters = FilterHelper.filter(filters: baseFilters, strict: true);
    _filters = baseFilters;
    if (fetch) {
      call();
    }
    if (redirect) {
      assert(context != null, 'context can\'t be null for if redirect is true');
      assert(uri != null, 'uri can\'t be null for if redirect is true');
      // Use 300+ milliseconds to ensure animations completes
      Future.delayed(const Duration(milliseconds: 1)).then((time) {
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
    if (initialized) notifyListeners();
    return filters;
  }

  /// Get serialized data
  dynamic get serialized;

  Timer? _timer;
  int debounceCount = 0;

  /// Debounce time in milliseconds
  int debounceTime = 10;

  /// Notify listeners with debounce
  @override
  void notifyListeners() {
    // Make custom debounce effective only after the first call otherwise use 10ms as minimum
    int finalDebounceTime = debounceCount > 0 ? debounceTime : 5;
    // If the first call is not initialized, use minimum debounce time
    if (!initialized) finalDebounceTime = 500;
    // Increment debounce count, cancel timer and start a new one
    debounceCount++;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: finalDebounceTime), () {
      debounceCount = 0;
      super.notifyListeners();
    });
  }
}
