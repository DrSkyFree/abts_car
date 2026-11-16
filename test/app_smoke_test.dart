import 'package:abts/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// 入口冒烟测试：保证 lib/main.dart 能通过编译（曾有改动漏掉 import 导致
/// 业务测试全绿、但打包时才报 Undefined name 的情况）。
void main() {
  test('App 入口可编译', () {
    expect(const AbTingShuApp(), isNotNull);
  });
}
