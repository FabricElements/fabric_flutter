import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../helper/http_request.dart';
import 'state_shared.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

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

  /// [credentials]
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication
  String? credentials;

  /// [authScheme]
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes
  /// Use Bearer for token authentication
  AuthScheme? authScheme;

  /// [token]
  /// Use [AuthScheme.Bearer] and the current user id token for authentication
  bool token = false;

  bool loading = false;

  /// Clear and reset default values
  void clear({bool notify = false}) {
    _errorCount = 0;
    data = null;
    // baseEndpoint = null;
    initialized = false;
    // _lastEndpointCalled = null;
    clearAfter();
    if (notify) notifyListeners();
  }

  /// Define the HTTPS [endpoint] (https://example.com/demo)
  /// when the timestamp is updated it will result in a new call to the API [endpoint].
  /// Don't use a '/' at the beginning of the path
  set endpoint(String? value) {
    if (value == baseEndpoint && data != null) return;
    // if (value != baseEndpoint) clear(notify: false);
    // if (initialized) return;
    baseEndpoint = value;
    if (_errorCount > 1) {
      if (kDebugMode) {
        print('$_errorCount errors calls to endpoint: $baseEndpoint');
      }
      return;
    }
    call(ignoreDuplicatedCalls: true);
  }

  /// API Call
  void call({bool ignoreDuplicatedCalls = false}) async {
    if (loading) return;
    loading = true;
    // Prevents duplicate calls with a delay
    await Future.delayed(Duration(milliseconds: 200));
    if (baseEndpoint == null) {
      data = null;
      error = 'endpoint can\'t be null';
      _errorCount++;
      loading = false;
      notifyListeners();
      return;
    }
    if (ignoreDuplicatedCalls &&
        _lastEndpointCalled != null &&
        _lastEndpointCalled == baseEndpoint) {
      loading = false;
      return;
    }
    if (_lastEndpointCalled != baseEndpoint) {
      _errorCount = 0;
      data = null;
      initialized = false;
    }
    _lastEndpointCalled = baseEndpoint;
    String? _error;
    if (_errorCount > 1) {
      if (kDebugMode) {
        print('$_errorCount errors calls to endpoint: $baseEndpoint');
      }
      loading = false;
      return;
    }
    bool mustAuthenticate = false;
    bool canAuthenticate = false;
    if (token) {
      authScheme = AuthScheme.Bearer;
      credentials = await _auth.currentUser?.getIdToken();
    }
    if (authScheme != null || credentials != null) {
      mustAuthenticate = true;
      canAuthenticate = authScheme != null && credentials != null;
    }
    if (mustAuthenticate && !canAuthenticate) {
      if (kDebugMode) print('Must Authenticate on call: $baseEndpoint');
      loading = false;
      return;
    }
    bool willAuthenticate = mustAuthenticate && canAuthenticate;
    Uri url = Uri.parse(baseEndpoint!);
    Map<String, String> headers = {};
    if (willAuthenticate) {
      headers.addAll({
        'Authorization': '${describeEnum(authScheme!)} $credentials',
      });
    }
    if (kDebugMode) print('Calling endpoint: $baseEndpoint');
    final response = await http.get(url, headers: headers);
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
    initialized = true;
    loading = false;
    notifyListeners();
  }
}
