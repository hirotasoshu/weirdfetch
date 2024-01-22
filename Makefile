PREFIX?=/usr
BIN?=$(PREFIX)/bin

default:
	zig build -Doptimize=ReleaseFast
install:
	install -Dm755 ./zig-out/bin/weirdfetch $(BIN)/weirdfetch
uninstall:
	rm -f $(BIN)/catfetch
