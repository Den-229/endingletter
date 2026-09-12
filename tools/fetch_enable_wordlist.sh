#!/usr/bin/env bash
# Récupère la Enable Word List publique (~172k mots anglais) et la compresse
# en gzip dans assets/dictionary/enable_seed.txt.gz.
#
# Source : https://github.com/dolph/dictionary (Enable Word List de John Dalbec)
# Licence : domaine public.

set -euo pipefail

DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/dictionary"
TMP_DIR="$(mktemp -d)"
TMP_FILE="$TMP_DIR/enable.txt"
OUT_FILE="$DEST_DIR/enable_seed.txt.gz"

mkdir -p "$DEST_DIR"

URL="${ENABLE_WORDLIST_URL:-https://raw.githubusercontent.com/dolph/dictionary/master/enable1.txt}"

echo "📥 Téléchargement de la Enable Word List depuis : $URL"
curl --fail --silent --show-error --location --output "$TMP_FILE" "$URL"

WORD_COUNT=$(wc -l < "$TMP_FILE" | tr -d ' ')
echo "✅ $WORD_COUNT mots téléchargés"

echo "🗜️  Compression gzip…"
gzip -c "$TMP_FILE" > "$OUT_FILE"

SIZE=$(du -h "$OUT_FILE" | cut -f1)
echo "✅ Wordlist compressée : $OUT_FILE ($SIZE)"

rm -rf "$TMP_DIR"
echo "🎉 Terminé."