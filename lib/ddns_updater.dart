library ddns.updater;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String ddnsClientName = 'dart_ddns_client';
const String ddnsClientVersion = '1.0.1';

/**
 * [DynamicDNSUpdater] is a base class for interacting with a dynamic DNS server
 * such as dyndns.org. This was inspired by python-dyndnsc...
 * https://github.com/infothrill/python-dyndnsc/blob/develop/dyndnsc/updater/dyndns2.py
 */
abstract class DynamicDNSUpdater {
  /// The hostname to be updated
  String hostname;

  /// The username of the account containing dynamic dns entry
  String username;

  /// The password for the account containing dynamic dns entry
  String password;

  DynamicDNSUpdater({this.hostname, this.username, this.password});

  /// Return a new client for updating the dynamic DNS server
  HttpClient get httpClient => new HttpClient();

  /// Update the DDNS service with the new public address.
  /// Return a future that completes with bool indicating success.
  Future<UpdateResult> update(InternetAddress address);
}

abstract class _CommonDNSUpdater extends DynamicDNSUpdater {
  _CommonDNSUpdater({String hostname, String username, String password})
      : super(hostname: hostname, username: username, password: password);

  /// Provide additional information for the request
  Future<HttpClientResponse> processRequest(HttpClientRequest request) {
    request.headers
        .set(HttpHeaders.userAgentHeader, '$ddnsClientName/$ddnsClientVersion');
    // Optionally set up headers...
    // Optionally write to the request object...
    return request.close();
  }

  Future<UpdateResult> processResponse(HttpClientResponse response) {
    UpdateResult result = new UpdateResult();
    result.timestamp = new DateTime.now();
    result.statusCode = response.statusCode;
    result.reasonPhrase = response.reasonPhrase;
    if (result.statusCode != HttpStatus.ok) {
      result.success = false;
      return new Future.value(result);
    }
    Completer<UpdateResult> completer = new Completer();
    response.transform(utf8.decoder).listen((String contents) {
      processResponseContents(result, contents);
      completer.complete(result);
    });
    return completer.future;
  }

  void processResponseContents(UpdateResult result, String contents) {
    result.contents = contents;
    if (contents.startsWith('good ')) {
      result.success = true;
      result.addressText = contents.substring(5).trim();
      return;
    }
    if (contents.startsWith('nochg ')) {
      result.success = null;
      result.addressText = contents.substring(6).trim();
      return;
    }
    result.success = false;
    result.addressText = null;
  }
}

/**
 * [Dyndns2Updater] updates dynamic DNS entries using dyndns2 protocol.
 * See http://dyn.com/support/developers/api/perform-update/
 */
class Dyndns2Updater extends _CommonDNSUpdater {
  Dyndns2Updater({String hostname, String username, String password})
      : super(hostname: hostname, username: username, password: password);

  @override
  Future<UpdateResult> update(InternetAddress address) {
    if (hostname == null) {
      throw 'must set hostname';
    }
    if (username == null || password == null) {
      throw 'must set username/password';
    }
    StringBuffer sb =
        new StringBuffer('https://members.dyndns.org/nic/update?hostname=');
    sb.write(hostname);
    sb.write('&myip=');
    sb.write(address.address);
    Uri uri = Uri.parse(sb.toString());
    HttpClient client = httpClient;
    client.addCredentials(
        uri, 'realm', new HttpClientBasicCredentials(username, password));
    return client.getUrl(uri).then(processRequest).then(processResponse);
  }
}

/**
 * [GoogleDomainsUpdater] updates dynamic DNS records in Google Domains.
 * See "Using the API to update your Dynamic DNS record"
 * in https://support.google.com/domains/answer/6147083
 */
class GoogleDomainsUpdater extends _CommonDNSUpdater {
  GoogleDomainsUpdater({String hostname, String username, String password})
      : super(hostname: hostname, username: username, password: password);

  @override
  Future<UpdateResult> update(InternetAddress address) {
    if (hostname == null) {
      throw 'must set hostname';
    }
    if (username == null || password == null) {
      throw 'must set username/password';
    }
    StringBuffer sb = new StringBuffer('https://');
    sb.write(username);
    sb.write(':');
    sb.write(password);
    sb.write('@domains.google.com/nic/update?hostname=');
    sb.write(hostname);
    sb.write('&myip=');
    sb.write(address.address);
    Uri uri = Uri.parse(sb.toString());
    HttpClient client = httpClient;
    client.addCredentials(
        uri, 'realm', new HttpClientBasicCredentials(username, password));
    return client.getUrl(uri).then(processRequest).then(processResponse);
  }
}

/**
 * [UpdateResult] contains information about success or failure
 * along with the reason for failure if it did fail.
 */
class UpdateResult {
  /// `true` if the update succeeded, `false` if the update failed
  /// or `null` if the server was already updated to the given internet address.
  bool success;

  /// The http status code
  int statusCode;

  /// The reason phrase associated with the status code.
  String reasonPhrase;

  /// The unvalidated address text returned by the server or `null` if none
  String addressText;

  /// The content message returned by the server if any.
  String contents;

  /// When the result was received and processed.
  DateTime timestamp;
}
