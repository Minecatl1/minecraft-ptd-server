FROM eclipse-temurin:17-jre-jammy

# Arguments
ARG MIN_RAM=4G
ARG MAX_RAM=8G

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create server directory
RUN mkdir -p /server
WORKDIR /server

# Copy server files
COPY . .

# Expose ports
EXPOSE 25565
EXPOSE 19132/udp
EXPOSE 24454/udp

# Start command
CMD ["sh", "-c", "java -Xms${MIN_RAM} -Xmx${MAX_RAM} -jar ${SERVER_JAR} nogui"]