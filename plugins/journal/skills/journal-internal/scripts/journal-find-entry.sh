#!/bin/bash
# Usage: journal-find-entry.sh <journal-root> <date> <project>
# Outputs the path of an existing entry for this project today, or empty string
ROOT="$1"
DATE="$2"
PROJECT="$3"
YEAR="${DATE:0:4}"
MONTH="${DATE:5:2}"
DAY="${DATE:8:2}"

ls "$ROOT/entries/$YEAR/$MONTH/$DAY/"*"-$PROJECT.md" 2>/dev/null | head -1
