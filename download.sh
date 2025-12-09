#!/usr/bin/env bash
#
# download - Downloader that extracts tables from HTML pages as CSV
# Usage: ./download.sh URL

set -e

USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
ACCEPT="text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
ACCEPT_LANGUAGE="en-AU,en;q=0.9"

if [ $# -ne 1 ]; then
  echo "Usage: $0 URL"
  exit 1
fi

URL="$1"

if [[ ! "$URL" =~ ^https?:// ]]; then
  echo "Error: URL must start with http:// or https://"
  exit 1
fi

TEMP_FILE=$(mktemp)

echo "Downloading $URL"
curl -s -L "$URL" \
  -H "User-Agent: $USER_AGENT" \
  -H "Accept: $ACCEPT" \
  -H "Accept-Language: $ACCEPT_LANGUAGE" \
  -o "$TEMP_FILE" || {
  echo "Error: Failed to download $URL"
  rm -f "$TEMP_FILE"
  exit 1
}

MIME_TYPE=$(file --mime-type -b "$TEMP_FILE")
FILENAME=$(echo "$URL" | sed -E 's|^https?://||' | sed -E 's|^www\.||' | sed 's|/$||' | sed 's|/|-|g')

if [[ "$MIME_TYPE" == "text/html" ]]; then
  CSV_FILE="${FILENAME}.csv"
  
  # Extract table, convert to CSV
  cat "$TEMP_FILE" |
    tr '\n\r' ' ' |
    sed 's|<[tT][aA][bB][lL][eE]|\n<table|g' |
    grep -i '<table' | head -1 |
    sed 's|</[tT][rR]>|\n|g' |
    sed 's|<[tT][dDhH][^>]*>|,|g' |
    sed 's|<[^>]*>||g' |
    sed 's|&nbsp;| |g; s|&amp;|\&|g; s|&lt;|<|g; s|&gt;|>|g' |
    sed 's/^,//' |
    sed 's/[[:space:]]\+/ /g' |
    sed 's/ ,/,/g; s/, /,/g' |
    sed '/General Disclaimer/,$d' |                   # Stop before disclaimer
    grep -v '^[[:space:]]*$' > "$CSV_FILE"
  
  rm -f "$TEMP_FILE"
  echo "Saved: $CSV_FILE"
else
  mv "$TEMP_FILE" "${FILENAME}"
  echo "Saved: ${FILENAME}"
fi
