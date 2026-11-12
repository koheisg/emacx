.PHONY: all build release app dist run clean

APP := .build/Emacx.app
VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ZIP := .build/Emacx-$(VERSION).zip

all: build

build:
	swift build

release:
	swift build -c release

app:
	./scripts/build-app.zsh

dist: app
	rm -f $(ZIP)
	ditto -c -k --keepParent $(APP) $(ZIP)
	shasum -a 256 $(ZIP)

run: app
	open $(APP)

clean:
	swift package clean
	rm -rf $(APP) .build/Emacx-*.zip
