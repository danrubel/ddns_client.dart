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

  /// The number of times that [update] is called
  int updateCount = 0;

  @override
  Future<UpdateResult> update(String address) {
    ++updateCount;
    return new Future(() {
      UpdateResult result = new UpdateResult();
      result.success = true;
      result.statusCode = HttpStatus.OK;
      result.reasonPhrase = 'a reason';
      result.ipAddress = address;
      result.contents = 'content returned by ddns website';
      result.timestamp = new DateTime.now();
      return result;
    });
  }
}
