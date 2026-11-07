import 'dart:convert';

import 'package:fabric_flutter/helper/http_request.dart';
import 'package:fabric_flutter/state/state_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/debounce.dart';

/// Concrete [StateAPI] used to exercise the abstract base class.
///
/// The state records every request it sends so tests can assert on the final
/// URL, method, headers, and body without touching the network.
class _TestStateAPI extends StateAPI {
  /// Creates a test state backed by [handler].
  _TestStateAPI(
    Future<http.Response> Function(http.Request request) handler, {
    List<String> filterHeaders = const [],
    this.pagingKeys = const [],
  }) : headersToFilter = filterHeaders,
       super(
         clientFactory: () =>
             MockClient((request) => _record(request, handler)),
       );

  /// Stores every request observed by the mock transport.
  static final List<http.Request> requests = [];

  /// Records [request] before delegating to [handler].
  static Future<http.Response> _record(
    http.Request request,
    Future<http.Response> Function(http.Request request) handler,
  ) {
    requests.add(request);
    return handler(request);
  }

  /// Lists the response headers this state carries into the next request.
  @override
  final List<String> headersToFilter;

  /// Extra paging parameters this state adds to every request.
  final List<String> pagingKeys;

  /// Adds the consumer-specific paging keys to the defaults.
  @override
  List<String> get paginationParameters => [
    ...super.paginationParameters,
    ...pagingKeys,
  ];

  @override
  dynamic get serialized => data;
}

/// Builds a JSON response for the mock transport.
http.Response jsonOk(Object body, {Map<String, String> headers = const {}}) =>
    http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json', ...headers},
    );

/// [http.BaseClient] stub that records whether [close] was called.
class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient({required this.onClose});

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnsupportedError('_CloseTrackingClient is for disposal tests only');
  }

  @override
  void close() {
    onClose();
    super.close();
  }
}

/// [http.Client] stub that replies with a streamed SSE response.
///
/// The client records every request it receives and answers with
/// [responseChunks] delivered one per `send()` as a `text/event-stream`.
class _SseStubClient extends http.BaseClient {
  _SseStubClient(this.responseChunks);

  /// The raw SSE body split into network-sized chunks.
  final List<List<int>> responseChunks;

  /// Stores every request observed by the stub transport.
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final Stream<List<int>> stream = Stream.fromIterable(responseChunks);
    return http.StreamedResponse(
      stream,
      200,
      headers: {'content-type': 'text/event-stream; charset=utf-8'},
    );
  }
}

/// [http.Client] stub that always replies with a non-200 SSE status.
///
/// The stub records each request and answers with an empty stream carrying
/// [statusCode], to exercise the error path of the SSE transport.
class _FailingSseClient extends http.BaseClient {
  _FailingSseClient(this.statusCode);

  /// The HTTP status returned by the stub.
  final int statusCode;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        const Stream<List<int>>.empty(),
        statusCode,
        headers: {'content-type': 'text/event-stream; charset=utf-8'},
      );
}

