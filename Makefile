prefix ?= /usr/local
bindir = $(prefix)/bin

build:
	swift build -c release

install: build
	install ".build/release/xccov-json-to-sonar-xml" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/xccov-json-to-sonar-xml"

clean:
	rm -rf .build