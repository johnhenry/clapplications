#!/bin/bash
# Graceful shutdown helper for claudio servers

# Gracefully stop a process
# Args: $1 = PID, $2 = process name (for logging)
graceful_shutdown() {
    local pid="$1"
    local name="$2"
    local timeout=10

    # Check if process exists
    if ! ps -p "$pid" > /dev/null 2>&1; then
        return 0  # Already stopped
    fi

    # Send SIGTERM
    kill "$pid" 2>/dev/null

    # Wait for up to $timeout seconds
    for i in $(seq 1 $timeout); do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Successfully stopped
        fi
        sleep 1
    done

    # Process didn't stop, send SIGKILL
    echo "⚠️  $name didn't stop gracefully, forcing..."
    kill -9 "$pid" 2>/dev/null
    sleep 1

    # Verify it's dead
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "❌ Failed to stop $name (PID: $pid)"
        return 1
    fi

    return 0
}

# Stop server by port
# Args: $1 = port, $2 = name (for logging)
stop_by_port() {
    local port="$1"
    local name="$2"

    if ! lsof -Pi ":$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port not in use
    fi

    local pid=$(lsof -ti ":$port")
    graceful_shutdown "$pid" "$name"

    # Verify port is released
    if lsof -Pi ":$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "❌ Port $port still in use"
        return 1
    fi

    return 0
}

# Export functions
export -f graceful_shutdown
export -f stop_by_port
