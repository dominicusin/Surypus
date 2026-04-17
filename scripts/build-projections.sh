#!/bin/bash
# ============================================================================
# Projection Builder - Builds read models from events
# ============================================================================
set -e

DB_URL="${DATABASE_URL:-postgresql://surypus:surypus_secret@localhost:5432/surypus}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"

echo "Starting projection builder..."
echo "Database: $DB_URL"
echo "Poll interval: ${POLL_INTERVAL}s"

while true; do
	# Get projections that need updating
	projections=$(psql "$DB_URL" -t -A -F',' -c "
        SELECT projection_name, last_sequence
        FROM projections
        WHERE is_enabled = true
        ORDER BY projection_name
    ")

	if [ -z "$projections" ]; then
		sleep "$POLL_INTERVAL"
		continue
	fi

	# Process each projection
	echo "$projections" | while IFS=',' read -r projection_name last_sequence; do
		echo "Processing projection: $projection_name"

		# Get events since last checkpoint
		events=$(psql "$DB_URL" -t -A -F',' -c "
            SELECT event_id, event_type, event_data::text, sequence_number
            FROM event_store
            WHERE sequence_number > $last_sequence
            ORDER BY sequence_number
            LIMIT 1000
        ")

		if [ -z "$events" ]; then
			continue
		fi

		# Process events and update projection
		# In production, would call appropriate handler function

		# Get new last sequence
		new_sequence=$(echo "$events" | tail -1 | cut -d',' -f4)

		# Update checkpoint
		psql "$DB_URL" -c "SELECT projection_update_checkpoint('$projection_name', $new_sequence)"

		echo "Updated $projection_name to sequence $new_sequence"
	done

	sleep "$POLL_INTERVAL"
done
