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
CREATE_VERSION="0.7.0"             # Create NeoForge version
GEYSER_VERSION="2.2.3"             # Geyser-NeoForge
FLOODGATE_VERSION="2.2.4"          # Floodgate-NeoForge
JAVA_MODS_DIR="mods/java"          # For Java mods (.jar)
BEDROCK_MODS_DIR="mods/bedrock"    # For Bedrock addons (.mcaddon)

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
  apt-get install -y curl wget unzip jq docker.io docker-compose
  systemctl enable --now docker
  usermod -aG docker "$CURRENT_USER"
}

# Create organized directory structure
setup_directories() {
  echo -e "${YELLOW}Creating directory structure...${NC}"
  mkdir -p {config,world,resource_packs,behavior_packs,scripts}
  mkdir -p "$JAVA_MODS_DIR" "$BEDROCK_MODS_DIR"/{behavior_packs,resource_packs}
  chown -R "$CURRENT_USER:$CURRENT_USER" .
}

# Install NeoForge server
download_minecraft_server() {
  echo -e "${YELLOW}Downloading NeoForge for Minecraft $MC_VERSION...${NC}"
  if ! download_file \
    "https://maven.neoforged.net/releases/net/neoforged/neoforge/21.1.186/neoforge-21.1.186-installer.jar" \
    "neoforge-21.1.186-installer.jar"; then
    exit 1
  fi

  echo -e "${YELLOW}Installing server...${NC}"
  sudo java -jar neoforge-21.1.186-installer.jar --installServer || {
    echo -e "${RED}NeoForge installation failed!${NC}"
    exit 1
  }

  if [ ! -f "$SERVER_JAR" ]; then
    echo -e "${RED}Server jar not found after installation!${NC}"
    ls -la
    exit 1
  fi
  rm -f neoforge-21.1.186-installer.jar neoforge-21.1.186-installer.jar.log
}

# Download and organize Java mods
download_java_mods() {
  echo -e "${BLUE}=== Downloading Java Mods ===${NC}"
  
  # Create NeoForge
  download_file \
    "https://www.curseforge.com/api/v1/mods/328085/files/6641610/download" \
    "$JAVA_MODS_DIR/create-neoforge.jar" || exit 1
  #JEI
  download_file \
    "https://cdn.modrinth.com/data/u6dRKJwZ/versions/TxS03dKM/jei-1.21.1-neoforge-19.21.0.247.jar" \
    "$JAVA_MODS_DIR/jei-1.21.1-neoforge-19.21.0.247.jar" || exit 1
  # Geyser-NeoForge
  download_file \
    "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/neoforge" \
    "$JAVA_MODS_DIR/geyser-neoforge.jar" || exit 1

  # Floodgate-NeoForge
  download_file \
    "https://cdn.modrinth.com/data/bWrNNfkb/versions/ByP7SHZE/Floodgate-Neoforge-2.2.4-b36.jar" \
    "$JAVA_MODS_DIR/floodgate-neoforge.jar" || exit 1
  # Worldedit
  download_file \
    "https://cdn.modrinth.com/data/1u6JkXh5/versions/WTAFvuRx/worldedit-mod-7.3.8.jar" \
    "$JAVA_MODS_DIR/Worldedit-neoforge.jar" 
}

