#!/usr/bin/env bash
#
# build-history.sh - Build tgp-mobil-history.csv from all git history
# Extracts every version of the CSV from git commits, fills in missing dates,
# and produces a single deduplicated history file sorted by date.

set -e

CSV_NAME="mobil.com.au-en-au-commercial-fuels-terminal-gate.csv"
HISTORY_FILE="tgp-mobil-history.csv"
TEMP_ALL=$(mktemp)

echo "Extracting CSV from all git commits..."

# Get all commits that touched the CSV file (oldest first)
commits=$(git log --format="%H" --reverse -- "$CSV_NAME")

for commit in $commits; do
  # Get commit date as YYYY-MM-DD for fallback
  commit_date=$(git log -1 --format='%ci' "$commit" | cut -d' ' -f1)

  # Extract CSV content (skip header)
  git show "$commit":"$CSV_NAME" 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Check if the Date column (last field) is empty
    date_val=$(echo "$line" | awk -F, '{print $NF}')
    if [ -z "$date_val" ]; then
      # Strip trailing comma and append commit date
      line="${line}${commit_date}"
    fi

    echo "$line"
  done >> "$TEMP_ALL"
done

# Write header + sorted unique rows
echo "State,Terminal Locations,E10,ULP,95 Premium,98 Premium,Diesel,Date" > "$HISTORY_FILE"
sort -t, -k8,8 -k1,1 -k2,2 "$TEMP_ALL" | uniq >> "$HISTORY_FILE"

rm -f "$TEMP_ALL"

total=$(tail -n +2 "$HISTORY_FILE" | wc -l)
echo "Built $HISTORY_FILE with $total unique rows"
