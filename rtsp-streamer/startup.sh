#!/bin/bash

# RTSP Streamer startup script
# This script handles RTSP streaming operations using ffmpeg

set -e

# Default values
DURATION=60
OUTPUT_DIR="/app/data"
CAMERAS=""
CAMERAS_FILE=""
LOG_LEVEL="warning"
STREAMS_PER_CAMERA=1

# Function to display usage
show_usage() {
    echo "RTSP Streamer - FFmpeg wrapper for RTSP operations"
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --duration SECONDS    Duration to record each stream in seconds (default: 60)"
    echo "  -o, --output-dir DIR      Output directory for recorded files and logs (default: /app/data)"
    echo "  -c, --cameras LIST        Comma-separated list of camera URLs (e.g., 'rtsp://cam1,rtsp://cam2')"
    echo "  -f, --cameras-file FILE   Path to file containing camera URLs (one per line)"
    echo "  -l, --log-level LEVEL     Log level (default: warning)"
    echo "  -s, --streams NUMBER      Number of streams per camera (default: 1)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Note: Either --cameras or --cameras-file must be specified, but not both"
    echo ""
    echo "Examples:"
    echo "  $0 -d 120 -o /data -c 'rtsp://cam1:554/stream,rtsp://cam2:554/stream' -s 3"
    echo "  $0 --duration 300 --output-dir /recordings --cameras-file /config/cameras.txt --streams 2"
}

# Function to stream from a single camera
stream_camera() {
    local camera_url="$1"
    local camera_name="$2"
    local stream_number="$3"
    local duration="$4"
    local output_dir="$5"
    local log_level="$6"

    # Create unique filename for this stream
    local filename="${camera_name}_stream${stream_number}"

    echo "Starting stream $stream_number for $camera_name from $camera_url"

    # Start ffmpeg in background
    nohup ffmpeg -i "$camera_url" -t "$duration" -c copy -loglevel "$log_level" -y "${output_dir}/${filename}.mp4" > "${output_dir}/logs/${filename}.log" 2>&1 &
    local pid=$!

    echo "Process ID for $filename: $pid"

    # Wait for this specific process to complete
    echo "Waiting for $filename (PID: $pid)..."

    if wait $pid; then
        echo "✅ $filename completed successfully"
        return 0
    else
        local exit_code=$?
        echo "❌ $filename failed with exit code $exit_code, wait for other streams to complete"
        return $exit_code
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -c|--cameras)
            CAMERAS="$2"
            shift 2
            ;;
        -f|--cameras-file)
            CAMERAS_FILE="$2"
            shift 2
            ;;
        -l|--log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        -s|--streams)
            STREAMS_PER_CAMERA="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check that exactly one of cameras or cameras-file is specified
if [ -z "$CAMERAS" ] && [ -z "$CAMERAS_FILE" ]; then
    echo "Error: Either --cameras or --cameras-file must be specified"
    show_usage
    exit 1
fi

if [ -n "$CAMERAS" ] && [ -n "$CAMERAS_FILE" ]; then
    echo "Error: Cannot specify both --cameras and --cameras-file"
    show_usage
    exit 1
fi

# Validate streams per camera
if ! [[ "$STREAMS_PER_CAMERA" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Streams per camera must be a positive integer"
    exit 1
fi

# Get camera list
if [ -n "$CAMERAS" ]; then
    # Convert comma-separated list to newline-separated
    CAMERA_LIST=$(echo "$CAMERAS" | tr ',' '\n')
else
    # Check if cameras file exists
    if [ ! -f "$CAMERAS_FILE" ]; then
        echo "Error: Cameras file not found at $CAMERAS_FILE"
        exit 1
    fi
    CAMERA_LIST=$(yq '.cameras[]' "$CAMERAS_FILE")
fi

# Fail if output directory does not exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory $OUTPUT_DIR does not exist"
    exit 1
fi

# Execute ffmpeg with provided arguments
echo "Starting RTSP streamer with ffmpeg..."
echo "Duration: ${DURATION}s"
echo "Output directory: $OUTPUT_DIR"
echo "Streams per camera: $STREAMS_PER_CAMERA"
echo ""

mkdir -p "$OUTPUT_DIR/logs"

echo "Starting streams, logs will be written to ${OUTPUT_DIR}/logs"

# Arrays to store results
declare -a CAMERA_NAMES
declare -a EXIT_CODES

counter=1
for CAMERA in $CAMERA_LIST; do
    # Skip empty lines
    if [ -z "$CAMERA" ]; then
        continue
    fi

    CAMERA=$(echo "$CAMERA" | sed -e 's/localhost/host.docker.internal/g' -e 's/127\.0\.0\.1/host.docker.internal/g')
    CAMERA_NAME="camera_${counter}"

    # Store camera name
    CAMERA_NAMES+=("$CAMERA_NAME")

    # Start multiple streams for this camera
    for stream_num in $(seq 1 $STREAMS_PER_CAMERA); do
        # Run stream_camera function asynchronously
        stream_camera "$CAMERA" "$CAMERA_NAME" "$stream_num" "$DURATION" "$OUTPUT_DIR" "$LOG_LEVEL" &
    done

    counter=$((counter + 1))
done

# Wait for all background functions to complete
echo ""
echo "Waiting for all streams to complete..."

# Wait for all background processes
wait

echo ""
echo "All streams have completed, check logs for details for any failed streams"
echo "Log files are located in: ${OUTPUT_DIR}/logs/"
exit 0
