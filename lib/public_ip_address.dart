library ip.monitor;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ddns_client/ip_address.dart';
import 'package:logging/logging.dart';

/// Signature for a method that will return a website
/// which can be queried for the public ip address.
typedef PublicIpAddressWebsite RandomWebsite();

/// A [PublicIpAddressEvent] represents a public ip address change
/// in the event stream returned by [PublicIpDetector.startWatching].
class PublicIpAddressEvent {
  final String oldIpAddress;
  final String newIpAddress;

  PublicIpAddressEvent(this.oldIpAddress, this.newIpAddress);
}

/// [PublicIpAddressException] represents an exception that occurred
/// when determing the public ip address.
class PublicIpAddressException implements Exception {
  final String message;
  final String url;
  final int statusCode;
  final exception;
  final StackTrace stackTrace;

  const PublicIpAddressException(this.message, this.url, {this.statusCode,
      this.exception, this.stackTrace});

  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write('PublicIpAddressException[');
    sb.write(message);
    sb.write(' url: ');
    sb.write(url);
    if (statusCode != null) {
      sb.write(' statusCode: ');
      sb.write(statusCode);
    }
    if (exception != null) {
      sb.write(' ');
      sb.write(exception);
      if (exception is Error) {
        _writeStackTrace(sb, exception.stackTrace);
      }
    }
    _writeStackTrace(sb, stackTrace);
    sb.write(']');
    return sb.toString();
  }

  void _writeStackTrace(StringBuffer sb, StackTrace stackTrace) {
    if (stackTrace != null) {
      sb.writeln();
      sb.write(stackTrace);
      sb.writeln();
    }
  }
}

/// [PublicIpAddressMonitor] checks the current public ip address using one of several
/// possible [PublicIpAddressWebsite]s. This was inspired by python-dyndnsc...
/// https://github.com/infothrill/python-dyndnsc/blob/develop/dyndnsc/detector/webcheck.py
/// with additional websites from
/// http://stackoverflow.com/questions/3097589/getting-my-public-ip-via-api
class PublicIpAddressMonitor {

  /// The current public ip address.
  /// This field is initialized directly or via the constructor,
  /// and updated when with the current public ip address
  /// when [_hasIpAddressChanged] is called.
  String ipAddress;

  /// The function for obtaining a website
  /// which can be queried for the public ip address.
  RandomWebsite randomWebsite;

  /// The timer used for periodically checking the public ip address
  /// or `null` if not monitoring.
  Timer _monitorTimer;

  /// The controller for sending ip change events to the caller
  /// of [startWatching] or `null` if not monitoring.
  StreamController<PublicIpAddressEvent> _monitorController;

  /// A flag indicating whether [checkIpAddress] has been called
  /// after a call to [startWatching].
  /// This flag will be `null` if [startWatching] has not been called.
  bool _firstIpAddressCheck;

  final Logger _logger = new Logger('PublicIpDetector');

  /// Construct a new public ip address monitor.
  /// Pass [MockPublicIpAddressMonitor.randomWebsite] into this constructor
  /// so that this and applications built on it
  /// can be tested without actually querying for the public ip address.
  PublicIpAddressMonitor([this.randomWebsite]) {
    if (randomWebsite == null)
      randomWebsite = PublicIpAddressWebsite.randomWebsite;
  }

  /// Check [ipAddress] against the ip returned by a public website,
  /// and update [ipAddress] if it is different than what is returned.
  /// Return `true` if [ipAddress] is not `null` and does not match
  /// the ip address returned by a [PublicIpWebsite.randomWebsite].
  Future<bool> get _hasIpAddressChanged {
    PublicIpAddressWebsite website = randomWebsite();
    _logger.log(Level.FINE, 'requesting public ip address from $website');
    return website.requestIpAddress.then((String newIpAddress) {
      if (ipAddress == null) {
        ipAddress = newIpAddress;
        return false;
      }
      if (ipAddress != newIpAddress) {
        ipAddress = newIpAddress;
        return true;
      }
      return false;
    }).catchError((e, s) {
      _logger.log(Level.WARNING, 'failed to obtain public ip address', e, s);
      return false;
    });
  }

