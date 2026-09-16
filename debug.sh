#!/bin/sh

set -e

if [ ! -f build/meson-private/coredata.dat ]; then
    meson setup build --prefix=/usr
fi

meson compile -C build

killall io.elementary.wingpanel 2>/dev/null || true
killall io.elementary.wingpanel 2>/dev/null || true

G_MESSAGES_DEBUG=all ./build/src/io.elementary.wingpanel "$@"