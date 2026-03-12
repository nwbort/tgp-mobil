#!/bin/bash
CSV_NAME="mobil.com.au-en-au-commercial-fuels-terminal-gate.csv"
HISTORY_FILE="tgp-mobil-history.csv"

./download.sh 'https://www.mobil.com.au/en-au/commercial-fuels/terminal-gate'

# Append new data to history CSV (deduplicated)
if [ -f "$CSV_NAME" ]; then
  # Ensure history file has a header
  if [ ! -f "$HISTORY_FILE" ]; then
    head -1 "$CSV_NAME" > "$HISTORY_FILE"
  fi

  # Get today's date as fallback if Date column is empty
  today=$(date -u +%Y-%m-%d)

  # Append new rows, filling in empty dates
  tail -n +2 "$CSV_NAME" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    date_val=$(echo "$line" | awk -F, '{print $NF}')
    if [ -z "$date_val" ]; then
      line="${line}${today}"
    fi
    # Only add if not already present
    if ! grep -qF "$line" "$HISTORY_FILE"; then
      echo "$line" >> "$HISTORY_FILE"
    fi
  done
fi
