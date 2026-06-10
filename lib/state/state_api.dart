import 'dart:async';
import 'dart:convert' show Utf8Codec, jsonEncode;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../helper/byte_count_transformer.dart';
import '../helper/http_request.dart';
import '../helper/log_color.dart';
import '../helper/utils.dart';
import 'state_shared.dart';

/// Parses a possibly partial JSON-object stream buffer into complete objects.
///
/// The function runs inside `compute()` when isolates are available so large
/// streaming API responses do not block the main isolate. It accepts `args`
/// containing the incoming chunk under `s` and any leftover content from the
/// previous pass under `staticBuffer`, then returns parsed `items` plus the new
/// trailing `buffer`.
///
/// Only complete top-level JSON objects are emitted. Invalid trailing fragments
/// are intentionally preserved for the next chunk so split payloads can recover
/// cleanly instead of producing false parse errors.
Map<String, dynamic> _parseJsonBuffer(Map<String, dynamic> args) {
  final String chunk = (args['s'] as String?) ?? '';
  final String prevBuffer = (args['staticBuffer'] as String?) ?? '';
  final String s = '$prevBuffer$chunk';

  final List<Map<String, dynamic>> items = [];
  int depth = 0;
  bool inString = false;
  bool escape = false;
  int startIndex = 0;

  for (int i = 0; i < s.length; i++) {
    final String ch = s[i];

    if (escape) {
      escape = false;
      continue;
    }
    if (ch == '\\') {
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
        final candidate = s.substring(startIndex, i + 1).trim();
        if (candidate.isNotEmpty) {
          try {
            final decoded = HTTPRequest.jsonDecodeAndClean(candidate);
            if (decoded is Map<String, dynamic>) {
              // Remove keys with null values
              decoded.removeWhere((key, value) => value == null);
              // Successfully decoded a JSON object
              items.add(decoded);
            }
          } catch (_) {
            // If decoding fails, keep the candidate for the next chunk.
            break;
          }
        }
        startIndex = i + 1;
      }
    }
  }

  final String buffer = startIndex < s.length ? s.substring(startIndex) : '';
  return {'items': items, 'buffer': buffer};
}

/// Defines shared behavior for HTTP-backed state objects.
///
/// [StateAPI] extends [StateShared] with endpoint construction, authentication,
/// header filtering, pagination-aware fetches, and support for both regular JSON
/// responses and `application/x-json-stream` streams. Typical consumers call
/// [call] for one-shot loads and listen to the inherited [stream] or
/// [notifyListeners] updates for UI refreshes.
///
/// Subclasses usually configure [endpoint], [method], [headersToFilter], and
/// serialization logic. Updates propagate through [data], [error], and
/// [loading], so widgets can react consistently no matter how the response was
/// delivered.
abstract class StateAPI extends StateShared {
  /// Holds the active HTTP client used for outgoing requests.
  http.Client httpClient;

  /// Creates an API state.
  ///
  /// Passing [httpClient] is useful in tests or when a custom transport layer is
  /// required. Otherwise a fresh default [http.Client] is created.
  StateAPI({http.Client? httpClient})
      : httpClient = httpClient ?? http.Client(),
        super();

  /// Remembers the last fully expanded endpoint used by [call].
  ///
  /// This lets the state suppress duplicate requests when the same endpoint is
  /// asked for repeatedly without any intervening reset.
  String? _lastEndpointCalled;

  /// Stores the base endpoint path before query parameters are merged in.
  ///
  /// Callers should update [endpoint] instead of writing this field directly so
  /// the state can trigger lifecycle resets and fetches.
  String baseEndpoint = '';

  /// Stores credentials used by [authScheme] when authenticated requests are
  /// needed.
  ///
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication
  String? credentials;

  /// Defines the HTTP authentication scheme for the next request.
  ///
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes
  /// Use [AuthScheme.Bearer] for token authentication.
  AuthScheme? authScheme;

  /// Automatically uses the current Firebase ID token for authentication.
  ///
  /// When enabled, [call] refreshes [credentials] before each request and forces
  /// [authScheme] to [AuthScheme.Bearer].
  bool token = false;

  /// Defines the HTTP verb used when sending the request.
  HTTPMethod method = HTTPMethod.GET;

  /// Stores the request body for methods such as `POST`, `PUT`, or `PATCH`.
  ///
  /// [call] accepts [String], [Map], and [List] bodies. Unsupported body types
  /// throw so mistakes surface early instead of being silently serialized.
  dynamic body;

