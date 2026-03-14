#!/bin/bash
set -e

# 设置工作目录为脚本所在目录
cd "$(dirname "$0")"

UNSIGNED_MODE=false
for arg in "$@"; do
    case "$arg" in
        --unsigned)
            UNSIGNED_MODE=true
            ;;
        *)
            echo "错误: 未知参数 $arg"
            echo "用法: ./package_ios.sh [--unsigned]"
            exit 1
            ;;
    esac
done

echo "清理构建目录..."
rm -rf build
rm -rf tvbox.xcarchive
rm -f TVBox.ipa
rm -f TVBox-unsigned.ipa

SCHEME="tvbox"
CONFIGURATION="Release"
ARCHIVE_PATH="build/tvbox.xcarchive"
EXPORT_PATH="build/exported"
EXPORT_OPTIONS="ExportOptions.plist"

if [ "$UNSIGNED_MODE" = true ]; then
    echo "开始构建未签名 iOS App..."
    DERIVED_DATA_PATH="build/unsigned/DerivedData"
    APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/TVBox.app"
    PAYLOAD_DIR="build/unsigned/Payload"
    UNSIGNED_IPA_PATH="$(pwd)/TVBox-unsigned.ipa"

    xcodebuild \
        -project tvbox.xcodeproj \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=iOS" \
        -sdk iphoneos \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        clean build

    if [ ! -d "$APP_PATH" ]; then
        echo "❌ 构建失败: 找不到 .app 文件: $APP_PATH"
        exit 1
    fi

    rm -rf "$PAYLOAD_DIR"
    mkdir -p "$PAYLOAD_DIR"
    cp -R "$APP_PATH" "$PAYLOAD_DIR/"

    (
        cd build/unsigned
        zip -qry "$UNSIGNED_IPA_PATH" Payload
    )

    if [ ! -f "$UNSIGNED_IPA_PATH" ]; then
        echo "❌ 打包失败: 未生成 .ipa 文件。"
        exit 1
    fi

    echo "✅ 未签名打包完成！生成文件: TVBox-unsigned.ipa"
    exit 0
fi

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
