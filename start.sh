#!/bin/bash

# Start message
echo "Starting NeoForge server with ${MIN_RAM}/${MAX_RAM} RAM..."

# Launch server
exec java -Xms${MIN_RAM} -Xmx${MAX_RAM} -jar "${SERVER_JAR}" nogui
