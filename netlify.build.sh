#!/usr/bin/env bash
# Exit on error
set -e

echo "Cloning Flutter repository..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
export PATH="$PATH:`pwd`/_flutter/bin"

echo "Verifying Flutter installation..."
flutter --version

echo "Building Flutter web app..."
flutter build web --release