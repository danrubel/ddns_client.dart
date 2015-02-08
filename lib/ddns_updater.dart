library ddns.updater;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String ddnsClientName = 'dart-ddns-client';
const String ddnsClientVersion = '0.1';

/**
 * [DynamicDNSUpdater] is a base class for updating a dynamic DNS server
 * such as dyndns.org. This was inspired by python-dyndnsc...
 * https://github.com/infothrill/python-dyndnsc/blob/develop/dyndnsc/updater/dyndns2.py
 *
 */
abstract class DynamicDNSUpdater {

  /// The hostname to be updated
  String hostname;

  DynamicDNSUpdater({this.hostname});

  /// Update the DDNS service with the new IP address.
  /// Return a future that completes with bool indicating success.
  Future<UpdateResult> update(String ipAddress);
}

/**
 * [Dyndns2Updater] updates dynamic DNS entries using dyndns2 protocol.
 * See http://dyn.com/support/developers/api/perform-update/
 */
class Dyndns2Updater extends DynamicDNSUpdater {
  String username;
  String password;

  Dyndns2Updater({String hostname, this.username, this.password})
      : super(hostname: hostname);

  /// Return a new client for updating the dynamic DNS server
  HttpClient get httpClient => new HttpClient();

  /// Provide additional information for the request
  Future<HttpClientResponse> processRequest(HttpClientRequest request) {
    request.headers.set(
        HttpHeaders.USER_AGENT,
        '$ddnsClientName/$ddnsClientVersion');
    // Optionally set up headers...
    // Optionally write to the request object...
    return request.close();
  }

  Future<UpdateResult> processResponse(HttpClientResponse response) {
    UpdateResult result = new UpdateResult();
    result.timestamp = new DateTime.now();
    result.statusCode = response.statusCode;
    result.reasonPhrase = response.reasonPhrase;
    if (result.statusCode != HttpStatus.OK) {
      result.success = false;
      return new Future.value(result);
    }
    Completer<UpdateResult> completer = new Completer();
    response.transform(UTF8.decoder).listen((String contents) {
      processResponseContents(result, contents);
      completer.complete(result);
    });
    return completer.future;
  }

  void processResponseContents(UpdateResult result, String contents) {
    result.contents = contents;
    if (contents.startsWith('good ')) {
      result.success = true;
      result.ipAddress = contents.substring(5).trim();
      return;
    }
    if (contents.startsWith('nochg ')) {
      result.success = null;
      result.ipAddress = contents.substring(6).trim();
      return;
    }
    result.success = false;
    result.ipAddress = null;
  }

  @override
  Future<UpdateResult> update(String ipAddress) {
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
    sb.write(ipAddress);
    Uri uri = Uri.parse(sb.toString());
    HttpClient client = httpClient;
    client.addCredentials(
        uri,
        'realm',
        new HttpClientBasicCredentials(username, password));
    return client.getUrl(uri).then(processRequest).then(processResponse);
  }
}

/**
 * [UpdateResult] contains information about success or failure
 * along with the reason for failure if it did fail.
 */
class UpdateResult {

  /// `true` if the update succeeded, `false` if the update failed
  /// or `null` if the server was already updated to the given ip.
  bool success;

  /// The http status code
  int statusCode;

  /// The reason phrase associated with the status code.
  String reasonPhrase;

  /// The ip address returned by the server or `null` if none
  String ipAddress;

  /// The content message returned by the server if any.
  String contents;

  /// When the result was received and processed.
  DateTime timestamp;
}
