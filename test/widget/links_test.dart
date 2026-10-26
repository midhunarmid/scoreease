import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/features/common/game_ui.dart';

void main() {
  test('a TV link points at the TV page and still parses back to its code', () {
    expect(tvLink('ab12cd'), 'https://scoreease.armid.in/live/ab12cd/tv');
    expect(parseJoinCode(tvLink('ab12cd')), 'ab12cd');
  });
}
