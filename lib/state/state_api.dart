library fabric_flutter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../helper/http_request.dart';
import '../helper/utils.dart';
import 'state_shared.dart';

/// Base State for API calls
/// Use this state to fetch updated data every time an endpoint is updated
class StateAPI extends StateShared {
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

  /// Clear and reset default values
  void clear({bool notify = false}) {
    _errorCount = 0;
    initialized = false;
    pageDefault = 0;
    limitDefault = 5;
    selectedItems = [];
    _lastEndpointCalled = null;
    data = null;
    dataOld = null;
    queryAllPaginated = false;
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

  String? get endpoint {
    if (queryParameters == null || baseEndpoint == null) return baseEndpoint;
    return Utils.uriQueryToStringPath(
        uri: Uri.parse(baseEndpoint!), queryParameters: queryParameters!);
  }

  /// Clear URL from pagination queries
  String? urlClear(String? url) {
    if (url == null) return null;
    return Utils.uriQueryToStringPath(
        uri: Uri.parse(url), queryParameters: {'page': [], 'limit': []});
  }

  /// API Call
  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = false}) async {
    if (loading) return null;
    loading = true;
    // Prevents duplicate calls with a delay
    await Future.delayed(const Duration(milliseconds: 100));
    if (endpoint == null) {
      data = null;
      error = 'endpoint can\'t be null';
      _errorCount++;
      loading = false;
      notifyListeners();
      return null;
    }
    if (ignoreDuplicatedCalls &&
        _lastEndpointCalled != null &&
        _lastEndpointCalled == endpoint) {
      loading = false;
      return null;
    }
    bool isSameClearPath = false;
    if (!queryAllPaginated) {
      final lastEndpointClear = urlClear(_lastEndpointCalled);
      final endpointClear = urlClear(endpoint);
      isSameClearPath =
          lastEndpointClear == endpointClear && incrementalPagination;
      if (!isSameClearPath) {
        _errorCount = 0;
        data = null;
        initialized = false;
      }
    }

    _lastEndpointCalled = endpoint;
    if (_errorCount > 1) {
      if (kDebugMode) {
        print('$_errorCount errors calls to endpoint: $endpoint');
      }
      loading = false;
      if (!isSameClearPath) data = null;
      return null;
    }
    bool mustAuthenticate = false;
    bool canAuthenticate = false;
    if (token) {
      authScheme = AuthScheme.Bearer;
      credentials = await FirebaseAuth.instance.currentUser?.getIdToken();
    }
    if (authScheme != null || credentials != null) {
      mustAuthenticate = true;
      canAuthenticate = authScheme != null && credentials != null;
    }
    if (mustAuthenticate && !canAuthenticate) {
      if (kDebugMode) print('Must Authenticate on call: $endpoint');
      loading = false;
      return null;
    }
    bool willAuthenticate = mustAuthenticate && canAuthenticate;
    Uri url = Uri.parse(endpoint!);
    Map<String, String> headers = {};
    if (willAuthenticate) {
      headers.addAll({
        'Authorization': '${describeEnum(authScheme!)} $credentials',
      });
    }
    if (kDebugMode) print('Calling endpoint: $endpoint');
    dynamic newData;
    try {
      final response = await http.get(url, headers: headers);
      newData = HTTPRequest.response(response);
      error = null;
    } catch (e) {
      if (kDebugMode) print('------------ ERROR API CALL -------------');
      _errorCount++;
      error = e.toString();
      if (!isSameClearPath) data = null;
      newData = null;
    }
    initialized = true;
    loading = false;
    Future.delayed(const Duration(milliseconds: 10))
        .then((value) => notifyListeners());

    /// pagination
    if (incrementalPagination && page > 0) {
      if (data != null && newData != null && newData.isNotEmpty) {
        data = merge(base: data, toMerge: newData);
      }
    } else {
      data = newData;
    }
    return newData;
  }
}
