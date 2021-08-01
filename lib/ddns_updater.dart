library ddns.updater;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String ddnsClientName = 'dart_ddns_client';
const String ddnsClientVersion = '2.0.0';

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

  DynamicDNSUpdater({required this.hostname, required this.username, required this.password});

  /// Return a new client for updating the dynamic DNS server
  HttpClient get httpClient => new HttpClient();

  /// Update the DDNS service with the new public address.
  /// Return a future that completes with bool indicating success.
  Future<UpdateResult> update(InternetAddress address);
}

abstract class _CommonDNSUpdater extends DynamicDNSUpdater {
  _CommonDNSUpdater({required String hostname, required String username, required String password})
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
    if (response.statusCode != HttpStatus.ok) {
      return new Future.value(UpdateResult(
        success: false,
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
      ));
    }
    Completer<UpdateResult> completer = new Completer();
    var subscription =
        response.transform(utf8.decoder).listen((String contents) {
      completer.complete(processResponseContents(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        contents: contents,
      ));
    });
    return completer.future.then((result) {
      subscription.cancel();
      return result;
    });
  }

  UpdateResult processResponseContents({
    int? statusCode,
    String? reasonPhrase,
    String? contents,
  }) {
    if (contents != null) {
      if (contents.startsWith('good ')) {
        return UpdateResult(
          success: true,
          statusCode: statusCode,
          reasonPhrase: reasonPhrase,
          addressText: contents.substring(5).trim(),
          contents: contents,
        );
      }
      if (contents.startsWith('nochg ')) {
        return UpdateResult(
          success: null,
          statusCode: statusCode,
          reasonPhrase: reasonPhrase,
          addressText: contents.substring(6).trim(),
          contents: contents,
        );
      }
    }
    return UpdateResult(
      success: false,
      statusCode: statusCode,
      reasonPhrase: reasonPhrase,
      addressText: null,
      contents: contents,
    );
  }
}

/**
 * [Dyndns2Updater] updates dynamic DNS entries using dyndns2 protocol.
 * See http://dyn.com/support/developers/api/perform-update/
 */
class Dyndns2Updater extends _CommonDNSUpdater {
  Dyndns2Updater({required String hostname, required String username, required String password})
      : super(hostname: hostname, username: username, password: password);

  @override
  Future<UpdateResult> update(InternetAddress address) {
    StringBuffer buf = new StringBuffer()
      ..write('https://members.dyndns.org/nic/update?hostname=')
      ..write(hostname)
      ..write('&myip=')
      ..write(address.address);
    Uri uri = Uri.parse(buf.toString());
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
  GoogleDomainsUpdater({required String hostname, required String username, required String password})
      : super(hostname: hostname, username: username, password: password);

  @override
  Future<UpdateResult> update(InternetAddress address) {
    StringBuffer buf = new StringBuffer()
      ..write('https://')
      ..write(username)
      ..write(':')
      ..write(password)
      ..write('@domains.google.com/nic/update?hostname=')
      ..write(hostname)
      ..write('&myip=')
      ..write(address.address);
    Uri uri = Uri.parse(buf.toString());
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
  final bool? success;

  /// The http status code
  final int? statusCode;

  /// The reason phrase associated with the status code.
  final String? reasonPhrase;

  /// The unvalidated address text returned by the server or `null` if none
  final String? addressText;

  /// The content message returned by the server if any.
  final String? contents;

  /// When the result was received and processed.
  final DateTime timestamp;

  UpdateResult({
    this.success,
    this.statusCode,
    this.reasonPhrase,
    this.addressText,
    this.contents,
  }) : timestamp = DateTime.now();
}
