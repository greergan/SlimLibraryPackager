#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(pwd)"

for item in Makefile CMakeLists.txt cmake; do
	if [[ -e "$SOURCE_DIR/$item" ]]; then
		ln -sf "$SOURCE_DIR/$item" "$TARGET_DIR/$item"
	fi
done

cp "$SOURCE_DIR/LICENSE" "$TARGET_DIR"

mkdir -p "$TARGET_DIR/.forgejo"
cp -r "$SOURCE_DIR/forgejo/workflows" "$TARGET_DIR/.forgejo"

cp "$SOURCE_DIR/.gitignore" "$TARGET_DIR"
