#!/usr/bin/env python3
"""Read the wide-format history CSV and emit a normalised CSV + JSON."""

import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HISTORY_CSV = Path("tgp-mobil-history.csv")
NORMALISED_CSV = Path("tgp_data.csv")
JSON_FILE = Path("tgp_data.json")
PROVIDER = "mobil"

FUEL_COLUMNS = {
    "E10": "e10",
    "ULP": "ulp91",
    "95 Premium": "p95",
    "98 Premium": "p98",
    "Diesel": "diesel",
    "Premium Diesel": "prediesel",
    "Biodiesel B5": "b5",
}


def parse_price(value: str):
    value = (value or "").strip()
    if not value or value.upper() == "N/A":
        return None
    try:
        return round(float(value), 1)
    except ValueError:
        return None


def load_records(path: Path):
    records = []
    with path.open(newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            state = (row.get("State") or "").strip()
            location = (row.get("Terminal Locations") or "").strip()
            date = (row.get("Date") or "").strip()
            if not state or not location or not date:
                continue
            if not location[:1].isalpha():
                continue
            for column, fuel_type in FUEL_COLUMNS.items():
                if column not in row:
                    continue
                price = parse_price(row[column])
                if price is None:
                    continue
                records.append((date, state, location, fuel_type, price))
    return records


def dedupe_sorted(records):
    seen = set()
    unique = []
    for rec in records:
        if rec in seen:
            continue
        seen.add(rec)
        unique.append(rec)
    unique.sort(key=lambda r: (r[0], r[1], r[2], r[3]))
    return unique


def write_csv(path: Path, records):
    with path.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(["date", "state", "location", "fuel_type", "price_cpl"])
        for rec in records:
            writer.writerow([rec[0], rec[1], rec[2], rec[3], f"{rec[4]:.1f}"])


def write_json(path: Path, records):
    updated = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    payload = {
        "provider": PROVIDER,
        "updated": updated,
        "fields": ["date", "state", "location", "fuel_type", "price_cpl"],
        "records": [[r[0], r[1], r[2], r[3], r[4]] for r in records],
    }
    with path.open("w") as fh:
        json.dump(payload, fh, separators=(",", ":"))
        fh.write("\n")


def main():
    if not HISTORY_CSV.exists():
        print(f"No history file at {HISTORY_CSV}", file=sys.stderr)
        sys.exit(1)
    records = dedupe_sorted(load_records(HISTORY_CSV))
    write_csv(NORMALISED_CSV, records)
    write_json(JSON_FILE, records)
    print(f"Wrote {len(records)} rows to {NORMALISED_CSV} and {JSON_FILE}")


if __name__ == "__main__":
    main()
