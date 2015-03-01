library test.public.address.monitor;

import 'dart:async';
import 'dart:io';

import 'package:ddns_client/mock/mock_public_address.dart';
import 'package:ddns_client/public_address.dart';
import 'package:unittest/unittest.dart';

main([List<String> args]) {

  // Pass --testAllWebsites on the command line
  // to test obtaining an public internet address for each website.
  // If this is true and these tests run too frequently
  // then some websites may block this internet address
  // because we are calling them too frequently.
  bool testAllWebsites =
      args != null &&
      args.length > 0 &&
      args[0] == '--testAllWebsites';

  group('PublicAddressMonitor', () {

    group('checkAddress', () {
      PublicAddressMonitor monitor;

      setUp(() {
        monitor =
            new PublicAddressMonitor(MockPublicAddressWebsite.randomWebsite);
      });

      test('address null', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        expect(monitor.address, isNull);
        expect(await monitor.checkAddress(), isFalse);
        expect(monitor.address.address, '1.2.3.4');
      });

      test('address same', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        monitor.address = new InternetAddress('1.2.3.4');
        expect(await monitor.checkAddress(), isFalse);
        expect(monitor.address.address, '1.2.3.4');
      });

      test('address different', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        monitor.address = new InternetAddress('4.3.2.1');
        expect(await monitor.checkAddress(), isTrue);
        expect(monitor.address.address, '1.2.3.4');
      });
    });

    group('startWatching', () {
      PublicAddressMonitor monitor;

      setUp(() {
        monitor =
            new PublicAddressMonitor(MockPublicAddressWebsite.randomWebsite);
      });

      tearDown(() {
        monitor.stopWatching();
      });

      test('address null', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        expect(monitor.address, isNull);
        Completer completer = new Completer();
        monitor.startWatching().listen((PublicAddressEvent event) {
          expect(event.oldAddress, isNull);
          expect(event.newAddress.address, '1.2.3.4');
          completer.complete();
        });
        await completer.future;
      });

      test('address same', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        monitor.address = new InternetAddress('1.2.3.4');
        Completer completer = new Completer();
        monitor.startWatching().listen((PublicAddressEvent event) {
          expect(event.oldAddress.address, '1.2.3.4');
          expect(event.newAddress.address, '1.2.3.4');
          completer.complete();
        });
        await completer.future;
      });

      test('address different', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '5.6.7.8';
        monitor.address = new InternetAddress('1.2.3.4');
        Completer completer = new Completer();
        monitor.startWatching().listen((PublicAddressEvent event) {
          expect(event.oldAddress.address, '1.2.3.4');
          expect(event.newAddress.address, '5.6.7.8');
          completer.complete();
        });
        await completer.future;
      });

      test('address sequence', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        monitor.address = null;
        int eventCount = 0;
        monitor.startWatching().listen((PublicAddressEvent event) {
          ++eventCount;
        });
        // initial event
        await _pumpEventQueue();
        expect(eventCount, 1);
        // same address = no new event
        monitor.checkAddress();
        await _pumpEventQueue();
        expect(eventCount, 1);
        // different address = new event
        MockPublicAddressWebsite.addressTextFromWebsite = '5.6.7.8';
        monitor.checkAddress();
        await _pumpEventQueue();
        expect(eventCount, 2);
      });
    });
  });

  group('PublicAddressWebsite', () {

    group('extractAddress', () {
      test('simple', () {
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
        InternetAddress result = website.extractAddress('1.2.3.4');
        expect(result.address, '1.2.3.4');
      });
      test('prefix/suffix', () {
        PublicAddressWebsite website = new PublicAddressWebsite(
            'http://does.not.exist',
            prefix: 'start',
            suffix: 'end');
        InternetAddress result =
            website.extractAddress('boostart   1.2.3.4 \t\nendmore');
        expect(result.address, '1.2.3.4');
      });
    });

    group('processResponse', () {
      test('bad status code', () {
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.statusCode = HttpStatus.GATEWAY_TIMEOUT;
        try {
          website.processResponse(response);
          fail('expected exception');
        } on PublicAddressException catch (e) {
          // Expect exception
        }
      });
      test('invalid address', () {
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
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
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.contents = '1.2.3.4';
        bool caughtException = false;
        return website.processResponse(response).catchError((e, s) {
          caughtException = true;
        }).then((InternetAddress address) {
          expect(caughtException, isFalse);
          expect(address.address, '1.2.3.4');
        });
      });
    });

    test('randomWebsite', () {
      PublicAddressWebsite website = PublicAddressWebsite.randomWebsite();
      expect(website, isNotNull);
      expect(PublicAddressWebsite.websites.contains(website), isTrue);
    });

    test('websites', () {
      List<PublicAddressWebsite> websites = PublicAddressWebsite.websites;
      expect(websites.length > 5, isTrue);

      List<Future> futures = <Future>[];
      Map<Uri, String> results = <Uri, String>{};
      websites.forEach((PublicAddressWebsite website) {
        expect(website, isNotNull);
        expect(website.uri, isNotNull);

        // Normally we don't want to test this for every website every time
        // the tests are run because the website may block our internet address.
        if (testAllWebsites) {
          futures.add(website.requestAddress.then((InternetAddress address) {
            results[website.uri] = address.address;
          }));
        }
      });

      // Wait for the results, then compare
      return Future.wait(futures).then((_) {
        bool same = true;
        String expectedAddress = null;
        results.forEach((Uri uri, String address) {
          if (expectedAddress == null) {
            expectedAddress = address;
          } else if (expectedAddress != address) {
            same = false;
          }
        });
        results.forEach((Uri uri, String address) {
          print('$address $uri');
        });
        expect(same, isTrue, reason: 'Expected same address from all websites');
      });
    });
  });

  group('InternetAddress', () {
    test('equal', () {
      var address1 = new InternetAddress('1.2.3.4');
      var address2 = new InternetAddress('1.2.3.4');
      expect(address1, equals(address2));
    });
    test('equal2', () {
      var address1 = new InternetAddress('1.2.3.4');
      var address2 = new InternetAddress('1.2.3.4');
      expect(address1 == address2, isTrue);
    });
    test('unequal', () {
      var address1 = new InternetAddress('1.2.3.45');
      var address2 = new InternetAddress('1.2.3.4');
      expect(address1, isNot(equals(address2)));
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
