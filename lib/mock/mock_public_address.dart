library mock.public.address.monitor;

import 'dart:async';
import 'dart:io';

import 'package:ddns_client/public_address.dart';

/// A mock [PublicAddressWebsite] for testing
/// which only implements [requestAddress] and always returns
/// the value specified in [addressTextFromWebsite].
/// Inject [randomWebsite] into a new instance of [PublicAddressMonitor]
/// so that it and applications built on it
/// can be tested without actually querying for the public internet address.
class MockPublicAddressWebsite implements PublicAddressWebsite {
  /// Set this field with the value that would be returned by a public address
  /// provider when the [PublicAddressMonitor.checkAddress] method is called.
  static String addressTextFromWebsite;

  @override
  Future<InternetAddress> get requestAddress {
    if (addressTextFromWebsite == null) {
      throw 'must set addressFromWebsite first';
    }
    return new Future.value(new InternetAddress(addressTextFromWebsite));
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  /// Return a new webiste that will return [addressTextFromWebsite].
  static PublicAddressWebsite randomWebsite() {
    return new MockPublicAddressWebsite();
  }
}
