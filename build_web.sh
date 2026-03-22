#!/bin/bash
# 使い方: ./build_web.sh met      (メトロポリタンさんぽ)
#         ./build_web.sh aic      (印象派さんぽ)
#         ./build_web.sh vermeer  (フェルメールさんぽ)
set -e

TARGET=${1:-met}
FLUTTER=/c/flutter/bin/flutter

case $TARGET in
  met)
    echo "Building メトロポリタンさんぽ..."
    cp web/index_met.html web/index.html
    $FLUTTER build web --release -t lib/main_met.dart
    ;;
  aic)
    echo "Building 印象派さんぽ..."
    cp web/index_aic.html web/index.html
    $FLUTTER build web --release -t lib/main_aic.dart
    ;;
  vermeer)
    echo "Building フェルメールさんぽ..."
    cp web/index_vermeer.html web/index.html
    $FLUTTER build web --release -t lib/main_vermeer.dart
    ;;
  rembrandt)
    echo "Building レンブラントさんぽ..."
    cp web/index_rembrandt.html web/index.html
    $FLUTTER build web --release -t lib/main_rembrandt.dart
    ;;
  *)
    echo "Usage: $0 [met|aic|vermeer|rembrandt]"
    exit 1
    ;;
esac

echo "Done: build/web ($TARGET)"
