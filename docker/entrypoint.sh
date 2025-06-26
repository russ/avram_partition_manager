#!/usr/bin/env bash

cd /app

echo "🚀 Initializing Lucky E2E test app..."
lucky init.custom e2e-test --api --no-auth

echo "🧩 Injecting avram_partition_manager into shard.yml if missing..."
grep -q '^  avram_partition_manager:' shard.yml || awk '
  /^development_dependencies:/ {
    print "  avram_partition_manager:\n    path: ../"
  }
  { print }
' e2e-test/shard.yml > tmp.yml && mv tmp.yml e2e-test/shard.yml

echo "➕ Ensuring require line is in shards.cr..."
grep -q '^require "avram_partition_manager"' e2e-test/src/shards.cr || echo 'require "avram_partition_manager"' >> e2e-test/src/shards.cr

echo "📁 Copying support files into the E2E project..."
cp spec/support/db/migrations/20250619220647_create_events.cr e2e-test/db/migrations/
cp spec/support/shard.override.yml e2e-test/
cp spec/support/src/models/event.cr e2e-test/src/models/
cp spec/support/src/queries/event_query.cr e2e-test/src/queries/
mkdir -p e2e-test/spec/models && cp spec/support/spec/models/event_spec.cr e2e-test/spec/models/
mkdir -p e2e-test/tasks/db && cp spec/support/tasks/db/update_partitions.cr e2e-test/tasks/db/

echo "📦 Installing shards..."
cd e2e-test
shards install

echo "🛠️ Running migrations and updating partitions..."
lucky db.migrate
lucky db.update_partitions

echo "🧪 Running specs..."
crystal spec

echo "✅ Done!"
