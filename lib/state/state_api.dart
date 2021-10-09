import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

/// Base State for API calls
/// Use this state to fetch updated data every time an endpoint is updated
class StateAPI extends ChangeNotifier {
  StateAPI();

  /// More at [callback]
  VoidCallback? _callback;

  /// More at [data]
  dynamic baseData;

  /// More at [error]
  String? _error;

  /// More at [endpoint]
  String? baseEndpoint;

  /// [authParameters]
  String? authParameters;

  /// [authScheme]
  String authScheme = "Bearer";

  /// Callback on successful load
  set callback(VoidCallback _function) => _callback = _function;

  /// Clear and reset default values
  void clear() {
    _callback = null;
    baseData = null;
    baseEndpoint = null;
  }

  /// API JSON response
  dynamic get data => baseData;

  /// Overwrite [data]
  set data(dynamic newData) {
    baseData = newData;
    notifyListeners();
  }

  /// Define the HTTPS [endpoint] (https://example.com/demo)
  /// when the timestamp is updated it will result in a new call to the API [endpoint].
  /// Don't use a "/" at the beginning of the path
  set endpoint(String? value) {
    if (value != baseEndpoint) clear();
    if (value == baseEndpoint && baseData != null) return;
    baseEndpoint = value;
    get();
  }

  /// Error messages related to fetch data
  String? get error => _error;

  /// API Call
  void get() async {
    baseData = null;
    _error = null;
    if (baseEndpoint == null) {
      _error = "endpoint can't be null";
      notifyListeners();
      return;
    }
    Uri url = Uri.parse(baseEndpoint!);
    Map<String, String> headers = {};
    if (authParameters != null) {
      headers.addAll({"Authorization": "$authScheme $authParameters"});
    }
    final Response response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      try {
        baseData = jsonDecode(response.body);
        if (_callback != null) _callback!();
      } catch (e) {
        _error = e.toString();
      }
    } else {
      _error =
          response.reasonPhrase != null && response.reasonPhrase!.isNotEmpty
              ? response.reasonPhrase
              : null;
      if (_error == null) {
        _error = "error--${response.statusCode}";
      }
    }
    if (_error != null) {
      print("------------ ERROR API CALL -------------");
      print(_error);
    }
    notifyListeners();
  }
}
