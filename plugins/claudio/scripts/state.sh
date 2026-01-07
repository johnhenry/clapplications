#!/bin/bash
# State management helpers for claudio plugin

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
STATE_FILE="$PLUGIN_DIR/state.json"

# Initialize state file if it doesn't exist
init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" << 'EOF'
{
  "version": "2.0.0",
  "providers": {
    "stt": "whisper",
    "tts": "chatterbox-turbo"
  },
  "servers": {},
  "models": {}
}
EOF
    fi
}

# Get current provider for a type (stt or tts)
get_provider() {
    local type="$1"
    init_state
    python3 -c "
import json, sys
try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    print(state.get('providers', {}).get('$type', ''))
except (json.JSONDecodeError, KeyError, FileNotFoundError):
    print('')
    sys.exit(0)
" 2>/dev/null || echo ""
}

# Set provider for a type
set_provider() {
    local type="$1"
    local provider="$2"
    init_state

    # Use atomic write with temp file to avoid corruption
    python3 -c "
import json, sys, os, tempfile
try:
    # Read current state
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)

    # Update state
    if 'providers' not in state:
        state['providers'] = {}
    state['providers']['$type'] = '$provider'

    # Atomic write using temp file + rename
    fd, temp_path = tempfile.mkstemp(dir=os.path.dirname('$STATE_FILE'), prefix='.state-', suffix='.tmp')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(state, f, indent=2)
        os.rename(temp_path, '$STATE_FILE')
    except:
        os.unlink(temp_path) if os.path.exists(temp_path) else None
        raise
except Exception as e:
    print(f'Error updating state: {e}', file=sys.stderr)
    sys.exit(1)
" || { echo "Failed to update state"; return 1; }
}

# Get server info
get_server() {
    local provider="$1"
    init_state
    python3 -c "import json; state=json.load(open('$STATE_FILE')); print(json.dumps(state['servers'].get('$provider', {})))"
}

# Set server info (pid, port, status)
set_server() {
    local provider="$1"
    local pid="$2"
    local port="$3"
    local status="$4"
    init_state
    python3 -c "
import json
with open('$STATE_FILE', 'r') as f:
    state = json.load(f)
state['servers']['$provider'] = {'pid': $pid, 'port': $port, 'status': '$status'}
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
}

# Remove server info
remove_server() {
    local provider="$1"
    init_state
    python3 -c "
import json
with open('$STATE_FILE', 'r') as f:
    state = json.load(f)
if '$provider' in state['servers']:
    del state['servers']['$provider']
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
}

# Get all running servers
get_running_servers() {
    init_state
    python3 -c "
import json
state = json.load(open('$STATE_FILE'))
running = [k for k, v in state.get('servers', {}).items() if v.get('status') == 'running']
print(' '.join(running))
"
}

# Set model info
set_model() {
    local provider="$1"
    local downloaded="$2"
    local size="$3"
    local path="$4"
    init_state
    python3 -c "
import json
with open('$STATE_FILE', 'r') as f:
    state = json.load(f)
state['models']['$provider'] = {'downloaded': $downloaded, 'size': '$size', 'path': '$path'}
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
}

# Check if model is downloaded
has_model() {
    local provider="$1"
    init_state
    python3 -c "import json; state=json.load(open('$STATE_FILE')); print(state.get('models', {}).get('$provider', {}).get('downloaded', False))"
}
