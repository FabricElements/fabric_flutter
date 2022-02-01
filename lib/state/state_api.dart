import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import 'state_shared.dart';

/// Base State for API calls
/// Use this state to fetch updated data every time an endpoint is updated
class StateAPI extends ChangeNotifier with StateShared {
  StateAPI();

  /// [initialized] after [endpoint] is set the first time

  /// [_errorCount] to prevent infinite loops
  int _errorCount = 0;

  /// Use [_lastEndpointCalled] to prevent duplicated calls when get() is called
  String? _lastEndpointCalled;

  /// More at [endpoint]
  String? baseEndpoint;

  /// [authParameters]
  String? authParameters;

  /// [authScheme]
  String authScheme = 'Bearer';

  /// Clear and reset default values
  void clear({bool notify = false}) {
    _errorCount = 0;
    data = null;
    baseEndpoint = null;
    initialized = false;
    _lastEndpointCalled = null;
    clearAfter();
    if (notify) notifyListeners();
  }

  /// Define the HTTPS [endpoint] (https://example.com/demo)
  /// when the timestamp is updated it will result in a new call to the API [endpoint].
  /// Don't use a '/' at the beginning of the path
  set endpoint(String? value) {
    if (value == baseEndpoint && data != null) return;
    if (value != baseEndpoint) clear(notify: false);
    if (initialized) return;
    baseEndpoint = value;
    if (_errorCount > 1) {
      if (kDebugMode) {
        print('$_errorCount errors calls to endpoint: $baseEndpoint');
      }
      return;
    }
    get(ignoreDuplicatedCalls: true);
  }

  /// API Call
  void get({bool ignoreDuplicatedCalls = false}) async {
    String? _error;
    if (_errorCount > 1) {
      if (kDebugMode) {
        print('$_errorCount errors calls to endpoint: $baseEndpoint');
      }
      return;
    }
    if (baseEndpoint == null) {
      data = null;
      error = 'endpoint can\'t be null';
      _errorCount++;
      notifyListeners();
      return;
    }
    if (ignoreDuplicatedCalls && _lastEndpointCalled == baseEndpoint) return;
    initialized = true;
    _lastEndpointCalled = baseEndpoint;
    if (kDebugMode) print('Calling endpoint: $baseEndpoint');
    Uri url = Uri.parse(baseEndpoint!);
    Map<String, String> headers = {};
    if (authParameters != null) {
      headers.addAll({'Authorization': '$authScheme $authParameters'});
    }
    final Response response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      try {
        data = jsonDecode(response.body);
        error = null;
      } catch (e) {
        _error = e.toString();
      }
    } else {
      _error =
          response.reasonPhrase != null && response.reasonPhrase!.isNotEmpty
              ? response.reasonPhrase
              : null;
      if (error == null) {
        _error = 'error--${response.statusCode}';
      }
    }
    if (_error != null) {
      print('------------ ERROR API CALL -------------');
      _errorCount++;
      error = _error;
      data = null;
    }
    notifyListeners();
  }
}