  /// Updates the base HTTPS endpoint and triggers a fresh [call].
  ///
  /// Do not prefix the path with `/` when composing relative URLs elsewhere.
  /// Reassigning the same value after data has already loaded is ignored, which
  /// prevents redundant network activity during rebuilds.
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

  /// Returns the active endpoint with current [queryParameters] applied.
  String get endpoint {
    if (queryParameters.isEmpty) return baseEndpoint;
    return Utils.uriMergeQuery(
      uri: Uri.parse(baseEndpoint),
      queryParameters: queryParameters,
    ).toString();
  }

  /// Removes pagination-specific parameters from [url].
  ///
  /// This is used when comparing endpoints so a page change does not look like a
  /// completely unrelated request path.
  String? urlClear(String? url) {
    if (url == null) return null;
    return Utils.uriMergeQuery(
      uri: Uri.parse(url),
      queryParameters: {'page': [], 'limit': [], 'sql': [], 'viewAs': []},
    ).toString();
  }

  /// Stores the raw headers returned by the most recent response.
  Map<String, String> headers = {};

  /// Lists response-header patterns that should be exposed through
  /// [headersFiltered].
  ///
  /// Example: [x-header-name] for exact header
  /// Example: [x-header-*] for wildcard headers
  /// Example: [x-custom-header-name, x-custom-*] for multiple headers
  /// Is not case sensitive
  /// headersToFilter will be used to filter the headers you like to use for the next call
  List<String> get headersToFilter => [];

