#!/bin/bash
# set -x # Uncomment for extreme debugging

# --- Auto-load .env file if it exists ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "Loading environment variables from $ENV_FILE"
    # Use set -a to automatically export all variables defined in the .env file
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Info: .env file not found at $ENV_FILE. Relying on pre-exported variables."
fi

# --- Option Parsing ---
debug_mode=false

usage() {
    echo "Usage: $0 [-d] [-h]"
    echo "  -d: Enable debug output (shows ping command and exit codes)"
    echo "  -h: Display this help message"
    exit 1
}

while getopts "dh" opt; do
    case $opt in
        d) debug_mode=true ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    esac
done
shift $((OPTIND-1)) # Remove parsed options

# --- Configuration via Environment Variables ---
# Optional: CHECK_SERVER_PREFIX (default: bio), CHECK_SERVER_START (default: 01),
#           CHECK_SERVER_END (default: 24), CHECK_SERVER_ADDRESS (default: studcs.uni-sb.de)

# Read configuration from environment variables or use defaults
prefix=${CHECK_SERVER_PREFIX:-bio}
start=${CHECK_SERVER_START:-01}
end=${CHECK_SERVER_END:-24}
address=${CHECK_SERVER_ADDRESS:-studcs.uni-sb.de}

# Output file
output_file="server_status.txt"

# Clear the output file
> "$output_file"

echo "Checking server status for ${prefix}${start}-${prefix}${end}.${address}"
if [ "$debug_mode" = true ]; then
    echo "Debug mode enabled."
fi

# Loop through the specified range
for i in $(seq -w $start $end); do
    server="$prefix$i.$address"
    echo "----------------------------------------"
    echo "Checking $server... "

    # Check server status with ping
    ping_cmd="ping -c 1 -W 2 \"$server\"" # Added -W 2 for 2-second timeout
    if [ "$debug_mode" = true ]; then echo "DEBUG: Running command: $ping_cmd" ; fi

    # Execute ping and capture output/exit code
    ping_output=$(ping -c 1 -W 2 "$server" 2>&1) # Capture stderr too
    ping_exit_code=$?

    if [ "$debug_mode" = true ]; then echo "DEBUG: ping exit code: $ping_exit_code" ; fi

    status=""
    if [ $ping_exit_code -eq 0 ]; then
        status="Online"
    else
        status="Offline"
        # Optional: Log ping output on failure if in debug mode
        if [ "$debug_mode" = true ]; then
            echo "DEBUG: ping output on failure: $ping_output"
        fi
    fi

    echo "Result: $status"
    echo "$server: $status" >> "$output_file"

done

echo "----------------------------------------"
echo "Server status check complete. Results saved to $output_file"
