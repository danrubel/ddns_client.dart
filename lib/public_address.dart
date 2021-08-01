library public.address.monitor;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';

/// Signature for a method that will return a website
/// which can be queried for the public internet address.
typedef RandomWebsite = PublicAddressWebsite Function();

/// A [PublicAddressEvent] represents a public internet address change
/// in the event stream returned by startWatching method
/// in [PublicAddressMonitor].
class PublicAddressEvent {
  final InternetAddress oldAddress;
  final InternetAddress newAddress;

  PublicAddressEvent(this.oldAddress, this.newAddress);
}

/// [PublicAddressException] represents an exception that occurred
/// when determing the public internet address.
class PublicAddressException implements Exception {
  final String message;
  final String url;
  final int statusCode;
  final exception;
  final StackTrace stackTrace;

  const PublicAddressException(this.message, this.url,
      {this.statusCode, this.exception, this.stackTrace});

  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write('PublicAddressException[');
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

/// [PublicAddressMonitor] checks the current public network address using one
/// of several possible [PublicAddressWebsite]s.
///
/// This was inspired by python-dyndnsc...
/// https://github.com/infothrill/python-dyndnsc/blob/develop/dyndnsc/detector/webcheck.py
///
/// with additional websites from
/// http://stackoverflow.com/questions/3097589/getting-my-public-ip-via-api
/// http://unix.stackexchange.com/questions/22615/how-can-i-get-my-external-ip-address-in-bash
class PublicAddressMonitor {
  /// The current public internet address.
  /// This field is initialized directly or via the constructor,
  /// and updated with the current public internet address
  /// when [checkAddress] is called.
  InternetAddress address;

  /// The function for obtaining a website
  /// which can be queried for the public internet address.
  RandomWebsite randomWebsite;

  /// The timer used for periodically checking the public network address
  /// or `null` if not monitoring.
  Timer _monitorTimer;

  /// The controller for sending public address change events to the caller
  /// of [startWatching] or `null` if not monitoring.
  StreamController<PublicAddressEvent> _monitorController;

  final Logger _logger = new Logger('PublicAddressDetector');

  /// Construct a new public internet address monitor.
  /// Pass `MockPublicAddressMonitor.randomWebsite` into this constructor
  /// so that this and applications built on it
  /// can be tested without actually querying for the public internet address.
  PublicAddressMonitor([this.randomWebsite]) {
    if (randomWebsite == null)
      randomWebsite = PublicAddressWebsite.randomWebsite;
  }

  /// Check [address] against the address returned by a public website,
  /// and update [address] if it is different than what is returned.
  /// Return `true` if [address] is not `null` and does not match
  /// the internet address returned by a [PublicAddressWebsite].
  Future<bool> get _hasAddressChanged {
    PublicAddressWebsite website = randomWebsite();
    _logger.log(Level.FINE, 'requesting public internet address from $website');
    return website.requestAddress.then((InternetAddress newAddress) {
      if (address == null) {
        address = newAddress;
        return true;
      }
      if (address != newAddress) {
        address = newAddress;
        return true;
      }
      return false;
    }).catchError((e, s) {
      _logger.log(Level.WARNING, 'failed to obtain address', e, s);
      return false;
    });
  }

  /// Return a [Future] that completes with a boolean indicating
  /// whether [address] is different that the public internet address
  /// returned by a random public internet address website.
  /// If they are different, then [address] is updated to match
  /// the value returned by the website.
  /// If [startWatching] has been called, then an event is sent
  /// via the stream returned by [startWatching].
  Future<bool> checkAddress([_]) async {
    InternetAddress oldAddress = address;
    if (!await _hasAddressChanged) return false;

    // If the address has changed
    // then verify the new address with a different website
    // before reporting it as changed
    InternetAddress newAddress = address;
    address = oldAddress;
    if (!await _hasAddressChanged) return false;

    // Do not make any changes if the two websites disagree about the address.
    if (address != newAddress) return false;

    // If the address has changed, then notify listeners via an event
    if (_monitorController != null) {
      _monitorController.add(new PublicAddressEvent(oldAddress, address));
    }
    return true;
  }

  /// Start monitoring the public address and return a stream of events.
  /// If monitoring has already been started, then do nothing and return `null`.
  Stream<PublicAddressEvent> startWatching({Duration duration}) {
    if (_monitorTimer != null) return null;
    if (duration == null) duration = new Duration(minutes: 10);
    _monitorTimer = new Timer.periodic(duration, checkAddress);
    scheduleMicrotask(checkAddress);
    _monitorController = new StreamController();
    return _monitorController.stream;
  }

  /// Stop monitoring the public internet address.
  /// If monitoring is already stopped, then do nothing.
  void stopWatching() {
    if (_monitorTimer == null) return;
    _monitorTimer.cancel();
    _monitorTimer = null;
    _monitorController.close();
    _monitorController = null;
  }
}

/// [PublicAddressWebsite] represents a public site
/// for requesting the public internet address.
class PublicAddressWebsite {
  static Random _random;

