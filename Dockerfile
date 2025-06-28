FROM eclipse-temurin:17-jre-jammy

# Arguments
ARG MC_VERSION=1.21.1
ARG NEOFORGE_VERSION=21.1.186
ARG MIN_RAM=4G
ARG MAX_RAM=8G

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy server files
COPY . /server
WORKDIR /server

# Expose ports
EXPOSE 25565/tcp  # Java Edition
EXPOSE 19132/udp  # Bedrock Edition
EXPOSE 24454/udp  # Voice Chat

# Start command
CMD ["sh", "-c", "java -Xms${MIN_RAM} -Xmx${MAX_RAM} -jar server.jar nogui"]
