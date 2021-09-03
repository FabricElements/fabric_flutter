import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

/// Base State for API calls
/// Use this state to fetch updated data every time an endpoint is updated
class StateAPI extends ChangeNotifier {
  StateAPI();

  /// More at [callback]
  VoidCallback? _callback;

  /// More at [data]
  dynamic _data;

  /// More at [error]
  String? _error;

  /// More at [endpoint]
  String? _endpoint;

  /// Callback on successful load
  set callback(VoidCallback _function) => _callback = _function;

  /// Clear and reset default values
  void clear() {
    _callback = null;
    _data = null;
    _endpoint = null;
  }

  /// API JSON response
  dynamic get data => _data;

  /// Define the HTTPS [endpoint] (https://example.com/demo)
  /// when the timestamp is updated it will result in a new call to the API [endpoint].
  /// Don't use a "/" at the beginning of the path
  set endpoint(String? value) {
    if (value != _endpoint) clear();
    if (value == _endpoint && _data != null) return;
    _endpoint = value;
    get();
  }

  /// Error messages related to fetch data
  String? get error => _error;

  /// API Call
  void get() async {
    _data = null;
    _error = null;
    if (_endpoint == null) {
      _error = "endpoint can't be null";
      notifyListeners();
      return;
    }
    Uri url = Uri.parse(_endpoint!);
    final response = await http.get(url);
    if (response.statusCode == 200) {
      try {
        _data = jsonDecode(response.body);
        if (_callback != null) _callback!();
      } catch (e) {
        _error = e.toString();
      }
    } else {
      _error = response.reasonPhrase ?? "Unknown Error";
    }
    notifyListeners();
  }
}