  /// Return a [Future] that completes with a boolean indicating
  /// whether [ipAddress] is different that the public ip address
  /// returned by a random public ip address website.
  /// If they are different, then [ipAddress] is updated to match
  /// the value returned by the website.
  /// If [startWatching] has been called, then an event is sent
  /// via the stream returned by [startWatching].
  Future<bool> checkIpAddress([_]) async {
    String oldIpAddress = ipAddress;

    bool hasChanged = await _hasIpAddressChanged;

    // If the ipAddress has changed or the website failed to return an address,
    // then verify the new IP address with a different website
    // before reporting it as changed
    if (hasChanged || ipAddress == null) {
      String newIpAddress = ipAddress;
      ipAddress = oldIpAddress;
      hasChanged = await _hasIpAddressChanged && ipAddress == newIpAddress;
    }

    // If the ipAddress has changed or this is the first ip address check
    // then notify listeners via an event
    if (_monitorController != null && (hasChanged || _firstIpAddressCheck)) {
      _firstIpAddressCheck = false;
      _monitorController.add(
          new PublicIpAddressEvent(oldIpAddress, ipAddress));
    }
    return new Future.value(hasChanged);
  }

  /// Start monitoring the public ip address and return a stream of events.
  /// If monitoring has already been started, then do nothing and return `null`.
  Stream<PublicIpAddressEvent> startWatching({Duration duration}) {
    if (_monitorTimer != null) return null;
    if (duration == null) duration = new Duration(minutes: 10);
    _monitorTimer = new Timer.periodic(duration, checkIpAddress);
    _firstIpAddressCheck = true;
    scheduleMicrotask(checkIpAddress);
    _monitorController = new StreamController();
    return _monitorController.stream;
  }

  /// Stop monitoring the public ip address.
  /// If monitoring is already stopped, then do nothing.
  void stopWatching() {
    if (_monitorTimer == null) return;
    _monitorTimer.cancel();
    _monitorTimer = null;
    _monitorController.close();
    _monitorController = null;
    _firstIpAddressCheck = null;
  }
}

/// [PublicIpAddressWebsite] represents a public site
/// for requesting the public ip address.
class PublicIpAddressWebsite {
  static Random _random;

  /// Websites used to determine the public IP address.
  /// Typically clients periodically call [hasIpAddressChanged]
  /// rather than accessing this field directly.
  ///
  /// Other websites not included here:
  ///      new PublicIpAddressWebsite(
  ///          'http://ipcheck.rehbein.net',
  ///          prefix: 'Current IP Address:',
  ///          suffix: '<br>Hostname:'),
  ///    ("http://ip.arix.com/", _parser_plain),
  ///       curl: (7) Failed connect to ip.arix.com:80; Connection refused
  ///    ("http://jsonip.com/", _parser_jsonip),
  ///    host -t a dartsclink.com | sed 's/.*has address //'
  ///    curl ifconfig.me # this has a lot of different alternatives too,
  ///                       such as ifconfig.me/host
  ///    curl -s ifconfig.me
  ///
  static List<PublicIpAddressWebsite> websites = [
      new PublicIpAddressWebsite(
          'http://checkip.dyndns.org',
          prefix: 'Current IP Address:',
          suffix: '</body>'),
      new PublicIpAddressWebsite(
          'http://checkip.eurodyndns.org',
          prefix: 'Current IP Address:',
          suffix: '<br>Hostname:'),
      new PublicIpAddressWebsite(
          'http://freedns.afraid.org:8080/dynamic/check.php',
          prefix: 'Detected IP :',
          suffix: 'HTTP_CLIENT_IP'),
      new PublicIpAddressWebsite(
          'http://checkip.dns.he.net',
          prefix: 'Your IP address is :',
          suffix: '</body>'),
      new PublicIpAddressWebsite('http://corz.org/ip'),
      new PublicIpAddressWebsite('http://curlmyip.com'),
      new PublicIpAddressWebsite('http://dynamic.zoneedit.com/checkip.html'),
      new PublicIpAddressWebsite('http://icanhazip.com'),
      new PublicIpAddressWebsite('http://ip.dnsexit.com'),
      new PublicIpAddressWebsite('http://ipinfo.io/ip'),
      new PublicIpAddressWebsite('http://ipv4.icanhazip.com'),
      new PublicIpAddressWebsite('http://ipv4.nsupdate.info/myip')];

