library test.all;

import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'ddns_updater_test.dart' as ddns_updater_test;
import 'public_address_test.dart' as public_address_test;

main() {
  ddns_updater_test.main();
  public_address_test.main();

  test('version', () {
    var pubspecFile = File('pubspec.yaml');
    var versionInPubspec = loadYaml(pubspecFile.readAsStringSync())['version'];
    print('version in pubspec is $versionInPubspec');

    var dartFile = File('lib/ddns_updater.dart');
    var prefix = 'const String ddnsClientVersion = \'';
    var lines = dartFile.readAsLinesSync();
    var line = lines.firstWhere((line) => line.startsWith(prefix));
    var versionInDartFile =
        line.substring(prefix.length, line.indexOf("'", prefix.length + 1));
    print('version in dart file is $versionInDartFile');

    expect(versionInPubspec, versionInDartFile);
  });
}
