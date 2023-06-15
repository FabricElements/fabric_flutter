import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../helper/http_request.dart';
import '../helper/utils.dart';
import 'state_shared.dart';

/// Base State for API calls
/// Use this state to fetch updated data every time an endpoint is updated
abstract class StateAPI extends StateShared {
  StateAPI();

  /// [initialized] after [endpoint] is set the first time

  /// Use lastEndpointCalled to prevent duplicated calls when get() is called
  String? _lastEndpointCalled;

  /// More at [endpoint]
  /// Don't override from outside the class, use [endpoint] for that
  late String baseEndpoint;

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

  /// Define the HTTPS [endpoint] (https://example.com/demo)
  /// when the timestamp is updated it will result in a new call to the API [endpoint].
  /// Don't use a '/' at the beginning of the path
  set endpoint(String value) {
    if (value == baseEndpoint && data != null) return;
    // if (value != baseEndpoint) clear(notify: false);
    // if (initialized) return;
    baseEndpoint = value;
    if (errorCount > 1) {
      if (kDebugMode) {
        print('$errorCount errors calls to endpoint: $baseEndpoint');
      }
      return;
    }
    call(ignoreDuplicatedCalls: true);
  }

  String get endpoint {
    if (queryParameters.isEmpty) return baseEndpoint;
    return Utils.uriMergeQuery(
      uri: Uri.parse(baseEndpoint),
      queryParameters: queryParameters,
    ).toString();
  }

  /// Clear URL from pagination queries
  String? urlClear(String? url) {
    if (url == null) return null;
    return Utils.uriMergeQuery(uri: Uri.parse(url), queryParameters: {
      'page': [],
      'limit': [],
      'sql': [],
      'viewAs': [],
    }).toString();
  }

  /// API Call
  @override
  Future<dynamic> call({
    bool ignoreDuplicatedCalls = false,
    bool notify = false,
  }) async {
    /// Prevents duplicate calls with a delay and check for loading call again
    if (loading) return;
    loading = true;
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      // if (endpoint == null) {
      //   data = null;
      //   error = 'endpoint can\'t be null';
      //   errorCount++;
      //   loading = false;
      //   if (notify) notifyListeners();
      //   return;
      // }
      if (ignoreDuplicatedCalls &&
          _lastEndpointCalled != null &&
          _lastEndpointCalled == endpoint) {
        loading = false;
        return data;
      }
      bool isSameClearPath = false;
      final lastEndpointClear = urlClear(_lastEndpointCalled);
      final endpointClear = urlClear(endpoint);
      isSameClearPath = lastEndpointClear == endpointClear && paginate;
      if (!isSameClearPath) {
        errorCount = 0;
        privateData = null;
        initialized = false;
      } else {
        // Disable this code block when ignoreDuplicatedCalls is set to false
        if (isSameClearPath && !ignoreDuplicatedCalls) {
          isSameClearPath = false;
          privateData = null;
        }
      }
      _lastEndpointCalled = endpoint;
      if (errorCount > 1) {
        if (kDebugMode) {
          print('$errorCount errors calls to endpoint: $endpoint');
        }
        loading = false;
        if (!isSameClearPath) data = null;
        return data;
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
        return;
      }
      bool willAuthenticate = mustAuthenticate && canAuthenticate;
      Uri url = Uri.parse(endpoint);
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
        final hasTotalHeader = response.headers.containsKey('x-total-count');
        if (hasTotalHeader) {
          final xTotalCountHeader =
              int.tryParse(response.headers['x-total-count'] ?? '0') ?? 0;
          totalCount = xTotalCountHeader;
        } else if (paginate && !hasTotalHeader) {
          /// Default totalCount depending on the page
          int newTotal = (newData as List<dynamic>).length;
          if (page > initialPage) {
            int basePage = page;
            if (basePage == 0) basePage = 1;
            totalCount = ((basePage - 1) * limit) + newTotal;
          } else {
            totalCount = newTotal;
          }
        }
        error = null;
      } catch (e) {
        if (kDebugMode) print('------------ ERROR API CALL -------------');
        errorCount++;
        error = e.toString();
        if (!isSameClearPath) data = null;
        newData = null;
      }
      initialized = true;
      loading = false;

      /// pagination
      if (incrementalPagination && page > initialPage) {
        if (data != null && newData != null && newData.isNotEmpty) {
          privateData = merge(base: data, toMerge: newData);
        }
      } else {
        privateData = newData;
      }
    } catch (e) {
      if (kDebugMode) print('------ ERROR API CALL : Parent catch ------');
      initialized = false;
      loading = false;
      errorCount++;
      error = e.toString();
    }
    data = privateData;
    return data;
  }

  @override
  void clear({bool notify = false}) {
    _lastEndpointCalled = null;
    super.clear();
  }
}
