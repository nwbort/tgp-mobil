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
  
  cat "$TEMP_FILE" |
    tr '\n\r' ' ' |
    sed 's|<[tT][aA][bB][lL][eE]|\n<table|g' |
    grep -i '<table' | head -1 |
    sed 's|</[tT][rR]>|\n|g' |
    awk '
    BEGIN { max_col = 20; first_row = 1 }
    {
      for (i = 1; i <= max_col; i++) {
        if (rowspan[i] > 0) {
          cells[i] = rowspan_val[i]
          rowspan[i]--
        } else {
          cells[i] = ""
        }
      }
      
      col = 1
      line = $0
      while (match(line, /<[tT][hHdD][^>]*>[^<]*((<[^\/][^>]*>[^<]*)*(<\/[^tT][^>]*>[^<]*)*)*<\/[tT][hHdD]>/)) {
        while (cells[col] != "") col++
        
        cell = substr(line, RSTART, RLENGTH)
        line = substr(line, RSTART + RLENGTH)
        
        rs = 1
        if (match(cell, /rowspan="?[0-9]+/)) {
          rs_str = substr(cell, RSTART, RLENGTH)
          gsub(/[^0-9]/, "", rs_str)
          rs = int(rs_str)
        }
        
        content = cell
        gsub(/<[^>]*>/, "", content)
        gsub(/&nbsp;/, " ", content)
        gsub(/&amp;/, "\\&", content)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", content)
        gsub(/[[:space:]]+/, " ", content)
        
        cells[col] = content
        
        if (rs > 1) {
          rowspan[col] = rs - 1
          rowspan_val[col] = content
        }
        
        col++
      }
      
      max = 0
      for (i = 1; i <= max_col; i++) {
        if (cells[i] != "") max = i
      }
      
      if (max > 0) {
        out = ""
        for (i = 1; i <= max; i++) {
          out = out (i > 1 ? "," : "") cells[i]
        }
        if (out !~ /^[[:space:],]*$/ && out !~ /General Disclaimer/) {
          if (first_row) {
            sub(/^Terminal Locations/, "State,Terminal Locations", out)
            first_row = 0
          }
          print out
        }
      }
    }
    ' > "$CSV_FILE"
  
  rm -f "$TEMP_FILE"
  echo "Saved: $CSV_FILE"
else
  mv "$TEMP_FILE" "${FILENAME}"
  echo "Saved: ${FILENAME}"
fi
