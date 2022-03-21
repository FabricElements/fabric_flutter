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
  dynamic _lastData;

  /// Returns data [data]
  dynamic _data;

  /// Returns [data] object
  dynamic get data => _data;

  /// [callback] is called every time the data is updated
  Function(dynamic data) callback = (dynamic data) {
    // if (data != null && kDebugMode) print(data);
  };

  /// [callbackFunction] is called every time data is updated
  set callbackFunction(Function(dynamic data) _f) => callback = _f;

  /// Merge List data
  List<dynamic> merge(
      {required List<dynamic> base, required List<dynamic> toMerge}) {
    List<dynamic> _newData = base;
    for (final item in toMerge) {
      dynamic _id = item['id'];
      int _index = _newData.indexWhere((element) => element['id'] == _id);
      if (_index >= 0) {
        _newData[_index] = item;
      } else {
        _newData.add(item);
      }
    }
    return _newData;
  }

  /// Push elements from new requests at the end or updates old ones by id
  bool incrementalPagination = false;

  /// Set [data]
  set data(dynamic dataObject) {
    if (_lastData == dataObject) return;
    _lastData = dataObject;
    // if (page != 0) {
    //   if (dataObject.runtimeType == List) {
    //     merge(dataObject);
    //   }
    // } else {
    //   _data = dataObject;
    // }
    _data = dataObject;

    callback(data);
    _controllerStream.sink.add(data);
  }

  /// More at [error]
  String? _error;

  /// Error messages related to fetch data
  String? get error => _error;

  /// [onError] is called every time there is an error
  Function(String? error) onError = (String? error) {
    if (error != null && kDebugMode) print("Error: $error");
  };

  /// [errorFunction] overrides [onError]
  set errorFunction(Function(String? error) _f) => onError = _f;

  /// [error] message
  set error(String? errorMessage) {
    _error = errorMessage;
    onError(errorMessage);
    _controllerStreamError.sink.add(errorMessage);
  }

  /// Override [clearAfter] for a custom implementation
  /// It is called on the [clear]
  void clearAfter() {}

  bool loading = false;

  /// Pagination
  /// More at [page]
  int pageDefault = 0;

  /// More at [limitDefault]
  int limitDefault = 3;

  /// More at [selected]
  List<dynamic> selectedItems = [];

  /// Returns the [page] number
  int get page => pageDefault;

  /// Set the [page] number and trigger filter
  set page(int? value) {
    pageDefault = value ?? 0;
    if (value != null) print('page: $value');
    // notifyListeners();
    // call(ignoreDuplicatedCalls: true);
  }

  /// Returns the [limit] number
  int get limit => limitDefault;

  /// Set the [limit] number and trigger filter
  set limit(int? value) {
    limitDefault = value ?? 5;
    if (value != null) print('limit: $value');
    // notifyListeners();
    // call(ignoreDuplicatedCalls: true);
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

    /// Add default values
    if (!_passingQueryParameters.containsKey('page')) {
      _passingQueryParameters['page'] = [page.toString()];
    }
    if (!_passingQueryParameters.containsKey('limit')) {
      _passingQueryParameters['limit'] = [limit.toString()];
    }
    return _passingQueryParameters;
  }

  /// Set the list of parameters
  set queryParameters(Map<String, List<String>>? p) {
    _queryParameters = p != null && p.isNotEmpty ? p : null;
    if (_queryParameters != null) {
      if (_queryParameters!.containsKey('page')) {
        pageDefault = int.tryParse(_queryParameters!['page']![0]) ?? 0;
      }
      if (_queryParameters!.containsKey('limit')) {
        limit = int.tryParse(_queryParameters!['limit']![0]) ?? limitDefault;
      }
    }
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
    return selectedItems.indexOf(id) >= 0;
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
}
