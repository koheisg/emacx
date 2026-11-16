.PHONY: all build release app dist run reload clean

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

# Rebuild, quit the running Emacx, and drop its stale Accessibility grant (the ad-hoc
# signature changes on every build) so the app asks for permission again on launch.
reload: app
	-pgrep -xq Emacx && osascript -e 'quit app id "com.koheisg.emacx"'; for i in $$(seq 25); do pgrep -xq Emacx || break; sleep 0.2; done
	-tccutil reset Accessibility com.koheisg.emacx
	open $(APP)

clean:
	swift package clean
	rm -rf $(APP) .build/Emacx-*.zip
