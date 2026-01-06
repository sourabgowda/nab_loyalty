#!/bin/bash
# Wrapper to run Chrome with GPU disabled to prevent system hangs with Flutter CanvasKit
/usr/bin/google-chrome --disable-gpu --disable-software-rasterizer "$@"
