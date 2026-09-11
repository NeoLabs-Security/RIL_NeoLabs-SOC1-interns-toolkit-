#!/bin/bash

# ==============================================================================
# CONFIGURATION - ADJUST THESE ENVIRONMENT VARIABLES AS NEEDED
# ==============================================================================
# Path to your source NDJSON file on your host machine
HOST_SOURCE_LOG="sample-log/authentication/failed-login-chain.ndjson"

# Target file path inside the Wazuh Manager container
CONTAINER_TARGET_LOG="/var/log/failed-login-chain.ndjson"

# Automated detection of the Wazuh Manager Container ID or Name
CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep "wazuh.manager" | head -n 1)

# Fallback check if container name pattern differs
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep "wazuh-manager" | head -n 1)
fi

# ==============================================================================
# PREREQUISITE CHECKS
# ==============================================================================
echo "🚀 Starting Automated Wazuh NDJSON Ingestion Pipeline..."

if [ ! -f "$HOST_SOURCE_LOG" ]; then
    echo "❌ Error: Source file '$HOST_SOURCE_LOG' not found on the host system."
    exit 1
fi

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ Error: Could not find an active running Wazuh Manager Docker container."
    exit 1
fi

echo "📦 Found target container: $CONTAINER_NAME"

# ==============================================================================
# PHASE 1: CONTAINER ENGINE DEPENDENCY PROVISIONING
# ==============================================================================
echo "🛠️ Phase 1: Installing nano text editor dependency..."
docker exec -it "$CONTAINER_NAME" yum install -y nano > /dev/null 2>&1

# ==============================================================================
# PHASE 2: PIPELINE CONFIGURATION PIPING
# ==============================================================================
echo "📝 Phase 2: Applying Wazuh Manager & Filebeat configurations..."

# Inject <localfile> and <global> archive settings into ossec.conf if not already present
docker exec -it "$CONTAINER_NAME" bash -c '
CONF="/var/ossec/etc/ossec.conf"

# Inject Localfile configuration for JSON parsing
if ! grep -q "<location>/var/log/failed-login-chain.ndjson</location>" "$CONF"; then
    sed -i "/<\/ossec_config>/i \  <localfile>\n    <location>/var/log/failed-login-chain.ndjson</location>\n    <log_format>json</log_format>\n  </localfile>" "$CONF"
    echo "    -> Added failed-login-chain.ndjson localfile hook to ossec.conf"
fi

# Update global parameters to preserve unmatched archives
sed -i "s|<logall>no</logall>|<logall>yes</logall>|g" "$CONF"
sed -i "s|<logall_json>no</logall_json>|<logall_json>yes</logall_json>|g" "$CONF"
echo "    -> Set logall and logall_json to yes"
'

# Update filebeat.yml parameters to ship archive logs to the indexer
docker exec -it "$CONTAINER_NAME" bash -c '
FILEBEAT_CONF="/etc/filebeat/filebeat.yml"
if [ -f "$FILEBEAT_CONF" ]; then
    # Locate archives block under wazuh module and flip enabled to true
    sed -i "/module: wazuh/,/archives:/ {s/enabled: false/enabled: true/}" "$FILEBEAT_CONF"
    echo "    -> Configured Filebeat modules to ship active archives"
fi
'

# ==============================================================================
# PHASE 3: FILE REPLICATION AND REPLAY INGESTION
# ==============================================================================
echo "🔄 Phase 3: Copying raw telemetry assets..."

docker exec "$CONTAINER_NAME" bash -c "true > $CONTAINER_TARGET_LOG"
docker cp "$HOST_SOURCE_LOG" "$CONTAINER_NAME":"$CONTAINER_TARGET_LOG"

echo "🔄 Restarting Wazuh Manager container to bind configurations..."
docker restart "$CONTAINER_NAME" > /dev/null
sleep 5

# ==============================================================================
# SUCCESS METRICS VISUALIZER
# ==============================================================================
echo "🏁 Execution Pipeline Complete!"
echo "--------------------------------------------------------"
echo "📊 Next Action Steps in Wazuh Dashboard UI:"
echo " 1. Go to Dashboard Management -> Index Patterns"
echo " 2. Confirm your 'wazuh-archives-*' pattern exists."
echo " 3. Navigate to Discover view."
echo " 4. Select index: 'wazuh-archives-*'"
echo " 5. Adjust Time Picker to Last 24 Hours."
echo " 6. Filter results using the field: 'data.event_type'"
echo "--------------------------------------------------------"

