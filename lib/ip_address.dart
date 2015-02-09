library ip.address;

import 'dart:async';
import 'dart:io';

int _nine = '9'.codeUnitAt(0);
int _period = '.'.codeUnitAt(0);
int _zero = '0'.codeUnitAt(0);

/// Return a future that completes with a list of local ip addresses
Future<List<InternetAddress>> get localInternetAddresses {
  return NetworkInterface.list().then((List<NetworkInterface> interfaces) {
    List<InternetAddress> addresses = <InternetAddress>[];
    for (NetworkInterface interface in interfaces) {
      for (InternetAddress address in interface.addresses) {
        addresses.add(address);
      }
    }
    return addresses;
  });
}

/// Determine if the given IP is a valid ip address.
bool isValidIpAddress(String ip) {
  try {
    new InternetAddress(ip);
    return true;
  } on ArgumentError {
    return false;
  }
}
