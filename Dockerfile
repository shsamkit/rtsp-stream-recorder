# Use a base image with ffmpeg pre-installed
FROM jrottenberg/ffmpeg:latest

# Set working directory
WORKDIR /app

# Copy the startup script
COPY startup.sh /app/startup.sh

# Install yq and other utilities
RUN apt-get update && apt-get install -y wget vim iputils-ping netcat telnet
RUN wget https://github.com/mikefarah/yq/releases/download/v4.47.1/yq_linux_amd64.tar.gz -O - |\
  tar xz && mv yq_linux_amd64 /usr/local/bin/yq
RUN yq --version

# Make the startup script executable
RUN chmod +x /app/startup.sh

# Set the startup script as the entrypoint
ENTRYPOINT ["/app/startup.sh"]

# Default command (can be overridden)
CMD ["--help"]



