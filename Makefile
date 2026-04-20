PREFIX ?= ~/.local

build:
	swiftc secrets.swift -o secrets -framework Security -framework LocalAuthentication
	codesign --force --sign - secrets

install: build
	mkdir -p $(PREFIX)/bin
	cp secrets $(PREFIX)/bin/secrets

uninstall:
	rm -f $(PREFIX)/bin/secrets

clean:
	rm -f secrets

.PHONY: build install uninstall clean
