#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MC_VERSION="1.21.1"
NEOFORGE_VERSION="21.1.186"
SERVER_JAR="server.jar"
CREATE_VERSION="0.7.0"
GEYSER_VERSION="2.2.3"
FLOODGATE_VERSION="2.2.4"
JAVA_MODS_DIR="mods/java"
BEDROCK_MODS_DIR="mods/bedrock"

# Check root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# Get current user
CURRENT_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-$(whoami)}")

# Function to download files with progress
download_file() {
  echo -e "${YELLOW}Downloading $1...${NC}"
  if ! wget -q --show-progress -O "$2" "$1"; then
    echo -e "${RED}Failed to download $1${NC}"
    return 1
  fi
  return 0
}

# Install required packages
install_dependencies() {
  echo -e "${YELLOW}Installing dependencies...${NC}"
  apt-get update
  apt-get install -y curl wget unzip jq docker.io docker-compose libxi6 libgl1-mesa-glx
  services docker start
  usermod -aG docker "$CURRENT_USER"
}

# Create organized directory structure
setup_directories() {
  echo -e "${YELLOW}Creating directory structure...${NC}"
  mkdir -p {config,world,resource_packs,behavior_packs,scripts,logs,backups}
  mkdir -p "$JAVA_MODS_DIR" "$BEDROCK_MODS_DIR"/{behavior_packs,resource_packs}
  chown -R "$CURRENT_USER:$CURRENT_USER" .
}

# Install NeoForge server
download_minecraft_server() {
  echo -e "${YELLOW}Downloading NeoForge...${NC}"
  if ! download_file \
    "https://maven.neoforged.net/releases/net/neoforged/neoforge/$NEOFORGE_VERSION/neoforge-$NEOFORGE_VERSION-installer.jar" \
    "neoforge-$NEOFORGE_VERSION-installer.jar"; then
    exit 1
  fi

  echo -e "${YELLOW}Installing server...${NC}"
  java -jar "neoforge-$NEOFORGE_VERSION-installer.jar" --installServer || {
    echo -e "${RED}NeoForge installation failed!${NC}"
    exit 1
  }

  [ ! -f "$SERVER_JAR" ] && { echo -e "${RED}Server jar missing!${NC}"; exit 1; }
  rm -f "neoforge-$NEOFORGE_VERSION-installer.jar"*
}

# Download Java mods
download_java_mods() {
  echo -e "${BLUE}=== Downloading Java Mods ===${NC}"
  
  declare -A MOD_URLS=(
    ["create-neoforge.jar"]="https://www.curseforge.com/api/v1/mods/328085/files/6641610/download"
    ["jei-neoforge.jar"]="https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar"
    ["geyser-neoforge.jar"]="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge"
    ["floodgate-neoforge.jar"]="https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar"
    ["Worldedit-neoforge.jar"]="https://cdn.modrinth.com/data/1u6JkXh5/versions/WTAFvuRx/worldedit-mod-7.3.8.jar"
    ["Pixelmon-neoforge.jar"]="https://www.curseforge.com/api/v1/mods/389487/files/6701628/download"
    ["modernfix.jar"]="https://www.curseforge.com/api/v1/mods/790626/files/6609557/download"
    ["Voicechat-neoforge.jar"]="https://cdn.modrinth.com/data/9eGKb6K1/versions/DtuPswKw/voicechat-neoforge-1.21.6-2.5.32.jar" # NeoForge compatible version
    ["ftn-converter.jar"]="https://cdn.modrinth.com/data/u58R1TMW/versions/KrmWHpgS/connector-2.0.0-beta.8%2B1.21.1-full.jar"
    ["forged-fabric-api.jar"]="https://github.com/Sinytra/ForgifiedFabricAPI/releases/download/0.115.6%2B2.1.1%2B1.21.1/forgified-fabric-api-0.115.6+2.1.1+1.21.1.jar"
    ["connecter-extras.jar"]="https://cdn.modrinth.com/data/FYpiwiBR/versions/dgLCqZyo/ConnectorExtras-1.12.1%2B1.21.1.jar"
    ["chest-cavity.jar"]="https://cdn.modrinth.com/data/eo1wLeXR/versions/rtvJdDF9/chestcavity-2.17.1.jar"
    ["cloth-config.jar"]="https://cdn.modrinth.com/data/9s6osm5g/versions/izKINKFg/cloth-config-15.0.140-neoforge.jar"
  )

  for mod in "${!MOD_URLS[@]}"; do
    download_file "${MOD_URLS[$mod]}" "$JAVA_MODS_DIR/$mod" || exit 1
  done
}

