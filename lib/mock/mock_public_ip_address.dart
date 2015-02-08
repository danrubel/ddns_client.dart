library ip.monitor.mock;

import 'dart:async';

import 'package:ddns_client/public_ip_address.dart';
import 'package:matcher/matcher.dart';

/// A mock [PublicIpAddressWebsite] for testing
/// which only implements [requestIpAddress] and always returns
/// the value specified in [ipAddressFromWebsite].
/// Inject [MockPublicIpAddressWebsite.randomWebsite] into a new instance
/// of [PublicIpAddressMonitor] so that it and applications built on it
/// can be tested without actually querying for the public ip address.
class MockPublicIpAddressWebsite implements PublicIpAddressWebsite {

  /// Set this field with the value that would be returned by a public ip
  /// address provider when the [hasIpAddressChanged] method is called.
  static String ipAddressFromWebsite;

  /// Return a new webiste that will return [ipAddressFromWebsite].
  static PublicIpAddressWebsite randomWebsite() {
    return new MockPublicIpAddressWebsite();
  }

  @override
  Future<String> get requestIpAddress {
    expect(
        ipAddressFromWebsite,
        isNotNull,
        reason: 'must set ipAddressFromWebsite first');
    return new Future.value(ipAddressFromWebsite);
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
