library ip.monitor.test;

import 'dart:async';
import 'dart:io';

import 'package:ddns_client/mock/mock_public_ip_address.dart';
import 'package:ddns_client/public_ip_address.dart';
import 'package:unittest/unittest.dart';

main([List<String> args]) {

  // Pass --testAllWebsites on the command line
  // to test obtaining an public ip address for each website.
  // If this is true and these tests run too frequently
  // then some websites may block this ip address
  // because we are calling them too frequently.
  bool testAllWebsites =
      args != null &&
      args.length > 0 &&
      args[0] == '--testAllWebsites';

  group('PublicIpAddressMonitor', () {

    group('checkIpAddress', () {
      PublicIpAddressMonitor monitor;

      setUp(() {
        monitor =
            new PublicIpAddressMonitor(MockPublicIpAddressWebsite.randomWebsite);
      });

      test('ipAddress null', () async {
        MockPublicIpAddressWebsite.ipAddressFromWebsite = '1.2.3.4';
        expect(monitor.ipAddress, isNull);
        expect(await monitor.checkIpAddress(), isFalse);
        expect(monitor.ipAddress, '1.2.3.4');
      });

      test('ipAddress same', () async {
        MockPublicIpAddressWebsite.ipAddressFromWebsite = '1.2.3.4';
        monitor.ipAddress = '1.2.3.4';
        expect(await monitor.checkIpAddress(), isFalse);
        expect(monitor.ipAddress, '1.2.3.4');
      });

      test('ipAddress different', () async {
        MockPublicIpAddressWebsite.ipAddressFromWebsite = '1.2.3.4';
        monitor.ipAddress = '4.3.2.1';
        expect(await monitor.checkIpAddress(), isTrue);
        expect(monitor.ipAddress, '1.2.3.4');
      });
    });

    group('startWatching', () {
      PublicIpAddressMonitor monitor;

      setUp(() {
        monitor =
            new PublicIpAddressMonitor(MockPublicIpAddressWebsite.randomWebsite);
      });

      tearDown(() {
        monitor.stopWatching();
      });

      test('ipAddress null', () async {
        MockPublicIpAddressWebsite.ipAddressFromWebsite = '1.2.3.4';
        expect(monitor.ipAddress, isNull);
        Completer completer = new Completer();
        monitor.startWatching().listen((PublicIpAddressEvent event) {
          expect(event.oldIpAddress, isNull);
          expect(event.newIpAddress, '1.2.3.4');
          completer.complete();
        });
        await completer.future;
      });

      test('ipAddress same', () async {
        MockPublicIpAddressWebsite.ipAddressFromWebsite = '1.2.3.4';
        monitor.ipAddress = '1.2.3.4';
        Completer completer = new Completer();
        monitor.startWatching().listen((PublicIpAddressEvent event) {
          expect(event.oldIpAddress, '1.2.3.4');
          expect(event.newIpAddress, '1.2.3.4');
          completer.complete();
        });
        await completer.future;
      });

      test('ipAddress different', () async {
        MockPublicIpAddressWebsite.ipAddressFromWebsite = '5.6.7.8';
        monitor.ipAddress = '1.2.3.4';
        Completer completer = new Completer();
        monitor.startWatching().listen((PublicIpAddressEvent event) {
          expect(event.oldIpAddress, '1.2.3.4');
          expect(event.newIpAddress, '5.6.7.8');
          completer.complete();
        });
        await completer.future;
      });

      test('ipAddress sequence', () async {
        MockPublicIpAddressWebsite.ipAddressFromWebsite = '1.2.3.4';
        monitor.ipAddress = null;
        int eventCount = 0;
        monitor.startWatching().listen((PublicIpAddressEvent event) {
          ++eventCount;
        });
        // initial event
        await _pumpEventQueue();
        expect(eventCount, 1);
        // same ip address = no new event
        monitor.checkIpAddress();
        await _pumpEventQueue();
        expect(eventCount, 1);
        // different ip address = new event
        MockPublicIpAddressWebsite.ipAddressFromWebsite = '5.6.7.8';
        monitor.checkIpAddress();
        await _pumpEventQueue();
        expect(eventCount, 2);
      });
    });
  });

  group('PublicIpWebsite', () {

    group('extractIpAddress', () {
      test('simple', () {
        PublicIpAddressWebsite website =
            new PublicIpAddressWebsite('http://does.not.exist');
        String result = website.extractIp('1.2.3.4');
        expect('1.2.3.4', result);
      });
      test('prefix/suffix', () {
        PublicIpAddressWebsite website = new PublicIpAddressWebsite(
            'http://does.not.exist',
            prefix: 'start',
            suffix: 'end');
        String result = website.extractIp('boostart   1.2.3.4 \t\nendmore');
        expect('1.2.3.4', result);
      });
    });

    group('processResponse', () {
      test('bad status code', () {
        PublicIpAddressWebsite website =
            new PublicIpAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.statusCode = HttpStatus.GATEWAY_TIMEOUT;
        try {
          website.processResponse(response);
          fail('expected exception');
        } on PublicIpAddressException catch (e) {
          // Expect exception
        }
      });
      test('invalid address', () {
        PublicIpAddressWebsite website =
            new PublicIpAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.contents = '1.2.3.4.invalid.address';
        bool caughtException = false;
        return website.processResponse(response).catchError((e, s) {
          caughtException = true;
        }).then((_) {
          expect(caughtException, isTrue);
        });
      });
      test('success', () {
        PublicIpAddressWebsite website =
            new PublicIpAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.contents = '1.2.3.4';
        bool caughtException = false;
        return website.processResponse(response).catchError((e, s) {
          caughtException = true;
        }).then((String address) {
          expect(caughtException, isFalse);
          expect(address, '1.2.3.4');
        });
      });
    });

    test('randomWebsite', () {
      PublicIpAddressWebsite website = PublicIpAddressWebsite.randomWebsite();
      expect(website, isNotNull);
      expect(PublicIpAddressWebsite.websites.contains(website), isTrue);
    });

    test('websites', () {
      List<PublicIpAddressWebsite> websites = PublicIpAddressWebsite.websites;
      expect(websites.length > 5, isTrue);

      List<Future> futures = <Future>[];
      Map<Uri, String> results = <Uri, String>{};
      websites.forEach((PublicIpAddressWebsite website) {
        expect(website, isNotNull);
        expect(website.uri, isNotNull);

        // Normally we don't want to test this for every website every time
        // the tests are run because the website may block our ip address.
        if (testAllWebsites) {
          futures.add(website.requestIpAddress.then((String ipAddress) {
            results[website.uri] = ipAddress;
          }));
        }
      });

      // Wait for the results, then compare
      return Future.wait(futures).then((_) {
        bool same = true;
        String expectedIp = null;
        results.forEach((Uri uri, String ip) {
          if (expectedIp == null) {
            expectedIp = ip;
          } else if (expectedIp != ip) {
            same = false;
          }
        });
        results.forEach((Uri uri, String ip) {
          print('$ip $uri');
        });
        expect(same, isTrue, reason: 'Expected same IP from all websites');
      });
    });
  });
}

/// Returns a [Future] that completes after pumping the event queue [times]
/// times. By default, this should pump the event queue enough times to allow
/// any code to run, as long as it's not waiting on some external event.
Future _pumpEventQueue([int times = 20]) {
  if (times == 0) return new Future.value();
  // We use a delayed future to allow microtask events to finish. The
  // Future.value or Future() constructors use scheduleMicrotask themselves and
  // would therefore not wait for microtask callbacks that are scheduled after
  // invoking this method.
  return new Future.delayed(Duration.ZERO, () => _pumpEventQueue(times - 1));
}

/// Mock response for testing
class MockResponse implements HttpClientResponse {
  int statusCode = HttpStatus.OK;
  String contents = null;

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream transform(StreamTransformer<List<int>, dynamic> transformer) {
    StreamController<String> controller = new StreamController<String>();
    new Future.microtask(() {
      controller.add(contents);
      controller.close();
    });
    return controller.stream;
  }
}
