library ddns.updater;

import 'dart:async';
import 'dart:io';

import 'package:ddns_client/ddns_updater.dart';

/// A mock [DynamicDNSUpdater] for testing
/// which only implements [update].
/// Inject [MockDynamicDNSUpdater] wherever [DynamicDNSUpdater] is needed
/// so that application built on it can be tested without
/// actually updating a dynamic dns site.
class MockDynamicDNSUpdater implements DynamicDNSUpdater {
  @override
  String hostname = 'mock.ddns.site';

  @override
  String username;

  @override
  String password;

  /// The number of times that [update] is called
  int updateCount = 0;

  @override
  HttpClient get httpClient => null;

  @override
  Future<UpdateResult> update(InternetAddress address) {
    ++updateCount;
    return new Future(() {
      UpdateResult result = new UpdateResult();
      result.success = true;
      result.statusCode = HttpStatus.ok;
      result.reasonPhrase = 'a reason';
      result.addressText = address.address;
      result.contents = 'content returned by ddns website';
      result.timestamp = new DateTime.now();
      return result;
    });
  }
}
