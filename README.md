Dart library for checking the public internet address
and updating a dynamic dns entry.

## Overview

 * __[PublicAddressMonitor](lib/public_address.dart)__ 
   provides functionality for both
   a one time check of the public internet address
   and continuous (periodic) monitoring of the public internet address.

 * __[DynamicDnsUpdater](lib/ddns_updater.dart)__ 
   and its subclasses provide functionality
   for updating a dynamic dns entry such as those at dyndns.org

## Example

A [simple example](example/simple_address_monitor.dart)
for monitoring an internet address and updating a dyndns.org entry
is provided as part of this package.

### Monitoring a public internet address:

```
var monitor = new PublicAddressMonitor();
monitor.startWatching().listen((PublicAddressEvent event) {
  if (event.oldAddress != null &&
      event.oldAddress != event.newAddress) {
    // process changed internet address here
  }
});
```

### Updating a dyndns.org entry:

```
Dyndns2Updater updater = new Dyndns2Updater(
  username: yourUsername,
  password: yourPassword,
  hostname: yourHostname);
updater.update(newAddress).then((UpdateResult result) {
  if (result.success == true) {
    // success
  } else if (result.success == null) {
    // no change
  } else {
    // failed to update dynamic dns entry
  }
});
```
