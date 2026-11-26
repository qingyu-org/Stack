import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/core/utils/server_host_normalizer.dart';
import 'package:mono_dash/domain/entities/server.dart';

void main() {
  group('parseServerAddressInput', () {
    test(
      'keeps bare IPv6 and does not split its trailing segment as a port',
      () {
        final result = parseServerAddressInput('2409:8a00:4000:8b1::1');
        expect(result.host, '2409:8a00:4000:8b1::1');
        expect(result.port, isNull);
        expect(result.isHttps, isNull);
      },
    );

    test('parses bracketed IPv6 with scheme, port and path', () {
      final result = parseServerAddressInput(
        'https://[2409:8a00:4000:8b1::1]:10000/api/v2',
      );
      expect(result.host, '2409:8a00:4000:8b1::1');
      expect(result.port, 10000);
      expect(result.isHttps, isTrue);
    });

    test('parses bracketed IPv6 without explicit port', () {
      final result = parseServerAddressInput('[::1]');
      expect(result.host, '::1');
      expect(result.port, isNull);
    });

    test('parses hostname and port', () {
      final result = parseServerAddressInput('panel.example.com:8080');
      expect(result.host, 'panel.example.com');
      expect(result.port, 8080);
    });

    test('parses IPv4 with scheme and full-width colon', () {
      final result = parseServerAddressInput('http://192.168.1.10：10000');
      expect(result.host, '192.168.1.10');
      expect(result.port, 10000);
      expect(result.isHttps, isFalse);
    });

    test('flags a non-numeric port suffix as invalid', () {
      final result = parseServerAddressInput('panel.example.com:abc');
      expect(result.host, 'panel.example.com');
      expect(result.port, isNull);
      expect(result.isPortInvalid, isTrue);
    });

    test('flags an out-of-range port suffix as invalid', () {
      final result = parseServerAddressInput('panel.example.com:70000');
      expect(result.host, 'panel.example.com');
      expect(result.port, isNull);
      expect(result.isPortInvalid, isTrue);
    });

    test('flags an out-of-range bracketed IPv6 port as invalid', () {
      final result = parseServerAddressInput('[2001:db8::1]:70000');
      expect(result.host, '2001:db8::1');
      expect(result.port, isNull);
      expect(result.isPortInvalid, isTrue);
    });

    test('normalizeServerHostInput stays backward compatible', () {
      expect(
        normalizeServerHostInput('https://[2001:db8::1]:10000'),
        '2001:db8::1',
      );
    });
  });

  group('IPv6 URL building', () {
    test('buildServerBaseUrl brackets IPv6 literals', () {
      expect(
        buildServerBaseUrl(
          host: '2409:8a00:4000:8b1::1',
          port: 10000,
          isHttps: false,
        ),
        'http://[2409:8a00:4000:8b1::1]:10000',
      );
    });

    test('Server.baseUrl brackets IPv6 and keeps scheme/port', () {
      final server = Server()
        ..host = '2001:db8::1'
        ..port = 10000
        ..isHttps = true;
      expect(server.baseUrl.toString(), 'https://[2001:db8::1]:10000');
    });

    test('invalid hosts still produce a parseable URL', () {
      final server = Server()
        ..host = 'example.com:abc'
        ..port = 10000;
      expect(() => server.baseUrl, returnsNormally);
    });

    test('Server.displayAddress brackets IPv6', () {
      final server = Server()
        ..host = '2001:db8::1'
        ..port = 10000;
      expect(server.displayAddress, '[2001:db8::1]:10000');
    });
  });
}
