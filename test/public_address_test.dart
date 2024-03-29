library test.public.address.monitor;

import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:ddns_client/mock/mock_public_address.dart';
import 'package:ddns_client/public_address.dart';
import 'package:test/test.dart';

main([List<String>? args]) {
  // Pass --testAllWebsites on the command line
  // to test obtaining a public internet address from each website.
  // If this is true and these tests run too frequently
  // then some websites may block this internet address
  // because we are calling them too frequently.
  bool testAllWebsites = false;

  // Pass --testWebsite=<uri> on the command line
  // to test obtaining a public internet address from a specific website
  List<PublicAddressWebsite> testWebsites = [];

  if (args != null) {
    for (String arg in args) {
      if (arg == '--testAllWebsites') testAllWebsites = true;
      if (arg.startsWith('--testWebsite=')) {
        var uri = arg.substring(14);
        var website = PublicAddressWebsite.websites
            .firstWhereOrNull((w) => w.uri.toString() == uri);
        if (website == null) throw 'no such website defined: $uri';
        testWebsites.add(website);
      }
    }
  }

  group('PublicAddressMonitor', () {
    group('checkAddress', () {
      late PublicAddressMonitor monitor;

      setUp(() {
        monitor =
            new PublicAddressMonitor(MockPublicAddressWebsite.randomWebsite);
      });

      test('address null', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        expect(monitor.address, isNull);
        expect(await monitor.checkAddress(), isTrue);
        expect(monitor.address!.address, '1.2.3.4');
      });

      test('address same', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        monitor.address = new InternetAddress('1.2.3.4');
        expect(await monitor.checkAddress(), isFalse);
        expect(monitor.address!.address, '1.2.3.4');
      });

      test('address different', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        monitor.address = new InternetAddress('4.3.2.1');
        expect(await monitor.checkAddress(), isTrue);
        expect(monitor.address!.address, '1.2.3.4');
      });
    });

    group('startWatching', () {
      late PublicAddressMonitor monitor;

      setUp(() {
        monitor =
            new PublicAddressMonitor(MockPublicAddressWebsite.randomWebsite);
      });

      tearDown(() {
        monitor.stopWatching();
      });

      test('address null', () async {
        monitor = PublicAddressMonitor(
            MockPublicAddressWebsiteReturnsNull.randomWebsite);
        expect(monitor.address, isNull);
        Completer completer = new Completer();
        monitor
            .startWatching(duration: const Duration(milliseconds: 2))!
            .listen((PublicAddressEvent event) {
          print('unexpected event: ${event.oldAddress}, ${event.newAddress}');
          completer.complete();
        });
        await completer.future.timeout(const Duration(milliseconds: 10),
            onTimeout: () {
          // timeout expected
        });
        expect(completer.isCompleted, isFalse,
            reason: 'should not send event if null address');
        expect(monitor.address, isNull);
      });

      test('address start', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        expect(monitor.address, isNull);
        Completer completer = new Completer();
        monitor.startWatching()!.listen((PublicAddressEvent event) {
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
        monitor
            .startWatching(duration: const Duration(milliseconds: 2))!
            .listen((PublicAddressEvent event) {
          print('unexpected event: ${event.oldAddress}, ${event.newAddress}');
          completer.complete();
        });
        await completer.future.timeout(const Duration(milliseconds: 10),
            onTimeout: () {
          // timeout expected
        });
        expect(completer.isCompleted, isFalse,
            reason: 'should not send event if address is the same');
        expect(monitor.address!.address, '1.2.3.4');
      });

      test('address different', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '5.6.7.8';
        monitor.address = new InternetAddress('1.2.3.4');
        Completer completer = new Completer();
        monitor.startWatching()!.listen((PublicAddressEvent event) {
          expect(event.oldAddress!.address, '1.2.3.4');
          expect(event.newAddress.address, '5.6.7.8');
          completer.complete();
        });
        await completer.future;
      });

      test('address sequence', () async {
        MockPublicAddressWebsite.addressTextFromWebsite = '1.2.3.4';
        monitor.address = null;
        int eventCount = 0;
        monitor.startWatching()!.listen((PublicAddressEvent event) {
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
      test('bad status code', () async {
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.statusCode = HttpStatus.gatewayTimeout;
        try {
          await website.processResponse(response);
          fail('PublicAddressException exception');
        } on PublicAddressException catch (error) {
          // expected
        }
      });
      test('forbidden', () async {
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.statusCode = HttpStatus.forbidden;
        try {
          await website.processResponse(response);
          fail('PublicAddressException exception');
        } on PublicAddressException catch (error) {
          // expected
        }
      });
      test('invalid address', () async {
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.contents = '1.2.3.4.invalid.address';
        try {
          await website.processResponse(response);
          fail('PublicAddressException expected');
        } on PublicAddressException catch (error) {
          // expected
        }
      });
      test('slow/split response', () async {
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.contents = '1';
        response.contents2 = '.2.3.4';
        var address = await website.processResponse(response);
        expect(address.address, '1.2.3.4');
      });
      test('success', () async {
        PublicAddressWebsite website =
            new PublicAddressWebsite('http://does.not.exist');
        MockResponse response = new MockResponse();
        response.contents = '1.2.3.4';
        var address = await website.processResponse(response);
        expect(address.address, '1.2.3.4');
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

      // Validate all websites
      websites.forEach((PublicAddressWebsite website) {
        expect(website, isNotNull);
        expect(website.uri, isNotNull);

        // Normally we don't want to test this for every website every time
        // the tests are run because the website may block our internet address.
        if (testAllWebsites) {
          print('Request  : ${website.uri}');
          futures.add(website.requestAddress.then((InternetAddress? address) {
            print('Response : ${website.uri} : ${address}');
            results[website.uri] = address!.address;
          }));
        }
      });

      // Test some websites.
      // Normally we don't want to test this for a specific website every time
      // the tests are run because the website may block our internet address.
      testWebsites.forEach((PublicAddressWebsite website) {
        print('Request  : ${website.uri}');
        futures.add(website.requestAddress.then((InternetAddress? address) {
          print('Response : ${website.uri} : ${address}');
          results[website.uri] = address!.address;
        }));
      });

      // Wait for the results, then compare
      return Future.wait(futures).then((_) {
        bool same = true;
        String? expectedAddress = null;
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
  return new Future.delayed(Duration.zero, () => _pumpEventQueue(times - 1));
}

/// Mock response for testing
class MockResponse implements HttpClientResponse {
  int statusCode = HttpStatus.ok;
  String? contents;
  String? contents2;

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<String> transform<String>(
      StreamTransformer<List<int>, String> transformer) {
    var controller = new StreamController<String>();
    new Future.microtask(() {
      controller.add(contents as String);
      if (contents2 != null) controller.add(contents2 as String);
      controller.close();
    });
    return controller.stream;
  }
}

class MockPublicAddressWebsiteReturnsNull extends MockPublicAddressWebsite {
  @override
  Future<InternetAddress?> get requestAddress async => null;

  /// Return a new webiste that will return [addressTextFromWebsite].
  static PublicAddressWebsite randomWebsite() {
    return new MockPublicAddressWebsiteReturnsNull();
  }
}
