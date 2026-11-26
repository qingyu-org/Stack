import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/presentation/features/dashboard/utils/virtualization_info.dart';

void main() {
  group('parseVirtualizationInfo', () {
    test('returns empty for blank and placeholder values', () {
      expect(parseVirtualizationInfo('').isEmpty, isTrue);
      expect(parseVirtualizationInfo('none').isEmpty, isTrue);
      expect(parseVirtualizationInfo('  ').isEmpty, isTrue);
    });

    test('normalizes known system names and roles', () {
      final info = parseVirtualizationInfo('kvm (host)');
      expect(info.system, 'KVM');
      expect(info.role, 'host');
      expect(info.extraTags, isEmpty);

      final container = parseVirtualizationInfo('docker');
      expect(container.system, 'Docker');
      expect(container.role, 'container');
    });

    test('splits compound values into tags', () {
      final info = parseVirtualizationInfo('qemu; guest; x86_64');
      expect(info.system, 'QEMU');
      expect(info.role, 'guest');
      expect(info.extraTags, isNotEmpty);
    });

    test('ignores valid JSON without recognizable fields', () {
      expect(parseVirtualizationInfo('{}').isEmpty, isTrue);
      expect(parseVirtualizationInfo('{"foo":"bar"}').isEmpty, isTrue);
      expect(parseVirtualizationInfo('[]').isEmpty, isTrue);
    });

    test('extracts fields from JSON-like values', () {
      final info = parseVirtualizationInfo(
        '{"system":"vmware","role":"guest","version":"8.0"}',
      );
      expect(info.system, 'VMware');
      expect(info.role, 'guest');
      expect(info.extraTags, contains('8.0'));
    });

    test('falls back to a truncated label for unknown values', () {
      final info = parseVirtualizationInfo(
        'some-very-long-unknown-virtualization-platform-name',
      );
      expect(info.system, isNotNull);
      expect(info.system!.length, lessThanOrEqualTo(24));
    });
  });
}
