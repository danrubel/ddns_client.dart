library mock.public.address.monitor;

import 'dart:async';
import 'dart:io';

import 'package:ddns_client/public_ip_address.dart';
import 'package:matcher/matcher.dart';

/// A mock [PublicAddressWebsite] for testing
/// which only implements [requestAddress] and always returns
/// the value specified in [addressFromWebsite].
/// Inject [randomWebsite] into a new instance of [PublicAddressMonitor]
/// so that it and applications built on it
/// can be tested without actually querying for the public internet address.
class MockPublicAddressWebsite implements PublicAddressWebsite {

  /// Set this field with the value that would be returned by a public ip
  /// address provider when the [hasIpAddressChanged] method is called.
  static String addressFromWebsite;

  @override
  Future<InternetAddress> get requestAddress {
    expect(
        addressFromWebsite,
        isNotNull,
        reason: 'must set ipAddressFromWebsite first');
    return new Future.value(new InternetAddress(addressFromWebsite));
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  /// Return a new webiste that will return [addressFromWebsite].
  static PublicAddressWebsite randomWebsite() {
    return new MockPublicAddressWebsite();
  }
}
