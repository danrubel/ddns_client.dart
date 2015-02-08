library ip.address;

import 'dart:async';
import 'dart:io';

int _nine = '9'.codeUnitAt(0);
int _period = '.'.codeUnitAt(0);
int _zero = '0'.codeUnitAt(0);

/// Return a future that completes with a list of local ip addresses
Future<List<String>> get localIpAddresses {
  return NetworkInterface.list().then((List<NetworkInterface> interfaces) {
    List<String> addresses = <String>[];
    for (NetworkInterface interface in interfaces) {
      for (InternetAddress address in interface.addresses) {
        addresses.add(address.address);
      }
    }
    return addresses;
  });
}

/// Determine if the given IP is a valid ip address.
bool isValidIpAddress(String ip) {
  // TODO validate IPv6 address - see https://en.wikipedia.org/wiki/IPv6
  return isValidIpv4Address(ip);
}

/// Determine if the given IP is a valid IPv4 address.
/// Consider calling [isValidIpAddress] instead.
bool isValidIpv4Address(String ip) {
  if (ip == null) return false;
  int periodCount = 0;
  for (int index = 0; index < ip.length; ++index) {
    int code = ip.codeUnitAt(index);
    if (code == _period) {
      ++periodCount;
    } else if (code < _zero || code > _nine) {
      return false;
    }
  }
  if (periodCount != 3) return false;
  bool isValid = true;
  ip.split('.').forEach((String chunk) {
    int value = int.parse(chunk, onError: (_) => -1);
    if (value < 0 || value > 255) isValid = false;
  });
  return isValid;
}
