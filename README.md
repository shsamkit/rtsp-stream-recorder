# RTSP Streamer

A Docker-based RTSP streaming solution that uses FFmpeg to record multiple camera streams simultaneously.

## Quick Start
```
# Check out the repo and build a docker image
docker build . -t rtsp-streamer-recorder --platform  linux/amd64

# make a data directory for the recordings and logs
mkdir -p /tmp/rtsp-streamer

# Prepare camera urls with credentials and camera IPs; if IPs aren't directly accessible, consider using port forwarding
# Sample URL for hikvision cameras, you may pass mutiple comma-separated camera URLs
RTSP_URLS=rtsp://${CAMERA_IP}:554/ISAPI/Streaming/channels/101

# Sample command for port-forwarding
ssh -L 5544:${CAMERA_IP}:554 $JUMP_SERVER

# Run the streamer (you may skip --add-host arg if not connecting to cameras via port-forwarding)
docker run --add-host=host.docker.internal:host-gateway \
--name rtsp-streamer --rm \
-v /tmp/rtsp-streamer:/app/data \
rtsp-streamer-recorder \
-l info \
-o /app/data \
-d 60 \
-c ${RTSP_URLS} \
-s 1

# Wait for the streaming to finish
# Recording and logs should be availbale as follows
ls -la /tmp/rtsp-streamer
├── camera_1_stream1.mp4
└── logs/
    ├── camera_1_stream1.log
```

## Configuration

### Command Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--duration` | `-d` | Recording duration in seconds | 60 |
| `--output-dir` | `-o` | Output directory for recordings and logs | `/app/data` |
| `--cameras` | `-c` | Comma-separated list of camera URLs | - |
| `--cameras-file` | `-f` | Path to YAML file containing camera list | - |
| `--log-level` | `-l` | FFmpeg log level (error, warning, info, debug) | warning |
| `--streams` | `-s` | Number of streams per camera | 1 |
| `--help` | `-h` | Show help message | - |

### Camera Configuration File

Create a YAML file with your camera list:

```yaml
cameras:
  - rtsp://camera1:554/stream1
  - rtsp://camera2:554/stream2
  - rtsp://camera3:554/stream3
```

### Inline Camera List

Specify cameras directly on the command line:

```bash
-c 'rtsp://camera1:554/stream,rtsp://camera2:554/stream,rtsp://camera3:554/stream'
```

## Output Structure
Sample output for 2 cameras with 2 streams
```
output_directory/
├── camera_1_stream1.mp4
├── camera_1_stream2.mp4
├── camera_2_stream1.mp4
├── camera_2_stream2.mp4
└── logs/
    ├── camera_1_stream1.log
    ├── camera_1_stream2.log
    ├── camera_2_stream1.log
    └── camera_2_stream2.log
```

## Development

### Build the Image

```bash
docker build -t rtsp-streamer .
```

### Basic Usage

```bash
# Stream from inline camera list
docker run -v /path/to/output:/app/data rtsp-streamer \
  -d 60 \
  -o /app/data \
  -c 'rtsp://camera1:554/stream,rtsp://camera2:554/stream'

# Stream from configuration file
docker run -v /path/to/output:/app/data -v /path/to/config:/app/config.yaml rtsp-streamer \
  -d 120 \
  -o /app/data \
  -f /app/config.yaml

# Multiple streams per camera
docker run -v /path/to/output:/app/data rtsp-streamer \
  -c 'rtsp://camera1:554/stream' \
  -s 3 \
  -d 60 \
  -o /app/data
```

## Output Structure
```
output_directory/
├── camera_1_stream1.mp4
├── camera_1_stream2.mp4
├── camera_2_stream1.mp4
├── camera_2_stream2.mp4
└── logs/
    ├── camera_1_stream1.log
    ├── camera_1_stream2.log
    ├── camera_2_stream1.log
    └── camera_2_stream2.log
```

## Examples

### Record 5-minute clips from 3 cameras

```bash
docker run -v /recordings:/app/data rtsp-streamer \
  -c 'rtsp://192.168.1.100:554/stream,rtsp://192.168.1.101:554/stream,rtsp://192.168.1.102:554/stream' \
  -d 300 \
  -o /app/data
```

### Use configuration file with custom output

```bash
docker run -v /recordings:/app/data -v /config:/app/config.yaml rtsp-streamer \
  -f /app/config.yaml \
  -d 180 \
  -o /app/data \
  -l info
```

### Multiple streams per camera for load testing

```bash
docker run -v /recordings:/app/data rtsp-streamer \
  -c 'rtsp://camera:554/stream' \
  -s 5 \
  -d 600 \
  -o /app/data \
  -l debug
```

### High-quality recording with multiple streams

```bash
docker run -v /recordings:/app/data rtsp-streamer \
  -c 'rtsp://camera1:554/high_quality,rtsp://camera2:554/high_quality' \
  -s 2 \
  -d 600 \
  -o /app/data
```

## Use Cases

### Load Testing
Use multiple streams per camera to test camera capacity and network performance:
```bash
docker run rtsp-streamer -c 'rtsp://camera:554/stream' -s 10 -d 300
```

### Redundancy
Create backup streams in case one fails:
```bash
docker run rtsp-streamer -c 'rtsp://camera:554/stream' -s 3 -d 3600
```

### Different Configurations
Future enhancement: Different ffmpeg parameters per stream for various quality levels.

## Requirements

- Docker
- RTSP camera streams accessible from the container directly or via port-forwarding
- Sufficient disk space for recordings
- Adequate network bandwidth for multiple concurrent streams

## Notes

- The container automatically replaces `localhost` and `127.0.0.1` with `host.docker.internal` for Docker Desktop compatibility
- All streams run concurrently and complete simultaneously
- Logs are written to individual files for each camera stream
- The output directory must exist before running the container
- Multiple streams from the same camera can help test camera capacity and provide redundancy
- Each stream gets a unique filename to avoid conflicts

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure the output directory has proper write permissions
2. **Camera connection failed**: Verify RTSP URLs and network connectivity
3. **Container exits immediately**: Check that either `--cameras` or `--cameras-file` is specified
4. **Multiple stream failures**: Some cameras may not support multiple concurrent connections

### Debug Mode

Use `-l debug` to get detailed FFmpeg output for troubleshooting connection issues.

### Network Considerations

When using multiple streams per camera:
- Ensure your network can handle the increased bandwidth
- Some cameras have limits on concurrent connections
- Monitor system resources (CPU, memory, disk I/O)

