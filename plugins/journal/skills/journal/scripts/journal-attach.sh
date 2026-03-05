#!/usr/bin/env bash
# Copies a media file into journal storage.
# Usage: journal-attach.sh <source> <dest-dir> <dest-filename>
# Verifies source exists, creates dest dir, copies file.

src_file="$1"
dest_dir="$2"
dest_name="$3"

if [ ! -f "$src_file" ]; then
  echo "ERROR: File not found: $src_file" >&2
  exit 1
fi

mkdir -p "$dest_dir"
cp "$src_file" "$dest_dir/$dest_name"
echo "$dest_dir/$dest_name"
