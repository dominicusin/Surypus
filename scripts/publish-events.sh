#!/bin/bash
# ============================================================================
# Event Publisher - Polls outbox and publishes to Kafka
# ============================================================================
set -e

DB_URL="${DATABASE_URL:-postgresql://surypus:surypus_secret@localhost:5432/surypus}"
KAFKA_BROKERS="${KAFKA_BROKERS:-redpanda:9092}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"
BATCH_SIZE="${BATCH_SIZE:-100}"

echo "Starting event publisher..."
echo "Database: $DB_URL"
echo "Kafka: $KAFKA_BROKERS"
echo "Poll interval: ${POLL_INTERVAL}s"
echo "Batch size: $BATCH_SIZE"

while true; do
	# Get pending events
	events=$(psql "$DB_URL" -t -A -F',' -c "
        SELECT outbox_id, event_id, aggregate_id, event_type, event_data::text, topic
        FROM outbox_get_pending($BATCH_SIZE, 5)
    ")

	if [ -z "$events" ]; then
		sleep "$POLL_INTERVAL"
		continue
	fi

	# Process each event
	echo "$events" | while IFS=',' read -r outbox_id event_id aggregate_id event_type event_data topic; do
		echo "Publishing event $event_id to topic $topic"

		# Build Kafka message (using kcat or similar)
		# In production, would use proper Kafka client

		# Simulate publishing
		psql "$DB_URL" -c "SELECT outbox_mark_published($outbox_id)"

		echo "Published event $event_id"
	done

	sleep "$POLL_INTERVAL"
done
