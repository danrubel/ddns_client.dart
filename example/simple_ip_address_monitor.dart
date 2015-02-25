library ip.monitor.example;

import 'dart:io';

import 'package:ddns_client/ddns_updater.dart';
import 'package:ddns_client/public_ip_address.dart';
import 'package:logging/logging.dart';

/// A simple example that monitors the public ip address,
/// notifies the user when it changes,
/// and updates the dynamic DNS entry with the new ip address.
main() {

  // Change the log level to show more information
  // and output log events to the console
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((LogRecord event) {
    var logMsg = '${event.time}: ${event.level.name}: ${event.message}';
    if (event.error != null) logMsg = '$logMsg\n${event.error}';
    if (event.stackTrace != null) logMsg = '$logMsg\n${event.stackTrace}';
    print(logMsg);
  });

  // Simulate loading the current ip address from a file
  // or leave it `null` to accept the current public ip address as valid
  // without updating the dynamic dns entry
  PublicAddressMonitor monitor = new PublicAddressMonitor();
  monitor.address = new InternetAddress('1.2.3.4');

  // Check the public ip address immediately and every 10 minutes thereafter
  monitor.startWatching().listen((PublicAddressEvent event) {
    print('Original public ip address: ${event.oldAddress}');
    print('Current  public ip address: ${event.newAddress}');

    // If the public ip address changed, then update the dynamic dns entry
    if (event.oldAddress != null &&
        event.oldAddress != event.newAddress) {
      Dyndns2Updater updater =
          new Dyndns2Updater(username: null, password: null, hostname: null);
      if (updater.username == null ||
          updater.password == null ||
          updater.hostname == null) {
        print(
            'must supply username, password, and hostname'
                ' to update a dynamic dns entry');
        exit(1);
      }
      updater.update(event.newAddress.address).then((UpdateResult result) {
        if (result.success == true) {
          // success
          print('${updater.hostname}.dyndns.org entry updated');
        } else if (result.success == null) {
          // no change
          print('${updater.hostname}.dyndns.org entry is already correct');
        } else {
          // failed to update dynamic dns entry
          print('failed to update ${updater.hostname}.dyndns.org entry');
        }
      });
    }
  });
}
