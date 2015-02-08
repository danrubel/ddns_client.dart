Dart library for checking the public ip address
and updating a dynamic DNS entry.

## Overview

 * __PublicIpAddressMonitor__ provides functionality for both
   a one time check of the public ip address
   and continuous (periodic) monitoring of the public ip address.

 * __DynamicDnsUpdater__ and its subclasses provide functionality
   for updating a dynamic dns entry such as those at dyndns.org

## Example

A [simple example](example/simple_ip_address_monitor.dart)
for monitoring and ip address and updating a dyndns.org entry
is provided as part of this package.

Monitoring a public ip address:

```PublicIpAddressMonitor monitor = new PublicIpAddressMonitor();
monitor.startWatching().listen((PublicIpAddressEvent event) {
  if (event.oldIpAddress != null &&
      event.oldIpAddress != event.newIpAddress) {
    // process changed ip address here
  }
});
```
Updating a dyndns.org entry:

```Dyndns2Updater updater = new Dyndns2Updater(
  username: yourUsername,
  password: yourPassword,
  hostname: yourHostname);
updater.update(newIpAddress).then((UpdateResult result) {
  if (result.success == true) {
    // success
  } else if (result.success == null) {
    // no change
  } else {
    // failed to update dynamic dns entry
  }
});
```
