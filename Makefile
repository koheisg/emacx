.PHONY: all build release app run clean

APP := .build/Emacx.app

all: build

build:
	swift build

release:
	swift build -c release

app:
	./scripts/build-app.zsh

run: app
	open $(APP)

clean:
	swift package clean
	rm -rf $(APP)
