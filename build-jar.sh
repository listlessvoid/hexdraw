#!/usr/bin/env bash
# Builds hexdraw.jar - a single runnable JAR (no JOGL needed; sketch uses JAVA2D).
# Compiles the sketch via Processing CLI, then bundles everything into one fat jar.
# Usage: ./build-jar.sh
# Run:   java -jar hexdraw.jar

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKETCH_DIR="$SCRIPT_DIR"
EXPORT_DIR="$SCRIPT_DIR/linux-amd64"
EXPORT_LIB="$EXPORT_DIR/lib"
OUT="$SCRIPT_DIR/hexdraw.jar"

PROCESSING="${PROCESSING:-processing}"
if ! command -v "$PROCESSING" >/dev/null 2>&1 && [ ! -x "$PROCESSING" ]; then
  echo "ERROR: Processing CLI not found."
  echo "Install Processing and ensure it is on your PATH, or set:"
  echo "  PROCESSING=/path/to/Processing ./build-jar.sh"
  exit 1
fi

# Prefer bundled JRE tools; fall back to PATH
JAR_TOOL="$EXPORT_DIR/java/bin/jar"
JAVA_BIN="$EXPORT_DIR/java/bin/java"
if [ ! -x "$JAR_TOOL" ]; then JAR_TOOL="$(command -v jar 2>/dev/null || true)"; fi
if [ ! -x "$JAVA_BIN" ]; then JAVA_BIN="$(command -v java 2>/dev/null || true)"; fi
if [ ! -x "$JAR_TOOL" ]; then echo "ERROR: jar tool not found"; exit 1; fi

echo "Compiling sketch via Processing CLI..."
"$PROCESSING" cli \
  --sketch="$SKETCH_DIR" \
  --output="$EXPORT_DIR" \
  --variant=linux-amd64 \
  --no-java \
  --force \
  --export

JARS=(
  core-4.5.2.jar
  annotations-13.0.jar
  antlr-2.7.7.jar
  kotlin-stdlib-2.2.20.jar
  hexdraw.jar
)

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Extracting..."
for jar in "${JARS[@]}"; do
  path="$EXPORT_LIB/$jar"
  if [ ! -f "$path" ]; then
    echo "ERROR: missing $path"
    exit 1
  fi
  (cd "$TMPDIR" && "$JAR_TOOL" xf "$path")
done

mkdir -p "$TMPDIR/META-INF"
printf 'Manifest-Version: 1.0\nMain-Class: hexdraw\n' > "$TMPDIR/META-INF/MANIFEST.MF"

echo "Packing $OUT..."
"$JAR_TOOL" cfm "$OUT" "$TMPDIR/META-INF/MANIFEST.MF" -C "$TMPDIR" .

SIZE=$(du -sh "$OUT" | cut -f1)
echo "Done: hexdraw.jar ($SIZE)"
if [ -x "$JAVA_BIN" ]; then
  echo "Run:  $JAVA_BIN -jar $OUT"
else
  echo "Run:  java -jar $OUT"
fi
