#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <bag_dir>" >&2
  exit 2
fi

BAG_DIR="$1"
MATCH_REGEX='tf|odom|utlidar|camera|realsense|joint|robot_description'

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "ERROR: sqlite3 is not installed." >&2
  echo "Install it with: sudo apt-get update && sudo apt-get install sqlite3" >&2
  exit 1
fi

if [ ! -d "$BAG_DIR" ]; then
  echo "ERROR: bag directory does not exist: $BAG_DIR" >&2
  exit 1
fi

mapfile -t DB_FILES < <(find "$BAG_DIR" -maxdepth 2 -type f -name '*.db3' | sort)

if [ "${#DB_FILES[@]}" -eq 0 ]; then
  echo "ERROR: no rosbag2 sqlite3 .db3 files found under: $BAG_DIR" >&2
  exit 1
fi

TMP_COUNTS="$(mktemp)"
trap 'rm -f "$TMP_COUNTS"' EXIT

for db_file in "${DB_FILES[@]}"; do
  sqlite3 -separator $'\t' "$db_file" "
    SELECT
      topics.name,
      topics.type,
      COUNT(messages.id)
    FROM topics
    LEFT JOIN messages ON messages.topic_id = topics.id
    GROUP BY topics.id, topics.name, topics.type
    ORDER BY topics.name;
  " >> "$TMP_COUNTS"
done

AGGREGATED="$(
  awk -F '\t' '
    {
      key = $1 FS $2
      count[key] += $3
      name[key] = $1
      type[key] = $2
    }
    END {
      for (key in count) {
        print name[key] FS type[key] FS count[key]
      }
    }
  ' "$TMP_COUNTS" | sort
)"

print_table() {
  if command -v column >/dev/null 2>&1; then
    column -t -s $'\t'
  else
    cat
  fi
}

echo "Bag directory: $BAG_DIR"
echo "SQLite files:"
printf '  %s\n' "${DB_FILES[@]}"
echo

echo "All topics:"
{
  printf 'topic\ttype\tmessages\n'
  printf '%s\n' "$AGGREGATED"
} | print_table

echo
echo "Highlighted topics matching: $MATCH_REGEX"
{
  printf 'topic\ttype\tmessages\n'
  printf '%s\n' "$AGGREGATED" | grep -Ei "$MATCH_REGEX" || true
} | print_table

echo
echo "Zero-count topics:"
ZERO_COUNT="$(
  printf '%s\n' "$AGGREGATED" | awk -F '\t' '$3 == 0 {print}'
)"
if [ -n "$ZERO_COUNT" ]; then
  {
    printf 'topic\ttype\tmessages\n'
    printf '%s\n' "$ZERO_COUNT"
  } | print_table
else
  echo "none"
fi