  /// The URL of the website used to check the public ip address.
  Uri uri;

  /// The prefix before the IP address in the response or `null` if none
  final String prefix;

  /// The suffix after the IP address in the response or `null` if none
  final String suffix;

  /// Construct a new instance to query the given URL for the public ip address.
  PublicIpAddressWebsite(String url, {this.prefix: null, this.suffix: null}) {
    uri = Uri.parse(url);
  }

  /// Return a new client for querying the server
  HttpClient get httpClient => new HttpClient();

  /// Determine the current public ip address.
  Future<String> get requestIpAddress {
    return httpClient.getUrl(uri).then(processRequest).then(processResponse);
  }

  /// Extract the IP address from the response
  String extractIp(String contents) {
    int start = 0;
    if (prefix != null) {
      int index = contents.indexOf(prefix);
      if (index == -1) {
        throw new PublicIpAddressException(
            'Expected to find $prefix\nin $contents',
            uri.toString());
      }
      start = index + prefix.length;
    }
    int end = contents.length;
    if (suffix != null) {
      int index = contents.indexOf(suffix);
      if (index == -1) {
        throw new PublicIpAddressException(
            'Expected to find $suffix\nin $contents',
            uri.toString());
      }
      end = index;
    }
    return contents.substring(start, end).trim();
  }

  /// Provide additional information for the request
  Future<HttpClientResponse> processRequest(HttpClientRequest request) {
    // Optionally set up headers...
    // Optionally write to the request object...
    return request.close();
  }

  /// Extract the public ip address from the response
  Future<String> processResponse(HttpClientResponse response) {
    if (response.statusCode != HttpStatus.OK) {
      String errMsg = 'Request failed';
      // If the website refused to answer, then remove it from the list
      if (response.statusCode == HttpStatus.FORBIDDEN) {
        websites.remove(this);
        errMsg =
            'Website returned 403 and was removed from the list.'
                ' ${websites.length} webistes remain.';
      }
      throw new PublicIpAddressException(
          errMsg,
          uri.toString(),
          statusCode: response.statusCode);
    }
    Completer<String> completer = new Completer();
    response.transform(UTF8.decoder).listen((String contents) {
      String ip;
      try {
        ip = extractIp(contents);
        if (!isValidIpAddress(ip)) {
          completer.completeError(
              new PublicIpAddressException('Invalid ip extracted: $ip', uri.toString()));
          return;
        }
        completer.complete(ip);
      } catch (e, s) {
        completer.completeError(
            new PublicIpAddressException(
                'Response processing failed',
                uri.toString(),
                exception: e,
                stackTrace: s));
        return;
      }
    }, onError: (e, s) {
      completer.completeError(
          throw new PublicIpAddressException(
              'Response transform failed',
              uri.toString(),
              exception: e,
              stackTrace: s));
    });
    return completer.future;
  }

  String toString() => 'website[$uri]';

  /// Return a random website which can be used to determine
  /// the public IP address.
  static PublicIpAddressWebsite randomWebsite() {
    if (_random == null) _random = new Random();
    int index = _random.nextInt(websites.length);
    return websites[index];
  }
}
