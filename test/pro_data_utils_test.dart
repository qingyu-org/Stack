import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/presentation/features/pro/utils/pro_data_utils.dart';

void main() {
  test('formatProValue compacts ints and doubles the same way', () {
    expect(formatProValue(12345), '1.23万');
    expect(formatProValue(12345.0), '1.23万');
    expect(formatProValue(9999.0), '9999');
    expect(formatProValue(9999.5), '9999.50');
  });
}
