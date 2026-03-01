#!/bin/bash
set -e

# 设置工作目录为脚本所在目录
cd "$(dirname "$0")"

echo "清理构建目录..."
rm -rf build
rm -rf tvbox.xcarchive
rm -f TVBox.ipa

SCHEME="tvbox"
CONFIGURATION="Release"
ARCHIVE_PATH="build/tvbox.xcarchive"
EXPORT_PATH="build/exported"
EXPORT_OPTIONS="ExportOptions.plist"

echo "开始构建 iOS Archive..."
xcodebuild archive \
    -project tvbox.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH"

if [ -f "$EXPORT_OPTIONS" ]; then
    echo "发现 $EXPORT_OPTIONS，尝试导出 IPA..."
    mkdir -p "$EXPORT_PATH"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -exportPath "$EXPORT_PATH" \
        -allowProvisioningUpdates

    # 查找生成的 .ipa 文件并移动到根目录
    IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" | head -n 1)
    if [ -n "$IPA_FILE" ]; then
        cp "$IPA_FILE" ./TVBox.ipa
        echo "✅ 打包完成！生成文件: TVBox.ipa"
    else
        echo "⚠️  未能在导出目录中找到 .ipa 文件。"
    fi
else
    echo "ℹ️  未找到 $EXPORT_OPTIONS，仅生成 Archive。"
    echo "✅ 构建完成！Archive 路径: $ARCHIVE_PATH"
    echo "您可以打开 Xcode 使用 Distribute App 手动导出 IPA。"
fi
