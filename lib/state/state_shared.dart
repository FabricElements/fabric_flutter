library fabric_flutter;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../helper/utils.dart';

class StateShared extends ChangeNotifier {
  /// [initialized] after data is called the first time
  bool initialized = false;

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
  set callback(Function(dynamic data) _f) => _callback = _f;

  /// Merge List data
  List<dynamic> merge(
      {required List<dynamic> base, required List<dynamic> toMerge}) {
    List<dynamic> _newData = base;
    for (final item in toMerge) {
      dynamic _id = item['id'];
      int _index = _newData.indexWhere((element) => element['id'] == _id);
      if (_index >= initialPage) {
        _newData[_index] = item;
      } else {
        _newData.add(item);
      }
    }
    return _newData;
  }

  /// Push elements from new requests at the end or updates old ones by id
  /// Use it to get all the previews results for pagination
  bool incrementalPagination = false;

  /// Allow pagination
  bool paginate = false;

  /// Initial Page defines the pagination starting point
  final int initialPage = 1;

  /// Verify if it's possible to paginate
  bool get canPaginate =>
      paginate && privateOldData != null && privateOldData.isNotEmpty;

  /// Paginate and call
  Future<dynamic> next() async {
    if (loading) {
      await Future.delayed(const Duration(milliseconds: 200));
      return next();
    }
    if (!canPaginate) return null;
    page = page + 1;
    return call(ignoreDuplicatedCalls: true);
  }

  /// Paginate and call
  Future<dynamic> previous() async {
    if (loading) {
      await Future.delayed(const Duration(milliseconds: 200));
      return next();
    }
    if (page <= initialPage) return null;
    page = page - 1;
    return call(ignoreDuplicatedCalls: true);
  }

  /// Set [data]
  set data(dynamic dataObject) {
    if (privateOldData == dataObject) return;
    privateOldData = dataObject;
    privateData = dataObject;
    notifyListeners();
    callback(data);
    _controllerStream.sink.add(data);
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
  set onError(Function(String? error) _f) => _onError = _f;

  /// [error] message
  set error(String? errorMessage) {
    _error = errorMessage;
    if (errorMessage != null) {
      onError(errorMessage);
      _controllerStreamError.sink.addError(errorMessage);
    }
  }

  /// Override [clearAfter] for a custom implementation
  /// It is called on the [clear]
  void clearAfter() {}

  bool loading = false;

  /// Pagination
  /// More at [page]
  int pageDefault = 1;

  /// More at [limitDefault]
  int limitDefault = 3;

  /// More at [selected]
  List<dynamic> selectedItems = [];

  /// Returns the [page] number
  int get page => pageDefault;

  /// Set the [page] number and trigger filter
  set page(int? value) {
    pageDefault = value ?? initialPage;
    if (kDebugMode) {
      if (value != null) print('page: $value');
    }
  }

  /// Returns the [limit] number
  int get limit => limitDefault;

  /// Set the [limit] number and trigger filter
  set limit(int? value) {
    limitDefault = value ?? 5;
    if (kDebugMode) {
      if (value != null) print('limit: $value');
    }
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
  Map<String, List<String>>? _queryParameters;

  /// Return only the parameters when required and only what you need with [parametersList]
  Map<String, List<String>>? get queryParameters {
    if (!passParameters) return null;

    /// The parameters that will be returned, everything else is ignored
    Map<String, List<String>> _passingQueryParameters = {};
    List<String> _parametersToPass = [
      'search',
      'searchBy',
      'status',
      'order',
      'sort',
      'page',
      'limit'
    ];
    _parametersToPass.addAll(parametersList);
    _parametersToPass = _parametersToPass.toSet().toList();
    _queryParameters?.forEach((key, value) {
      if (_parametersToPass.contains(key)) {
        _passingQueryParameters.addAll({key: value});
      }
    });

    if (paginate) {
      /// Add default values for pagination
      _passingQueryParameters['page'] = [initialPage.toString()];
      _passingQueryParameters['limit'] = [(limit * (page + 1)).toString()];

      /// Override pagination parameters
      if (!_passingQueryParameters.containsKey('page')) {
        _passingQueryParameters['page'] = [page.toString()];
      }
      if (!_passingQueryParameters.containsKey('limit')) {
        _passingQueryParameters['limit'] = [limit.toString()];
      }
    }

    return _passingQueryParameters;
  }

  /// Set the list of parameters
  set queryParameters(Map<String, List<String>>? p) {
    _queryParameters = p != null && p.isNotEmpty ? p : null;
    if (_queryParameters != null) {
      if (_queryParameters!.containsKey('page')) {
        pageDefault =
            int.tryParse(_queryParameters!['page']!.first) ?? initialPage;
      }
      if (_queryParameters!.containsKey('limit')) {
        limit = int.tryParse(_queryParameters!['limit']!.first) ?? limitDefault;
      }
    }
  }

  /// Merge list of parameters
  set mergeQueryParameters(Map<String, List<String>> p) {
    Map<String, List<String>> qp = {};
    if (_queryParameters != null) qp.addAll(_queryParameters!);
    qp.addAll(p);
    _queryParameters = qp;
  }

  /// [selectId] select item by id
  void selectId(dynamic id, bool value) {
    if (value) {
      selectedItems.add(id);
    } else {
      selectedItems.removeWhere((item) => item == id);
    }
    selectedItems = selectedItems.toSet().toList();
    notifyListeners();
  }

  /// [isSelected] returns true if the id is selected
  bool isSelected(dynamic id) {
    return selectedItems.contains(id);
  }

  /// [selected] returns a list of selected id's
  List<dynamic> get selected => selectedItems;

  /// Set [selected] items with a list of id's or an empty array to reset the value
  set selected(List<dynamic>? items) {
    selectedItems = items ?? [];
    notifyListeners();
  }

  /// [selectAll] select all available items on [data]
  void selectAll() {
    selectedItems = [];
    if (data == null) return;
    for (final item in data) {
      selectedItems.add(item['id']);
    }
    notifyListeners();
  }

  /// async function to process request
  Future<dynamic> call({bool ignoreDuplicatedCalls = false}) async {}
}
