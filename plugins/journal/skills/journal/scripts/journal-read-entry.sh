#!/bin/bash
# Usage: journal-read-entry.sh <path>
# Outputs the content of an existing journal entry
[ -f "$1" ] && cat "$1"
