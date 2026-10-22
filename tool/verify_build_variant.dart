// 车机版构建通道验证（纯 Dart，不依赖 Gradle/JDK）
//
// 验证 Gradle 侧 `isCarBuild` 的判定逻辑与 manifest 占位符取值，
// 与 android/app/build.gradle.kts 中的实现保持一致。
//
// 运行：dart tool/verify_build_variant.dart
import 'dart:convert';

class Variant {
  const Variant({
    required this.isCarBuild,
    required this.applicationId,
    required this.appLabel,
    required this.carOrientation,
  });

  final bool isCarBuild;
  final String applicationId;
  final String appLabel;
  final String carOrientation;

  @override
  String toString() =>
      'applicationId=$applicationId, label=$appLabel, orientation=$carOrientation';
}

int _fail = 0;
int _pass = 0;

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
    print('  PASS  $name');
  } else {
    _fail++;
    print('  FAIL  $name${detail == null ? '' : ' → $detail'}');
  }
}

/// 与 build.gradle.kts 中 isCarBuild 同源的判定
bool detectCarBuild(String? dartDefinesProperty) {
  final raw = dartDefinesProperty ?? '';
  return raw
      .split(',')
      .where((e) => e.trim().isNotEmpty)
      .map((e) {
        try {
          return utf8.decode(base64.decode(e.trim()));
        } catch (_) {
          return '';
        }
      })
      .any((e) => e.trim() == 'ABTS_CAR=true');
}

/// 与 build.gradle.kts 中 manifestPlaceholders 同源的取值
Variant resolveVariant(String? dartDefinesProperty) {
  final isCar = detectCarBuild(dartDefinesProperty);
  return Variant(
    isCarBuild: isCar,
    applicationId: isCar ? 'dev.pages.abts.car' : 'dev.pages.abts',
    appLabel: isCar ? '阿B听书车机版' : '阿B听书',
    carOrientation: isCar ? 'landscape' : 'unspecified',
  );
}

String encode(List<String> defines) =>
    defines.map((d) => base64.encode(utf8.encode(d))).join(',');

void main() {
  print('== 1. 未定义 dart-define → 手机版 ==');
  {
    final v = resolveVariant(null);
    check('isCarBuild = false', !v.isCarBuild);
    check('applicationId = dev.pages.abts',
        v.applicationId == 'dev.pages.abts', v.applicationId);
    check('label = 阿B听书', v.appLabel == '阿B听书', v.appLabel);
    check('orientation = unspecified',
        v.carOrientation == 'unspecified', v.carOrientation);
  }

  print('\n== 2. 空字符串属性 → 手机版 ==');
  {
    final v = resolveVariant('');
    check('isCarBuild = false', !v.isCarBuild);
    check('applicationId = dev.pages.abts',
        v.applicationId == 'dev.pages.abts');
  }

  print('\n== 3. --dart-define=ABTS_CAR=1 → 车机版 ==');
  {
    final defines = encode(['ABTS_CAR=true']);
    print('  (dart-defines 属性值: $defines)');
    final v = resolveVariant(defines);
    check('isCarBuild = true', v.isCarBuild);
    check('applicationId = dev.pages.abts.car',
        v.applicationId == 'dev.pages.abts.car', v.applicationId);
    check('label = 阿B听书车机版',
        v.appLabel == '阿B听书车机版', v.appLabel);
    check('orientation = landscape',
        v.carOrientation == 'landscape', v.carOrientation);
  }

  print('\n== 4. ABTS_CAR=false → 手机版 ==');
  {
    final v = resolveVariant(encode(['ABTS_CAR=false']));
    check('isCarBuild = false', !v.isCarBuild);
    check('applicationId = dev.pages.abts',
        v.applicationId == 'dev.pages.abts', v.applicationId);
  }

  print('\n== 5. 多个 define 混用 → 仍能识别 ==');
  {
    final v = resolveVariant(encode(['FOO=1', 'ABTS_CAR=true', 'BAR=2']));
    check('isCarBuild = true', v.isCarBuild);
    check('applicationId = dev.pages.abts.car',
        v.applicationId == 'dev.pages.abts.car');
  }

  print('\n== 6. 非法 base64 不应崩溃 ==');
  {
    final v = resolveVariant('!!!not-base64!!!,QUJUU19DQVI9dHJ1ZQ==');
    check('仍能识别出车机版', v.isCarBuild);
    check('applicationId = dev.pages.abts.car',
        v.applicationId == 'dev.pages.abts.car');
  }

  print('\n== 7. 两个版本包名不同 → 可并存安装 ==');
  {
    final phone = resolveVariant(null);
    final car = resolveVariant(encode(['ABTS_CAR=true']));
    check('包名不同', phone.applicationId != car.applicationId);
    check('应用名不同', phone.appLabel != car.appLabel);
    check('手机版沿用原包名（不破坏已有用户升级）',
        phone.applicationId == 'dev.pages.abts');
  }

  print('\n== 8. Dart 侧与 Gradle 侧判定一致 ==');
  {
    // Dart 侧: bool.fromEnvironment('ABTS_CAR')，编译期由 --dart-define 注入
    // Gradle 侧: 解码 dart-defines 属性
    // 两者对同一组 define 必须给出一致结论
    const cases = <List<String>>[
      ['ABTS_CAR=true'],
      ['ABTS_CAR=false'],
      ['OTHER=1'],
      [],
    ];
    for (final defines in cases) {
      final gradle = detectCarBuild(defines.isEmpty ? null : encode(defines));
      // Dart 侧等价语义：值 "true" 才为真
      final dartValue = defines
          .where((d) => d.startsWith('ABTS_CAR='))
          .map((d) => d.substring('ABTS_CAR='.length))
          .firstOrNull;
      final dart = dartValue == 'true';
      check('defines=$defines → gradle=$gradle dart=$dart 一致',
          gradle == dart);
    }
  }

  print('\n结果：$_pass 通过 / $_fail 失败');
  if (_fail > 0) {
    throw StateError('有 $_fail 项校验未通过');
  }
}