# Process Bedrock addons
process_mcaddons() {
  echo -e "${BLUE}=== Processing Bedrock Addons ===${NC}"
  find "$BEDROCK_MODS_DIR" -name "*.mcaddon" -exec sh -c '
    temp=$(mktemp -d)
    unzip -q "$1" -d "$temp"
    [ -d "$temp/behavior_packs" ] && cp -r "$temp/behavior_packs/"* "$2/behavior_packs/"
    [ -d "$temp/resource_packs" ] && cp -r "$temp/resource_packs/"* "$2/resource_packs/"
    rm -rf "$temp" "$1"
  ' _ {} "$BEDROCK_MODS_DIR" \;
  
  ln -sf "../$BEDROCK_MODS_DIR/behavior_packs" "behavior_packs/bedrock"
  ln -sf "../$BEDROCK_MODS_DIR/resource_packs" "resource_packs/bedrock"
}

# Docker Configuration
create_docker_config() {
  echo -e "${YELLOW}Creating Docker configuration...${NC}"
  
  cat > Dockerfile <<EOF
FROM eclipse-temurin:17-jre-jammy

# Install dependencies
RUN apt-get update && apt-get install -y \
    libxi6 libgl1-mesa-glx && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /server
COPY . .

# Health check
HEALTHCHECK --interval=30s --timeout=5s \\
    CMD netstat -tuln | grep -q 25565 || exit 1

EXPOSE 25565/tcp 19132/udp 24454/udp

CMD ["sh", "-c", "java -Xms\${MIN_RAM:-4G} -Xmx\${MAX_RAM:-8G} \\
-XX:+UseG1GC -XX:+UnlockExperimentalVMOptions \\
-XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled \\
-jar ${SERVER_JAR} nogui"]
EOF

  cat > docker-compose.yml <<EOF
version: '3.8'

services:
  minecraft:
    build: .
    image: minecraft-neoforge-pixelmon:${MC_VERSION}
    container_name: mc-neoforge
    restart: unless-stopped
    environment:
      - MIN_RAM=6G
      - MAX_RAM=10G
      - EULA=TRUE
    volumes:
      - ./world:/server/world
      - ./config:/server/config
      - ./mods:/server/mods
      - ./resource_packs:/server/resource_packs
      - ./behavior_packs:/server/behavior_packs
      - ./logs:/server/logs
      - ./backups:/server/backups
    ports:
      - "25565:25565/tcp"
      - "19132:19132/udp"
      - "24454:24454/udp"
    ulimits:
      memlock: -1
      nofile: 65535
    deploy:
      resources:
        limits:
          memory: 12G

volumes:
  minecraft_data:
    driver: local
EOF
}

# Main execution
echo -e "${BLUE}=== Minecraft ${MC_VERSION} NeoForge Server Setup ===${NC}"
install_dependencies
setup_directories
download_minecraft_server
download_java_mods
process_mcaddons
create_docker_config

# Fix permissions
chown -R "$CURRENT_USER:$CURRENT_USER" .

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo -e "Start with: ${YELLOW}docker-compose up -d${NC}"
echo -e "Connect at:"
echo -e "- Java:    <your-ip>:25565"
echo -e "- Bedrock: <your-ip>:19132"
echo -e "- Voice:   <your-ip>:24454 (if enabled)"
