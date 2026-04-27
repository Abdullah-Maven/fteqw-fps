#!/bin/bash
# Metal Shader Compilation Script for macOS
# Compiles .metal files to .metallib

set -e

SHADER_DIR="$(cd "$(dirname "$0")/../shaders" && pwd)"
OUTPUT_DIR="$(cd "$(dirname "$0")" && pwd)"
METAL_SDK_PATH=$(xcrun --show-sdk-path)

echo "=== FTEQW Metal Shader Compiler ==="
echo "Shader directory: $SHADER_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Metal SDK: $METAL_SDK_PATH"
echo ""

# Find all .metal files
METAL_FILES=$(find "$SHADER_DIR" -name "*.metal" -type f)

if [ -z "$METAL_FILES" ]; then
    echo "ERROR: No .metal files found in $SHADER_DIR"
    exit 1
fi

echo "Found shader files:"
echo "$METAL_FILES" | while read file; do
    echo "  - $(basename "$file")"
done
echo ""

# Create temporary directory for intermediate files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Compile each shader to air
AIR_FILES=""
for METAL_FILE in $METAL_FILES; do
    BASENAME=$(basename "$METAL_FILE" .metal)
    AIR_FILE="$TEMP_DIR/${BASENAME}.air"
    
    echo "Compiling: $BASENAME.metal -> $BASENAME.air"
    
    xcrun -sdk macosx metal \
        -c \
        -std=macos-metal2.3 \
        -O3 \
        -ffast-math \
        -fignore-exceptions \
        -target air64-apple-macos \
        -o "$AIR_FILE" \
        "$METAL_FILE"
    
    AIR_FILES="$AIR_FILES $AIR_FILE"
done

echo ""
echo "Linking all shaders into default.metallib..."

# Link all air files into metallib
xcrun -sdk macosx metallib \
    -o "$OUTPUT_DIR/default.metallib" \
    $AIR_FILES

echo ""
echo "✓ Successfully compiled $(echo "$METAL_FILES" | wc -l | tr -d ' ') shaders"
echo "✓ Output: $OUTPUT_DIR/default.metallib"
echo ""

# Verify the library
if [ -f "$OUTPUT_DIR/default.metallib" ]; then
    SIZE=$(ls -lh "$OUTPUT_DIR/default.metallib" | awk '{print $5}')
    echo "Library size: $SIZE"
    echo ""
    echo "To use in your app, copy default.metallib to your app bundle:"
    echo "  cp $OUTPUT_DIR/default.metallib YourApp.app/Contents/Resources/"
else
    echo "ERROR: Failed to create metallib"
    exit 1
fi
