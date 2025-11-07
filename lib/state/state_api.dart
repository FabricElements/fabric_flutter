import 'dart:async';
import 'dart:convert' show Utf8Codec, jsonDecode;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../helper/http_request.dart';
import '../helper/log_color.dart';
import '../helper/utils.dart';
import 'state_shared.dart';

/// Base State for API calls
/// Use this state to fetch updated data every time an endpoint is updated
abstract class StateAPI extends StateShared {
  http.Client httpClient;

  StateAPI({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client(),
      super();

  /// [initialized] after [endpoint] is set the first time

  /// Use lastEndpointCalled to prevent duplicated calls when get() is called
  String? _lastEndpointCalled;

  /// More at [endpoint]
  /// Don't override from outside the class, use [endpoint] for that
  String baseEndpoint = '';

  /// [credentials]
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication
  String? credentials;

  /// [authScheme]
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes
  /// Use Bearer for token authentication
  AuthScheme? authScheme;

  /// Use [AuthScheme.Bearer] and the current user id token for authentication
  bool token = false;

  /// Define the HTTPS [endpoint] (https://example.com/demo)
  /// when the timestamp is updated it will result in a new call to the API [endpoint].
  /// Don't use a '/' at the beginning of the path
  set endpoint(String value) {
    if (value == baseEndpoint && data != null) return;
    baseEndpoint = value;
    if (errorCount > 1) {
      debugPrint(
        LogColor.warning('$errorCount errors calls to endpoint: $baseEndpoint'),
      );
      return;
    }
    call();
  }

  /// Get the current endpoint and query parameters as a string
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
    return Utils.uriMergeQuery(
      uri: Uri.parse(url),
      queryParameters: {'page': [], 'limit': [], 'sql': [], 'viewAs': []},
    ).toString();
  }

  /// Response headers
  Map<String, String> headers = {};

  /// Define the header names to filter for the next call
  /// Example: [x-header-name] for exact header
  /// Example: [x-header-*] for wildcard headers
  /// Example: [x-custom-header-name, x-custom-*] for multiple headers
  /// Is not case sensitive
  /// headersToFilter will be used to filter the headers you like to use for the next call
  List<String> get headersToFilter => [];

  /// Get the headers for the next call
  Map<String, String> get headersFiltered {
    Map<String, String> finalHeaders = {};
    final headersToFilterToUse = headersToFilter
        .map((e) => e.toLowerCase())
        .toList();
    // change all header keys to lowercase
    final headersToUse = headers.map((key, value) {
      return MapEntry(key.toLowerCase(), value);
    });
    for (String header in headersToFilterToUse) {
      header = header.toLowerCase();
      if (header.endsWith('*')) {
        String headerName = header.replaceAll('*', '');
        headersToUse.forEach((key, value) {
          if (key.startsWith(headerName)) {
            finalHeaders[key] = value;
          }
        });
      } else {
        if (headersToUse.containsKey(header)) {
          finalHeaders[header] = headersToUse[header]!;
        }
      }
    }
    return finalHeaders;
  }

  /// Stream subscription for handling JSON stream responses
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {
    // Check for empty baseEndpoint
    if (baseEndpoint.isEmpty) {
      data = null;
      error = 'Endpoint path is empty';
      return null;
    }

    /// Prevents duplicate calls with a delay and check for loading call again
    if (loading) return;
    loading = true;
    // Check for duplicated calls
    if (ignoreDuplicatedCalls &&
        _lastEndpointCalled == endpoint &&
        data != null) {
      loading = false;
      return data;
    }
    bool isSameClearPath = urlClear(_lastEndpointCalled) == urlClear(endpoint);
    if (!isSameClearPath) {
      errorCount = 0;
      data = null;
      initialized = false;
    }
    _lastEndpointCalled = endpoint;
    if (errorCount > 1) {
      debugPrint(
        LogColor.warning('$errorCount errors calls to endpoint: $baseEndpoint'),
      );
      loading = false;
      return data;
    }
    dynamic newData;
    dynamic dataResponse;
    String? contentType;
    bool isJsonStream = false;
    try {
      bool mustAuthenticate = false;
      bool canAuthenticate = false;
      if (token) {
        authScheme = AuthScheme.Bearer;
        credentials = await FirebaseAuth.instance.currentUser!.getIdToken();
      }
      if (authScheme != null || credentials != null) {
        mustAuthenticate = true;
        canAuthenticate = authScheme != null && credentials != null;
      }
      if (mustAuthenticate && !canAuthenticate) {
        debugPrint(LogColor.error('Must Authenticate on call: $endpoint'));
        loading = false;
        return;
      }
      bool willAuthenticate = mustAuthenticate && canAuthenticate;
      Uri url = Uri.parse(endpoint);
      Map<String, String> requestHeaders = {...headersFiltered};
      if (willAuthenticate) {
        requestHeaders['Authorization'] = '${authScheme!.name} $credentials';
      }
      debugPrint(LogColor.info('Calling endpoint: $endpoint'));
      try {
        final request = http.Request('GET', url);
        request.headers.addAll(requestHeaders);
        final response = await httpClient.send(request);
        headers = response.headers;
        contentType = headers['content-type'];
        if (contentType == null) {
          throw 'No content type found for endpoint: $endpoint';
        }
        final hasTotalHeader = headers.containsKey('x-total-count');
        isJsonStream = contentType.contains('application/x-json-stream');

        /// Handle json streaming data
        if (isJsonStream) {
          if (!incrementalPagination) {
            newData = [];
            data = [];
          }
          String staticBuffer = '';

          // Build the transformed stream (maps chunks into Map\<String,dynamic\>)
          Stream<Map<String, dynamic>> stream = response.stream
              .transform(Utf8Codec(allowMalformed: true).decoder)
              .transform(
                StreamTransformer<String, Map<String, dynamic>>.fromHandlers(
                  handleData: (bufferData, sink) {
                    final combined = StringBuffer();
                    combined.write(staticBuffer);
                    combined.write(bufferData);
                    final s = combined.toString();

                    int depth = 0;
                    bool inString = false;
                    bool escape = false;
                    int startIndex = 0;

                    for (int i = 0; i < s.length; i++) {
                      final ch = s[i];

                      if (escape) {
                        escape = false;
                        continue;
                      }
                      if (ch == r'\') {
                        escape = true;
                        continue;
                      }
                      if (ch == '"') {
                        inString = !inString;
                        continue;
                      }
                      if (inString) continue;

                      if (ch == '{') {
                        depth++;
                      } else if (ch == '}') {
                        depth--;
                        if (depth == 0) {
                          final candidate = s
                              .substring(startIndex, i + 1)
                              .trim();
                          if (candidate.isNotEmpty) {
                            try {
                              final decoded = jsonDecode(candidate);
                              if (decoded is Map<String, dynamic>) {
                                sink.add(decoded);
                              }
                            } catch (_) {
                              // Preserve candidate for next chunks by breaking
                              break;
                            }
                          }
                          startIndex = i + 1;
                        }
                      }
                    }

                    if (startIndex < s.length) {
                      staticBuffer = s.substring(startIndex);
                    } else {
                      staticBuffer = '';
                    }
                  },
                ),
              );
          // Cancel any existing subscription
          await _streamSubscription?.cancel();
          // Subscribe and process chunks; wait until stream completes
          _streamSubscription = stream.listen(
            (chunk) {
              if (chunk.isEmpty) return;
              final originalData = data ?? [];
              // verify if item['id'] is present or add to data without merge method
              if (chunk.containsKey('id')) {
                final baseNewData = [chunk];
                dataResponse = merge(base: originalData, toMerge: baseNewData);
              } else {
                dataResponse = [...originalData, chunk];
              }
              newData = dataResponse;
              data = dataResponse;
              initialized = true;
            },
            onError: (e) {
              // propagate to error handling below by setting error
              errorCount++;
              error = e.toString();
            },
          );

          // Wait for the subscription to finish (stream done)
          await _streamSubscription!.asFuture();
          newData ??= [];
        } else {
          final convertedResponse = await http.Response.fromStream(response);
          newData = HTTPRequest.response(convertedResponse);
        }
        if (hasTotalHeader) {
          final xTotalCountHeader =
              int.tryParse(headers['x-total-count'] ?? '0') ?? 0;
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
        final isAbort =
            (e is http.ClientException && e.message.contains('abortTrigger')) ||
            e.toString().contains('abortTrigger');
        if (isAbort) {
          debugPrint(LogColor.warning('API call aborted: $endpoint'));
          return dataResponse;
        }
        debugPrint(
          LogColor.error('''
***
////////////// ERROR API CALL ////////////////////
Endpoint: $endpoint
Error: $e
//////////////////////////////////////////////////
***
'''),
        );
        errorCount++;
        error = e.toString();
      }
      initialized = true;

      /// pagination
      if (incrementalPagination) {
        bool hasOldData = data != null && data.isNotEmpty;
        bool hasNewData = newData != null && newData.isNotEmpty;
        // Merge data or return same data as last request
        if (hasOldData && hasNewData) {
          dataResponse = merge(base: data, toMerge: newData);
        } else if (hasOldData && !hasNewData) {
          dataResponse = data;
        } else {
          dataResponse = newData;
        }
      } else {
        dataResponse = newData;
      }
    } catch (e) {
      debugPrint(LogColor.error('------ ERROR API CALL : Parent catch ------'));
      initialized = false;
      errorCount++;
      error = e.toString();
    } finally {
      loading = false;
      await _resetHttpClient();
    }

    dataResponse = paginate
        ? (dataResponse ?? []) as List<dynamic>
        : dataResponse as dynamic;
    data = dataResponse;
    return dataResponse;
  }

  /// Reset the HTTP client and cancel any existing stream subscription
  /// Reset the HTTP client and cancel any existing stream subscription
  Future<void> _resetHttpClient() async {
    // Cancel and clear existing subscription
    try {
      await _streamSubscription?.cancel();
    } finally {
      _streamSubscription = null;
    }

    // Close existing client (http.Client.close is synchronous but keep pattern)
    try {
      httpClient.close();
    } catch (_) {}
    // Create a fresh client
    httpClient = http.Client();
  }

  @override
  void clear({bool notify = false}) {
    _lastEndpointCalled = null;
    headers = {};
    _resetHttpClient().whenComplete(() {
      super.clear(notify: notify);
    });
  }
}
