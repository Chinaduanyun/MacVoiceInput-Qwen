APP_NAME = VoiceInput
BUILD_DIR = .build/debug
RELEASE_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
APP_DEST = /Applications/$(APP_BUNDLE)
TEAM_ID ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | sed -n 's/.*(\([A-Z0-9]*\)).*/\1/p')

.PHONY: all build run install clean sign release

all: build

build:
	swift build

release:
	swift build -c release

run: build
	$(BUILD_DIR)/$(APP_NAME)

clean:
	swift package clean
	rm -rf .build
	rm -rf $(APP_BUNDLE)

$(APP_BUNDLE): release
	@echo "Creating app bundle..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(RELEASE_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(APP_BUNDLE)/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '<plist version="1.0">' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '<dict>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleDevelopmentRegion</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>en</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleExecutable</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>$(APP_NAME)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleIdentifier</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>com.voiceinput.$(APP_NAME)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleInfoDictionaryVersion</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>6.0</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleName</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>$(APP_NAME)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleIconFile</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>AppIcon</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundlePackageType</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>APPL</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleShortVersionString</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>1.0.0</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleVersion</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>1</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>LSMinimumSystemVersion</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>14.0</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>LSUIElement</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <true/>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>NSMicrophoneUsageDescription</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>VoiceInput 需要使用麦克风来录制您的语音输入</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>NSAppleEventsUsageDescription</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>VoiceInput 需要控制键盘事件来注入转录文本</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>NSSystemExtensionUsageDescription</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>VoiceInput 需要全局监听 Fn 键事件</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '</dict>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '</plist>' >> $(APP_BUNDLE)/Contents/Info.plist

sign: $(APP_BUNDLE)
	@if [ -n "$(TEAM_ID)" ]; then \
		echo "Signing app bundle with Team ID: $(TEAM_ID)"; \
		codesign --force --deep --sign "$(TEAM_ID)" $(APP_BUNDLE); \
	else \
		echo "Warning: No Apple Development Team ID found. Skipping code signing."; \
		echo "Set TEAM_ID to your Apple Developer Team ID to enable code signing."; \
	fi

install: sign
	@echo "Installing to Applications folder..."
	@rm -rf $(APP_DEST)
	@cp -R $(APP_BUNDLE) $(APP_DEST)
	@echo "Installed to $(APP_DEST)"