# Process Bedrock .mcaddon files
process_mcaddons() {
  echo -e "${BLUE}=== Processing Bedrock Addons ===${NC}"
  
  if ls "$BEDROCK_MODS_DIR"/*.mcaddon 1> /dev/null 2>&1; then
    for mcaddon in "$BEDROCK_MODS_DIR"/*.mcaddon; do
      echo -e "${YELLOW}Extracting ${mcaddon}...${NC}"
      temp_dir=$(mktemp -d)
      unzip -q "$mcaddon" -d "$temp_dir"
      
      # Move behavior packs
      if [ -d "$temp_dir/behavior_packs" ]; then
        cp -r "$temp_dir/behavior_packs/"* "$BEDROCK_MODS_DIR/behavior_packs/"
      fi
      
      # Move resource packs
      if [ -d "$temp_dir/resource_packs" ]; then
        cp -r "$temp_dir/resource_packs/"* "$BEDROCK_MODS_DIR/resource_packs/"
      fi
      
      # Cleanup
      rm -rf "$temp_dir"
      rm "$mcaddon"
    done
    
    # Create symlinks for server detection
    ln -sf "../$BEDROCK_MODS_DIR/behavior_packs" "behavior_packs/bedrock"
    ln -sf "../$BEDROCK_MODS_DIR/resource_packs" "resource_packs/bedrock"
    
    echo -e "${GREEN}Bedrock addons processed into $BEDROCK_MODS_DIR${NC}"
  else
    echo -e "${YELLOW}No .mcaddon files found in $BEDROCK_MODS_DIR${NC}"
  fi
}

# Create Docker configuration
create_docker_config() {
  echo -e "${YELLOW}Creating Docker configuration...${NC}"
  
  cat > Dockerfile << EOF
FROM eclipse-temurin:17-jre-jammy

# Arguments
ARG MC_VERSION=${MC_VERSION}
ARG NEOFORGE_VERSION=${NEOFORGE_VERSION}
ARG MIN_RAM=4G
ARG MAX_RAM=8G

# Install dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    unzip \\
    && rm -rf /var/lib/apt/lists/*

# Copy server files
COPY . /server
WORKDIR /server

# Expose ports
EXPOSE 25565/tcp  # Java Edition
EXPOSE 19132/udp  # Bedrock Edition
EXPOSE 24454/udp  # Voice Chat

# Start command
CMD ["sh", "-c", "java -Xms\${MIN_RAM} -Xmx\${MAX_RAM} -jar ${SERVER_JAR} nogui"]
EOF

  cat > docker-compose.yml << EOF
version: '3.8'

services:
  minecraft:
    build:
      context: .
      args:
        MC_VERSION: ${MC_VERSION}
        NEOFORGE_VERSION: ${NEOFORGE_VERSION}
    image: ${CURRENT_USER}/minecraft-neoforge:${MC_VERSION}
    container_name: ${CURRENT_USER}-minecraft
    restart: unless-stopped
    environment:
      - MIN_RAM=4G
      - MAX_RAM=8G
      - EULA=TRUE
    volumes:
      - ./world:/server/world
      - ./config:/server/config
      - ./mods:/server/mods
      - ./resource_packs:/server/resource_packs
      - ./behavior_packs:/server/behavior_packs
    ports:
      - "25565:25565/tcp"
      - "19132:19132/udp"
      - "24454:24454/udp"
    tty: true
    stdin_open: true
EOF
}

# Create startup script
create_startup_script() {
  cat > start.sh << 'EOF'
#!/bin/bash

# Start message
echo "Starting NeoForge server with ${MIN_RAM}/${MAX_RAM} RAM..."

# Launch server
exec java -Xms${MIN_RAM} -Xmx${MAX_RAM} -jar "${SERVER_JAR}" nogui
EOF
  chmod +x start.sh
}

# Main execution
echo -e "${BLUE}=== Minecraft 1.20.6 NeoForge Server Setup ===${NC}"

# Run setup steps
install_dependencies
setup_directories
download_minecraft_server
download_java_mods
process_mcaddons
create_docker_config
create_startup_script

# Fix permissions
chown -R "$CURRENT_USER:$CURRENT_USER" .

# Completion message
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo -e "Server Components:"
echo -e "- NeoForge ${NEOFORGE_VERSION} for Minecraft ${MC_VERSION}"
echo -e "- Create mod ${CREATE_VERSION}"
echo -e "- Geyser-NeoForge ${GEYSER_VERSION}"
echo -e "- Floodgate-NeoForge ${FLOODGATE_VERSION}"
echo -e ""
echo -e "${YELLOW}Mod Directories:${NC}"
echo -e "- Java mods: ./${JAVA_MODS_DIR}/"
echo -e "- Bedrock addons: ./${BEDROCK_MODS_DIR}/"
echo -e ""
echo -e "${YELLOW}To Start:${NC}"
echo -e "1. docker-compose build"
echo -e "2. docker-compose up -d"
echo -e ""
echo -e "${YELLOW}Connection Info:${NC}"
echo -e "Java players: your-ip:25565"
echo -e "Bedrock players: your-ip:19132"