#!/usr/bin/env bash
# 车机版（横屏大屏）构建脚本
#
# 与手机版的差异：
#   1. 独立包名 dev.pages.abts.car —— 可与手机版并存安装，互不覆盖；
#   2. 应用名「阿B听书车机版」—— 应用列表中单独标识；
#   3. 默认锁定横屏，且开启「车机适配」设置项（上下边距 / 界面缩放）；
#   4. 不参与自动更新引导（包名不同，无法覆盖安装）。
#
# 用法：
#   ./tool/build_car.sh              # 车机版 release APK
#   ./tool/build_car.sh --split      # 按 ABI 拆分
#   ./tool/build_car.sh --debug      # debug 包，快速验证

set -euo pipefail

cd "$(dirname "$0")/.."

MODE="release"
SPLIT=""

for arg in "$@"; do
  case "$arg" in
    --split) SPLIT="--split-per-abi" ;;
    --debug) MODE="debug" ;;
    --profile) MODE="profile" ;;
    *) echo "未知参数：$arg（可用：--split / --debug / --profile）"; exit 1 ;;
  esac
done

echo "==> 车机版构建（ABTS_CAR=true，包名 dev.pages.abts.car）"

flutter pub get

flutter build apk \
  --"$MODE" \
  --dart-define=ABTS_CAR=true \
  $SPLIT

echo
echo "==> 构建完成，产物目录：build/app/outputs/flutter-apk/"
ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
echo
echo "安装到车机：adb install -r build/app/outputs/flutter-apk/app-release.apk"
echo "首次启动后进入「我的 → 系统设置 → 车机/大屏适配」调整上下边距与缩放。"
