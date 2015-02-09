library ip.address.test;

import 'dart:io';

import 'package:ddns_client/ip_address.dart';
import 'package:unittest/unittest.dart';

main() {
  test('localInternetAddresses', () {
    return localInternetAddresses.then((List<InternetAddress> addresses) {
      //print('local ip addresses: $addresses');
      expect(addresses.length, greaterThan(0));
      for (InternetAddress address in addresses) {
        expect(
            isValidIpAddress(address.address),
            isTrue,
            reason: address.address);
      }
    });
  });
}
