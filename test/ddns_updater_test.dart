library test.ddns.updater;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ddns_client/ddns_updater.dart';
import 'package:unittest/unittest.dart';

main() {
  group('Dyndns2Updater', () {
    Dyndns2Target target;

    setUp(() {
      target = new Dyndns2Target();
    });

    test('update', () {
      target.hostname = 'testhostname.dyndns.org';
      target.username = 'myusername';
      target.password = 'mypassword';
      target.mockResponseContents = 'good 1.2.3.4';
      return target.update('1.2.3.4').then((UpdateResult result) {
        expect(result.success, isTrue);
        expect(result.statusCode, HttpStatus.OK);
        expect(result.reasonPhrase, 'someReason');
        expect(result.contents, 'good 1.2.3.4');
        expect(result.ipAddress, '1.2.3.4');

        MockClient client = target.mockClient;
        Uri urlSent = client.urlSent;
        expect(urlSent.scheme, 'https');
        expect(urlSent.authority, 'members.dyndns.org');
        expect(urlSent.path, '/nic/update');
        Map<String, String> param = urlSent.queryParameters;
        expect(param['hostname'], equals('testhostname.dyndns.org'));
        expect(param['myip'], equals('1.2.3.4'));
        expect(param.length, 2);

        MockRequest request = client.mockRequest;
        List<String> userAgent = request.headers[HttpHeaders.USER_AGENT];
        expect(userAgent, hasLength(1));
        expect(userAgent[0], '$ddnsClientName/$ddnsClientVersion');

        expect(client.credentialsUrl, equals(client.urlSent));
        expect(client.credentialsRealm, 'realm');
        expect(client.credentials, isNotNull);
      });
    });

    test('response_good', () {
      UpdateResult result = new UpdateResult();
      target.processResponseContents(result, 'good 1.2.3.4');
      expect(result.contents, 'good 1.2.3.4');
      expect(result.success, isTrue);
      expect(result.ipAddress, '1.2.3.4');
    });

    test('response_nochg', () {
      UpdateResult result = new UpdateResult();
      target.processResponseContents(result, 'nochg 5.2.3.4');
      expect(result.contents, 'nochg 5.2.3.4');
      expect(result.success, isNull);
      expect(result.ipAddress, '5.2.3.4');
    });

    test('response_badauth', () {
      UpdateResult result = new UpdateResult();
      target.processResponseContents(result, 'badauth');
      expect(result.contents, 'badauth');
      expect(result.success, isFalse);
      expect(result.ipAddress, isNull);
    });

    test('response_404', () {
      MockResponse response = new MockResponse();
      response.statusCode = HttpStatus.NOT_FOUND;
      return target.processResponse(response).then((UpdateResult result) {
        expect(result.statusCode, HttpStatus.NOT_FOUND);
        expect(result.contents, isNull);
        expect(result.success, isFalse);
        expect(result.ipAddress, isNull);
      });
    });
  });
}

/// Testable updater that does not contact the DDNS server
class Dyndns2Target extends Dyndns2Updater {
  String mockResponseContents;
  MockClient mockClient = new MockClient();

  HttpClient get httpClient {
    mockClient.mockResponseContents = mockResponseContents;
    return mockClient;
  }
}

class MockClient implements HttpClient {
  Uri urlSent;
  MockRequest mockRequest;
  String mockResponseContents;
  Uri credentialsUrl;
  String credentialsRealm;
  HttpClientCredentials credentials;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {
    credentialsUrl = url;
    credentialsRealm = realm;
    this.credentials = credentials;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (urlSent == null) {
      urlSent = url;
    } else {
      throw 'called getUrl more than once';
    }
    mockRequest = new MockRequest();
    mockRequest.mockResponseContents = mockResponseContents;
    return new Future.value(mockRequest);
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHeaders extends HttpHeaders {
  Map<String, List<String>> valueMap = { };

  @override
  List<String> operator [](String name) {
    return valueMap[name];
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void set(String name, Object value) {
    valueMap[name] = [value];
  }
}

class MockRequest implements HttpClientRequest {
  final MockHeaders _headers = new MockHeaders();
  String mockResponseContents;

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() {
    MockResponse response = new MockResponse();
    response.mockResponseContents = mockResponseContents;
    return new Future.value(response);
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockResponse implements HttpClientResponse {
  int statusCode = HttpStatus.OK;
  String reasonPhrase = 'someReason';
  String mockResponseContents;

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream transform(StreamTransformer<List<int>, dynamic> streamTransformer) {
    expect(mockResponseContents, isNotNull);
    expect(streamTransformer.runtimeType, equals(UTF8.decoder.runtimeType));
    StreamController<String> controller = new StreamController<String>();
    new Future(() {
      controller.add(mockResponseContents);
    });
    return controller.stream;
  }
}
