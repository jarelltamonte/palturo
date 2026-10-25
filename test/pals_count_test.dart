import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/utils/pals_count.dart';

void main() {
  test('pal count is pluralized', () {
    expect(palCountLabel(0), '0 pals');
    expect(palCountLabel(1), '1 pal');
    expect(palCountLabel(2), '2 pals');
  });
}
