#!/bin/bash

# Pre-commit hook for SQL formatting
# Install: cp scripts/pre-commit.sh .git/hooks/pre-commit

echo "Running SQL formatting checks..."

# Check if pg_format is available
if ! command -v pg_format &>/dev/null; then
	echo "Warning: pg_format not found. Install with: sudo apt-get install postgresql-client"
	exit 0
fi

# Files to format
SQL_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.sql$' || true)

if [ -z "$SQL_FILES" ]; then
	echo "No SQL files to format"
	exit 0
fi

echo "Formatting SQL files..."

# Format each SQL file
for file in $SQL_FILES; do
	if [ -f "$file" ]; then
		echo "Formatting: $file"
		pg_format -i "$file" 2>/dev/null || true
		git add "$file"
	fi
done

echo "SQL formatting complete"
exit 0
