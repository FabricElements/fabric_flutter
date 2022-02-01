import 'dart:async';

import 'package:flutter/foundation.dart';

class StateShared {
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

  /// Set [data]
  set data(dynamic dataObject) {
    _data = dataObject;
    callback(dataObject);
    _controllerStream.sink.add(dataObject);
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
}