  /// Websites used to determine the public internet address.
  /// Typically clients periodically call [randomWebsite()]
  /// rather than accessing this field directly.
  ///
  /// Other websites not included here:
  ///      new PublicAddressWebsite(
  ///          'http://ipcheck.rehbein.net',
  ///          prefix: 'Current IP Address:',
  ///          suffix: '<br>Hostname:'),
  ///    ("http://ip.arix.com/", _parser_plain),
  ///       curl: (7) Failed connect to ip.arix.com:80; Connection refused
  ///    ("http://jsonip.com/", _parser_jsonip),
  ///    host -t a dartsclink.com | sed 's/.*has address //'
  ///    http://ifconfig.me/ip - works fine from browser, but not app
  ///    http://corz.org/ip - periodically blocks
  ///
  static List<PublicAddressWebsite> websites = [
    new PublicAddressWebsite('http://checkip.dyndns.org',
        prefix: 'Current IP Address:', suffix: '</body>'),
    new PublicAddressWebsite('http://checkip.eurodyndns.org',
        prefix: 'Current IP Address:', suffix: '<br>Hostname:'),
    new PublicAddressWebsite('http://freedns.afraid.org:8080/dynamic/check.php',
        prefix: 'Detected IP :', suffix: 'HTTP_CLIENT_IP'),
    new PublicAddressWebsite('http://checkip.dns.he.net',
        prefix: 'Your IP address is :', suffix: '</body>'),
    new PublicAddressWebsite('http://bot.whatismyipaddress.com/'),
    new PublicAddressWebsite('http://curlmyip.com'),
    new PublicAddressWebsite('https://domains.google.com/checkip'),
    new PublicAddressWebsite('http://dynamic.zoneedit.com/checkip.html'),
    new PublicAddressWebsite('http://eth0.me/'),
    new PublicAddressWebsite('http://icanhazip.com'),
    new PublicAddressWebsite('http://ident.me/'),
    new PublicAddressWebsite('http://ifcfg.me/ip'),
    new PublicAddressWebsite('http://ip.appspot.com/'),
    new PublicAddressWebsite('http://ip.dnsexit.com'),
    new PublicAddressWebsite('http://ip.tyk.nu/'),
    new PublicAddressWebsite('http://ipecho.net/plain'),
    new PublicAddressWebsite('http://ipinfo.io/ip'),
    new PublicAddressWebsite('http://ipof.in/txt'),
    new PublicAddressWebsite('http://ipv4.icanhazip.com'),
    new PublicAddressWebsite('http://ipv4.nsupdate.info/myip'),
    new PublicAddressWebsite('http://l2.io/ip'),
    new PublicAddressWebsite('http://tnx.nl/ip'),
    new PublicAddressWebsite('http://wgetip.com/'),
    new PublicAddressWebsite('http://whatismyip.akamai.com/'),
  ];

  /// The URL of the website used to check the public internet address.
  Uri uri;

  /// The prefix before the internet address in the response or `null` if none
  final String prefix;

  /// The suffix after the internet address in the response or `null` if none
  final String suffix;

  /// Construct a new instance to query the given URL for the public address.
  PublicAddressWebsite(String url, {this.prefix: null, this.suffix: null}) {
    uri = Uri.parse(url);
  }

  /// Return a new client for querying the server
  HttpClient get httpClient => new HttpClient();

  /// Determine the current public internet address.
  Future<InternetAddress> get requestAddress {
    var timeout = new Duration(seconds: 9);
    return httpClient
        .getUrl(uri)
        .then(processRequest)
        .timeout(timeout)
        .then(processResponse)
        .catchError((e) {
      throw new PublicAddressException(
          'No response within $timeout', uri.toString(),
          exception: e);
    }, test: (e) => e is TimeoutException);
  }

  /// Extract the internet address from the response
  InternetAddress extractAddress(String contents) {
    int start = 0;
    if (prefix != null) {
      int index = contents.indexOf(prefix);
      if (index == -1) {
        throw new PublicAddressException(
            'Expected to find $prefix\nin $contents', uri.toString());
      }
      start = index + prefix.length;
    }
    int end = contents.length;
    if (suffix != null) {
      int index = contents.indexOf(suffix);
      if (index == -1) {
        throw new PublicAddressException(
            'Expected to find $suffix\nin $contents', uri.toString());
      }
      end = index;
    }
    String text = contents.substring(start, end).trim();
    try {
      return new InternetAddress(text);
    } on ArgumentError catch (e, s) {
      throw new PublicAddressException(
          'Extracted invalid address: $text from: $contents', uri.toString(),
          exception: e, stackTrace: s);
    }
  }

  /// Provide additional information for the request
  Future<HttpClientResponse> processRequest(HttpClientRequest request) {
    // Optionally set up headers...
    // Optionally write to the request object...
    return request.close();
  }

  /// Extract the public internet address from the response
  Future<InternetAddress> processResponse(HttpClientResponse response) {
    if (response.statusCode != HttpStatus.ok) {
      String errMsg = 'Request failed';
      // If the website refused to answer, then remove it from the list
      if (response.statusCode == HttpStatus.forbidden) {
        websites.remove(this);
        errMsg = 'Website returned 403 and was removed from the list.'
            ' ${websites.length} webistes remain.';
      }
      throw new PublicAddressException(errMsg, uri.toString(),
          statusCode: response.statusCode);
    }
    Completer<InternetAddress> completer = new Completer();
    var buf = new StringBuffer();
    response.transform(utf8.decoder).listen((String contents) {
      buf.write(contents);
    }, onDone: () {
      try {
        if (!completer.isCompleted) {
          completer.complete(extractAddress(buf.toString()));
        }
      } catch (e, s) {
        if (!completer.isCompleted) {
          completer.completeError(new PublicAddressException(
              'Response processing failed', uri.toString(),
              exception: e, stackTrace: s));
        }
      }
    }, onError: (e, s) {
      if (!completer.isCompleted) {
        completer.completeError(throw new PublicAddressException(
            'Response transform failed', uri.toString(),
            exception: e, stackTrace: s));
      }
    });
    return completer.future;
  }

  String toString() => 'website[$uri]';

  /// Return a random website which can be used to determine
  /// the public internet address.
  static PublicAddressWebsite randomWebsite() {
    if (_random == null) _random = new Random();
    int index = _random.nextInt(websites.length);
    return websites[index];
  }
}