void main() {
  setUp(_TestStateAPI.requests.clear);

  group('StateAPI', () {
    group('endpoint', () {
      test('should return the base endpoint when no parameters are set', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act
        state.baseEndpoint = 'https://example.com/items';

        // Assert
        expect(state.endpoint, 'https://example.com/items');
      });

      test('should merge query parameters into the endpoint', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.paginate = true;
        state.passParameters = true;

        // Act
        final endpoint = state.endpoint;

        // Assert
        expect(endpoint, contains('page=1'));
        expect(endpoint, contains('limit=10'));
      });
    });

    group('urlClear', () {
      test('should remove pagination parameters from a url', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act
        final result = state.urlClear(
          'https://example.com/items?page=3&limit=50&status=active',
        );

        // Assert
        expect(result, isNot(contains('page=')));
        expect(result, isNot(contains('limit=')));
        expect(result, contains('status=active'));
      });

      test('should return null for a null url', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act & Assert
        expect(state.urlClear(null), isNull);
      });
    });

    group('headersFiltered', () {
      test('should return only the exact headers requested', () {
        // Arrange
        final state = _TestStateAPI(
          (_) async => jsonOk({'id': '1'}),
          filterHeaders: ['x-keep'],
        );
        state.headers = {'X-Keep': 'yes', 'x-drop': 'no'};

        // Act
        final filtered = state.headersFiltered;

        // Assert
        expect(filtered, {'x-keep': 'yes'});
      });

      test('should support wildcard suffix matching', () {
        // Arrange
        final state = _TestStateAPI(
          (_) async => jsonOk({'id': '1'}),
          filterHeaders: ['x-custom-*'],
        );
        state.headers = {
          'X-Custom-One': '1',
          'x-custom-two': '2',
          'x-other': '3',
        };

        // Act
        final filtered = state.headersFiltered;

        // Assert
        expect(filtered, {'x-custom-one': '1', 'x-custom-two': '2'});
      });

      test('should return an empty map when nothing is configured', () {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.headers = {'x-anything': 'value'};

        // Act & Assert
        expect(state.headersFiltered, isEmpty);
      });
    });

    group('call', () {
      test('should set an error when the base endpoint is empty', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act
        final result = await state.call();

        // Assert
        expect(result, isNull);
        expect(state.data, isNull);
        expect(state.error, 'Endpoint path is empty');
        expect(_TestStateAPI.requests, isEmpty);
      });

      test('should fetch and decode a JSON response', () async {
        // Arrange
        final state = _TestStateAPI(
          (_) async => jsonOk({'id': '1', 'name': 'first'}),
        );
        state.baseEndpoint = 'https://example.com/items';

        // Act
        final result = await state.call();

        // Assert
        expect(result, {'id': '1', 'name': 'first'});
        expect(state.data, {'id': '1', 'name': 'first'});
        expect(state.error, isNull);
        expect(state.initialized, isTrue);
        expect(state.loading, isFalse);
      });

      test('should use the configured HTTP method', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.method = HTTPMethod.POST;

        // Act
        await state.call();

        // Assert
        expect(_TestStateAPI.requests.single.method, 'POST');
      });

      test('should encode a Map body as JSON', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.method = HTTPMethod.POST;
        state.body = {'name': 'value'};

        // Act
        await state.call();

        // Assert
        final request = _TestStateAPI.requests.single;
        expect(request.body, '{"name":"value"}');
        expect(request.headers['Content-Type'], contains('application/json'));
      });

      test('should send a String body unchanged', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.method = HTTPMethod.POST;
        state.body = 'raw-payload';

        // Act
        await state.call();

        // Assert
        expect(_TestStateAPI.requests.single.body, 'raw-payload');
      });

      test('should record an error for an unsupported body type', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.method = HTTPMethod.POST;
        state.body = 42;

        // Act
        await state.call();

        // Assert
        expect(state.error, contains('Unsupported body type'));
        expect(state.errorCount, 1);
      });

      test(
        'should attach the Authorization header when authenticated',
        () async {
          // Arrange
          final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
          state.baseEndpoint = 'https://example.com/items';
          state.authScheme = AuthScheme.Bearer;
          state.credentials = 'token-123';

          // Act
          await state.call();

          // Assert
          expect(
            _TestStateAPI.requests.single.headers['Authorization'],
            'Bearer token-123',
          );
        },
      );

      test('should skip the request when credentials are incomplete', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        state.authScheme = AuthScheme.Bearer;

        // Act
        await state.call();

        // Assert
        expect(_TestStateAPI.requests, isEmpty);
        expect(state.loading, isFalse);
        expect(state.data, isNull);
      });

      test('should record an error when no content type is returned', () async {
        // Arrange
        final state = _TestStateAPI((_) async => http.Response('{}', 200));
        state.baseEndpoint = 'https://example.com/items';

        // Act
        await state.call();

        // Assert
        expect(state.error, contains('No content type found'));
        expect(state.errorCount, 1);
      });

      test('should surface the API error message from the payload', () async {
        // Arrange
        final state = _TestStateAPI(
          (_) async => http.Response(
            jsonEncode({'message': 'Not allowed'}),
            403,
            headers: {'content-type': 'application/json'},
          ),
        );
        state.baseEndpoint = 'https://example.com/items';

        // Act
        await state.call();

        // Assert
        expect(state.error, 'Not allowed');
        expect(state.errorCount, 1);
      });

      test('should stop calling after more than one error', () async {
        // Arrange
        final state = _TestStateAPI(
          (_) async => http.Response(
            jsonEncode({'message': 'boom'}),
            500,
            headers: {'content-type': 'application/json'},
          ),
        );
        state.baseEndpoint = 'https://example.com/items';

        // Act
        await state.call(ignoreDuplicatedCalls: false);
        await state.call(ignoreDuplicatedCalls: false);
        final requestsAfterFailures = _TestStateAPI.requests.length;
        await state.call(ignoreDuplicatedCalls: false);

        // Assert: the circuit breaker suppresses the third request.
        expect(state.errorCount, 2);
        expect(_TestStateAPI.requests.length, requestsAfterFailures);
      });

      test('should suppress a duplicated call for the same endpoint', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        await state.call();

        // Act
        final result = await state.call();

        // Assert
        expect(_TestStateAPI.requests, hasLength(1));
        expect(result, {'id': '1'});
      });

      test('should repeat the call when duplicates are not ignored', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        await state.call();

        // Act
        await state.call(ignoreDuplicatedCalls: false);

        // Assert
        expect(_TestStateAPI.requests, hasLength(2));
      });

      test('should read totalCount from the x-total-count header', () async {
        // Arrange
        final state = _TestStateAPI(
          (_) async => jsonOk(
            [
              {'id': '1'},
            ],
            headers: {'x-total-count': '42'},
          ),
        );
        state.baseEndpoint = 'https://example.com/items';

        // Act
        await state.call();

        // Assert
        expect(state.totalCount, 42);
      });

      test(
        'should derive totalCount from the payload when paginating',
        () async {
          // Arrange
          final state = _TestStateAPI(
            (_) async => jsonOk([
              {'id': '1'},
              {'id': '2'},
            ]),
          );
          state.paginate = true;
          state.baseEndpoint = 'https://example.com/items';

          // Act
          await state.call();

          // Assert
          expect(state.totalCount, 2);
        },
      );

      test('should publish the payload through the data stream', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        final received = <dynamic>[];
        final subscription = state.stream.listen(received.add);

        // Act
        await state.call();
        await settleDebounce();

        // Assert
        expect(received.last, {'id': '1'});
        await subscription.cancel();
      });
    });

    group('error paths keep last good data', () {
      test(
        'should keep data and surface error when a call fails after load',
        () async {
          // Arrange
          var fail = false;
          final state = _TestStateAPI(
            (_) async => fail
                ? http.Response('boom', 500)
                : jsonOk([
                    {'id': '1'},
                  ]),
          );
          state.baseEndpoint = 'https://example.com/items';
          await state.call();
          expect(state.data, isNotNull);

          // Act - server error after data already loaded.
          fail = true;
          await state.call(ignoreDuplicatedCalls: false);

          // Assert - last good data kept, error surfaced.
          expect(state.data, isNotNull);
          expect(state.error, isNotNull);
        },
      );

      test('should stop paginating on the last page', () async {
        // Arrange - 20 total, default limit 10: page 2 is the last page.
        final state = _TestStateAPI((request) {
          final page =
              int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
          return Future.value(
            jsonOk(
              List<Map<String, String>>.generate(
                10,
                (index) => {'id': '$page-$index'},
              ),
              headers: {'x-total-count': '20'},
            ),
          );
        });
        state.paginate = true;
        state.baseEndpoint = 'https://example.com/items';
        await state.call();
        expect(state.canPaginate, isTrue);

        // Act
        await state.next();

        // Assert - no further page beyond the last.
        expect(state.page, 2);
        expect(state.canPaginate, isFalse);
      });
    });

    group('incremental pagination', () {
      test('should merge pages that also carry _start and _end', () async {
        // Arrange - the consumer state adds _start/_end to every page.
        final pages = <List<Map<String, dynamic>>>[
          List.generate(10, (i) => {'id': 'a$i'}),
          List.generate(10, (i) => {'id': 'b$i'}),
          List.generate(2, (i) => {'id': 'c$i'}),
        ];
        final state = _TestStateAPI((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          return jsonOk(pages[page - 1], headers: {'x-total-count': '22'});
        }, pagingKeys: ['_start', '_end']);
        state.paginate = true;
        state.passParameters = true;
        state.incrementalPagination = true;
        state.baseEndpoint = 'https://example.com/items';
        void setRange(int page) {
          state.mergeQueryParameters = {
            '_start': ['${(page - 1) * 10 + 1}'],
            '_end': ['${page * 10}'],
          };
        }

        setRange(1);
        await state.call();

        // Act
        setRange(2);
        await state.next();
        setRange(3);
        await state.next();

        // Assert
        expect(state.page, 3);
        expect((state.data as List).length, 22);
      });
    });

    group('incremental streams', () {
      test('should merge streamed items by the configured mergeKey', () async {
        // Arrange - page 2 streams an updated 'b' and a new 'c'. Items carry
        // `uid` instead of `id`, so the merge must use mergeKey.
        var page = 0;
        final bodies = [
          '{"uid":"a","v":1}\n{"uid":"b","v":1}',
          '{"uid":"b","v":2}\n{"uid":"c","v":2}',
        ];
        final state = _TestStateAPI((request) async {
          final body = bodies[page];
          page++;
          return http.Response(
            body,
            200,
            headers: {'content-type': 'application/x-json-stream'},
          );
        });
        state.mergeKey = 'uid';
        state.incrementalPagination = true;
        state.baseEndpoint = 'https://example.com/items';
        await state.call();

        // Act
        await state.call(ignoreDuplicatedCalls: false);

        // Assert
        expect(state.data, [
          {'uid': 'a', 'v': 1},
          {'uid': 'b', 'v': 2},
          {'uid': 'c', 'v': 2},
        ]);
      });
    });

    group('incremental headers', () {
      test('should forward the page token header with the wildcard', () async {
        // Arrange - each page returns a cursor token the next page must send.
        final pages = <List<Map<String, dynamic>>>[
          List.generate(10, (i) => {'id': 'a$i'}),
          List.generate(10, (i) => {'id': 'b$i'}),
          List.generate(2, (i) => {'id': 'c$i'}),
        ];
        final state = _TestStateAPI((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          return jsonOk(
            pages[page - 1],
            headers: {
              'x-total-count': '22',
              'X-Kallisto-Page-Token': 'token-$page',
            },
          );
        }, filterHeaders: ['X-Kallisto-*']);
        state.paginate = true;
        state.passParameters = true;
        state.incrementalPagination = true;
        state.baseEndpoint = 'https://example.com/items';
        await state.call();

        // Act
        await state.next();
        await state.next();

        // Assert - the third request carried the token from page 2.
        expect(state.page, 3);
        expect(
          _TestStateAPI.requests.last.headers['x-kallisto-page-token'],
          'token-2',
        );
        expect((state.data as List).length, 22);
      });
    });

    group('clear', () {
      test('should reset the last endpoint and headers', () async {
        // Arrange
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.baseEndpoint = 'https://example.com/items';
        await state.call();

        // Act
        state.clear();
        await Future<void>.delayed(Duration.zero);
        await state.call();

        // Assert: clearing the cached endpoint allows a fresh request.
        expect(state.headers, isNotEmpty);
        expect(_TestStateAPI.requests, hasLength(2));
      });
    });

    group('call with text/event-stream', () {
      test('should accumulate parsed SSE events into data in order', () async {
        // Arrange
        final client = _SseStubClient([
          utf8.encode(
            'data: {"id":"1","content":"Hello"}\n\n'
            'data: {"id":"2","content":" world"}\n\n'
            'data: [DONE]\n\n',
          ),
        ]);
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.httpClient = client;
        state.baseEndpoint = 'https://example.com/events';
        state.method = HTTPMethod.POST;
        state.body = {'stream': true};

        // Act
        await state.call();

        // Assert
        expect(state.error, isNull);
        expect(state.data, [
          {'id': '1', 'content': 'Hello'},
          {'id': '2', 'content': ' world'},
        ]);
      });

      test(
        'should reassemble a data payload split across chunk boundaries',
        () async {
          // Arrange — one SSE body split mid-JSON across network chunks.
          final client = _SseStubClient([
            utf8.encode('data: {"id":"1","content":"He'),
            utf8.encode('llo"}\n\ndata: {"id":"2","cont'),
            utf8.encode('ent":" world"}\n\ndata: [DONE]\n'),
            utf8.encode('\n'),
          ]);
          final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
          state.httpClient = client;
          state.baseEndpoint = 'https://example.com/events';
          state.method = HTTPMethod.POST;
          state.body = {'stream': true};

          // Act
          await state.call();

          // Assert
          expect(state.error, isNull);
          expect(state.data, [
            {'id': '1', 'content': 'Hello'},
            {'id': '2', 'content': ' world'},
          ]);
        },
      );

      test(
        'should stop at data: [DONE] and ignore anything after it',
        () async {
          // Arrange — a trailing data line follows the completion marker.
          final client = _SseStubClient([
            utf8.encode(
              'data: {"id":"1"}\n\n'
              'data: [DONE]\n\n'
              'data: {"id":"ignored"}\n\n',
            ),
          ]);
          final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
          state.httpClient = client;
          state.baseEndpoint = 'https://example.com/events';
          state.method = HTTPMethod.POST;
          state.body = {'stream': true};

          // Act
          await state.call();

          // Assert
          expect(state.error, isNull);
          expect(state.data, [
            {'id': '1'},
          ]);
        },
      );

      test(
        'should skip comment, blank, non-data lines and malformed payloads',
        () async {
          // Arrange — comments, blank lines, ignored SSE fields, a scalar
          // payload, and a malformed JSON payload are all skipped gracefully.
          final client = _SseStubClient([
            utf8.encode(
              ': heartbeat\n\n'
              'event: message\n'
              'id: 42\n'
              'retry: 1000\n'
              'data: {"id":"a"}\n\n'
              'data: not-json\n\n'
              'data: [DONE]\n\n'
              'data: {"id":"ignored"}\n\n',
            ),
          ]);
          final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
          state.httpClient = client;
          state.baseEndpoint = 'https://example.com/events';
          state.method = HTTPMethod.POST;
          state.body = {'stream': true};

          // Act
          await state.call();

          // Assert
          expect(state.error, isNull);
          expect(state.data, [
            {'id': 'a'},
          ]);
        },
      );

      test('should send the Authorization header when configured', () async {
        // Arrange
        final client = _SseStubClient([utf8.encode('data: [DONE]\n\n')]);
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.httpClient = client;
        state.baseEndpoint = 'https://example.com/events';
        state.method = HTTPMethod.POST;
        state.body = {'stream': true};
        state.authScheme = AuthScheme.Bearer;
        state.credentials = 'token-123';

        // Act
        await state.call();

        // Assert
        final request = client.requests.single as http.Request;
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.headers['Content-Type'], contains('application/json'));
        final Map<String, dynamic> sent =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(sent['stream'], isTrue);
      });

      test('should surface an error when the status is not 200', () async {
        // Arrange — a failing status must surface through `error`.
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        state.httpClient = _FailingSseClient(403);
        state.baseEndpoint = 'https://example.com/events';
        state.method = HTTPMethod.POST;
        state.body = {'stream': true};

        // Act
        await state.call();

        // Assert
        expect(state.error, isNotNull);
        expect(state.error.toString(), contains('403'));
      });
    });

    group('dispose', () {
      test('should not throw when disposed without a prior call', () {
        // Arrange — positive control: dispose must succeed even when no request
        // was ever sent and no streaming subscription exists.
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));

        // Act & Assert
        expect(() => state.dispose(), returnsNormally);
      });

      test('should close the HTTP client on dispose', () {
        // Arrange
        var closeCalled = false;
        final state = _TestStateAPI((_) async => jsonOk({'id': '1'}));
        // Replace the client with one that records close() calls.
        state.httpClient = _CloseTrackingClient(
          onClose: () {
            closeCalled = true;
          },
        );

        // Act
        state.dispose();

        // Assert — the client is closed so its connections are not leaked.
        expect(closeCalled, isTrue);
      });
    });
  });
}
