#!/bin/bash
# Run flutter web with HTML renderer to avoid CanvasKit/GPU crashes on Linux
flutter run -d chrome --web-renderer html --verbose