  /// Returns only the response headers matched by [headersToFilter].
  ///
  /// Exact names and `*` suffix wildcards are supported, and comparisons are
  /// case-insensitive to match HTTP semantics.
  Map<String, String> get headersFiltered {
    Map<String, String> finalHeaders = {};
    final headersToFilterToUse =
        headersToFilter.map((e) => e.toLowerCase()).toList();
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

  /// Tracks the active subscription when the server returns a JSON stream.
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  /// Fetches data from the configured [endpoint].
  ///
  /// This method drives the full API lifecycle: it suppresses duplicate calls,
  /// injects authentication, handles streamed and non-streamed responses,
  /// updates pagination metadata, resets the HTTP client, and propagates state
  /// through [data], [error], [loading], and [initialized]. Listeners should
  /// treat it as the authoritative refresh entry point for API-backed state.
  @override
  Future<dynamic> call({bool ignoreDuplicatedCalls = true}) async {
    /// Prevents duplicate calls with a delay and check for loading call again
    if (loading) return;

    /// Check for empty baseEndpoint
    if (baseEndpoint.isEmpty) {
      data = null;
      error = 'Endpoint path is empty';
      return null;
    }

    /// Check for duplicated calls
    if (ignoreDuplicatedCalls &&
        _lastEndpointCalled == endpoint &&
        data != null) {
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
      final String iconWarning = '⚠️';
      debugPrint(
        LogColor.warning(
          '$iconWarning $errorCount errors calls to endpoint: $baseEndpoint',
        ),
      );
      return data;
    }
    // Start loading
    loading = true;
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
      final originalData = data;
      List<dynamic> streamResponse = [];
      List<dynamic> streamResponseFull = [];
      try {
        final request = http.Request(method.name, url);
        // Add headers to request
        request.headers.addAll(requestHeaders);
        if (body != null) {
          if (body is String) {
            request.body = body;
          } else if (body is Map || body is List) {
            request.body = jsonEncode(body);
            request.headers['Content-Type'] = 'application/json; charset=utf-8';
          } else {
            throw 'Unsupported body type: ${body.runtimeType}';
          }
        }
        final response = await httpClient.send(request);
        headers = response.headers;
        contentType = headers['content-type'];
        if (contentType == null) {
          throw 'No content type found for endpoint: $endpoint';
        }
        isJsonStream = contentType.contains('application/x-json-stream');

        /// Handle json streaming data
        if (isJsonStream) {
          if (!incrementalPagination) {
            newData = [];
            data = [];
            // Wait for animation to complete
            await Future.delayed(const Duration(milliseconds: 500));
          }

          // We'll keep a staticBuffer in this scope and parse chunks on a background isolate
          String staticBuffer = '';

          // Build the transformed stream (maps chunks into Map<String,dynamic>)
          Stream<Map<String, dynamic>> stream = response.stream
              // insert ByteCountTransformer before decoding to UTF-8
              .transform(ByteCountTransformer(maxResponseBytes))
              .transform(Utf8Codec(allowMalformed: true).decoder)
              .asyncExpand((bufferData) async* {
            // Parse the combined buffer + incoming chunk in a background isolate
            final Map<String, dynamic> args = {
              's': bufferData,
              'staticBuffer': staticBuffer,
            };
            Map<String, dynamic> result;
            try {
              if (kIsWeb) {
                // On web, compute() is not supported; fallback to main-isolate parse
                result = await Future.microtask(
                  () => _parseJsonBuffer(args),
                );
              } else {
                result = await compute(_parseJsonBuffer, args);
              }
            } catch (e) {
              // On isolate failure, fallback to main-isolate parse (best-effort)
              result = _parseJsonBuffer(args);
            }
            staticBuffer = result['buffer'] as String? ?? '';
            final List items = result['items'] as List? ?? [];
            for (final item in items) {
              if (item is Map<String, dynamic>) {
                yield item;
              }
            }
          });
          // Cancel any existing subscription
          await _streamSubscription?.cancel();
          // Subscribe and process chunks; wait until stream completes
          _streamSubscription = stream.listen(
            (chunk) async {
              if (chunk.isEmpty) return;
              final originalData = data ?? [];
              // verify if item['id'] is present or add to data without merge method
              if (chunk.containsKey('id')) {
                final baseNewData = [chunk];
                try {
                  // Use isolate for merging data if possible
                  streamResponse = await Future.microtask(
                    () => merge(base: streamResponse, toMerge: baseNewData),
                  );
                  streamResponseFull = await Future.microtask(
                    () => merge(base: originalData, toMerge: baseNewData),
                  );
                } catch (e) {
                  // Fallback to main-isolate merge on failure
                  streamResponse = merge(
                    base: streamResponse,
                    toMerge: baseNewData,
                  );
                  streamResponseFull = merge(
                    base: originalData,
                    toMerge: baseNewData,
                  );
                }
              } else {
                streamResponse = [...streamResponse, chunk];
                streamResponseFull = [...originalData, chunk];
              }
              newData = streamResponse;
              data = streamResponseFull;
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
        error = null;
      } catch (e) {
        final isAbort =
            (e is http.ClientException && e.message.contains('abortTrigger')) ||
                e.toString().contains('abortTrigger');
        if (isAbort) {
          debugPrint(LogColor.warning('API call aborted: $endpoint'));
          return data;
        }
        errorCount++;
        error = e.toString();
      }

      /// pagination
      if (incrementalPagination) {
        bool hasOldData = originalData != null && originalData.isNotEmpty;
        bool hasNewData = newData != null && newData.isNotEmpty;
        // Merge data or return same data as last request
        if (hasOldData && hasNewData) {
          dataResponse = merge(base: originalData, toMerge: newData);
        } else if (hasOldData && !hasNewData) {
          dataResponse = originalData;
        } else {
          dataResponse = newData;
        }
      } else {
        dataResponse = newData;
      }

      /// Set initialized only if no error
      initialized = true;
    } catch (e) {
      initialized = false;
      errorCount++;
      error = e.toString();
    } finally {
      // Finalize data response depending on pagination
      dataResponse = paginate
          ? (dataResponse ?? []) as List<dynamic>
          : dataResponse as dynamic;
      // Set totalCount from headers if present or from data length
      final hasTotalHeader = headers.containsKey('x-total-count');
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
      if (error == null) {
        debugPrint(LogColor.info('✅ Endpoint: $endpoint'));
      } else {
        debugPrint(
          LogColor.error('''
/////////////////////////////////
❌ Endpoint: $endpoint
Error: $error
/////////////////////////////////
'''),
        );
      }

      /// Reset HTTP client to prevent issues with persistent connections
      await _resetHttpClient();
    }

    /// Set data
    data = dataResponse;

    /// Reset loading state
    loading = false;
    return dataResponse;
  }

  /// Recreates the HTTP client and cancels any active JSON-stream subscription.
  ///
  /// Resetting the client avoids stale persistent connections after streaming or
  /// aborted requests, which helps keep later calls predictable.
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

  /// Clears request-specific state and resets the HTTP transport.
  @override
  void clear({bool notify = false}) {
    _lastEndpointCalled = null;
    headers = {};
    _resetHttpClient().whenComplete(() {
      super.clear(notify: notify);
    });
  }
}
