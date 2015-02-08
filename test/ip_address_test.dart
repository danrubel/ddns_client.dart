library ip.address.test;

import 'package:ddns_client/ip_address.dart';
import 'package:unittest/unittest.dart';

main() {
  test('localIpAddresses', () {
    return localIpAddresses.then((List<String> addresses) {
      //print('local ip addresses: $addresses');
      expect(addresses.length, greaterThan(0));
      for (String address in addresses) {
        expect(isValidIpAddress(address), isTrue, reason: address);
      }
    });
  });
  test('isValidIp4Address', () {
    expect(isValidIpv4Address('1.2.3.4'), isTrue);
    expect(isValidIpv4Address('11.12.10.19'), isTrue);
    expect(isValidIpv4Address('111.112.113.114'), isTrue);
    expect(isValidIpv4Address('256.112.113.114'), isFalse);
    expect(isValidIpv4Address('111.299.113.114'), isFalse);
    expect(isValidIpv4Address('111.112.999.114'), isFalse);
    expect(isValidIpv4Address('111.112.113.333'), isFalse);
    expect(isValidIpv4Address('.1.2.3.4'), isFalse);
    expect(isValidIpv4Address('x1.2.3.4'), isFalse);
    expect(isValidIpv4Address('1.x2.3.4'), isFalse);
    expect(isValidIpv4Address('1.2.x3.4'), isFalse);
    expect(isValidIpv4Address('1.2.3.4x'), isFalse);
    expect(isValidIpv4Address('1.2.3.4.'), isFalse);
    expect(isValidIpv4Address('1.2.3.'), isFalse);
    expect(isValidIpv4Address('.1.2.3'), isFalse);
    expect(isValidIpv4Address('1.2.3'), isFalse);
  });
}
