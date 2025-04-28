#!/bin/bash
# set -x # Uncomment for extreme debugging (prints every command)

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
    echo "  -d: Enable debug output (shows commands being run and exit codes)"
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

# WARNING: Avoid hardcoding credentials. Use environment variables.

# --- Configuration via Environment Variables ---
# Required: CHECK_GPU_USER, CHECK_GPU_PASS
# Optional: CHECK_GPU_PREFIX (default: bio), CHECK_GPU_START (default: 01),
#           CHECK_GPU_END (default: 24), CHECK_GPU_ADDRESS (default: studcs.uni-sb.de)

# Check for required environment variables
if [ -z "$CHECK_GPU_USER" ]; then
    echo "Error: Environment variable CHECK_GPU_USER is not set." >&2
    exit 1
fi
if [ -z "$CHECK_GPU_PASS" ]; then
    echo "Error: Environment variable CHECK_GPU_PASS is not set." >&2
    echo "Tip: Create a .env file (from .env.example) and run 'source .env'" >&2
    exit 1
fi

# Read configuration from environment variables or use defaults
prefix=${CHECK_GPU_PREFIX:-bio}
start=${CHECK_GPU_START:-01}
end=${CHECK_GPU_END:-24}
address=${CHECK_GPU_ADDRESS:-studcs.uni-sb.de}
SSH_USER="$CHECK_GPU_USER"
SSH_PASS="$CHECK_GPU_PASS"

# Output file
output_file="gpu_detailed_status.txt"

# Clear the output file
> "$output_file"

echo "Checking detailed GPU and driver status on servers ${prefix}${start}-${prefix}${end}.${address}"
if [ "$debug_mode" = true ]; then
    echo "Debug mode enabled."
    echo "Using User: $SSH_USER"
fi

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is not installed. Please install it (e.g., 'sudo apt install sshpass' or 'brew install sshpass')." >&2
    exit 1
fi

# Loop through the specified range
for i in $(seq -w $start $end); do
    server="$prefix$i.$address"
    echo "----------------------------------------"
    echo "Checking $server... "

    # Define common SSH options
    SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
    # IMPORTANT: Avoid printing the command with the password!
    # Instead, we build the command string without the password part for logging
    SSH_CMD_BASE="ssh $SSH_OPTIONS ${SSH_USER}@${server}"
    SSHPASS_CMD_BASE="sshpass -p \"***PASSWORD***\" $SSH_CMD_BASE"

    # Initialize status variables
    conn_status=""
    hw_status="Unknown"
    driver_status="Unknown"
    combined_status=""

    # 1. Check hardware presence with lspci
    lspci_cmd="$SSH_CMD_BASE \"lspci | grep -i nvidia\""
    if [ "$debug_mode" = true ]; then echo "DEBUG: Running command: $SSHPASS_CMD_BASE \"lspci | grep -i nvidia\"" ; fi
    lspci_output=$(sshpass -p "$SSH_PASS" $SSH_CMD_BASE "lspci | grep -i nvidia" 2>&1)
    lspci_exit_code=$?
    if [ "$debug_mode" = true ]; then echo "DEBUG: lspci exit code: $lspci_exit_code" ; fi

    # 2. Check driver status with nvidia-smi (only if lspci didn't fail due to connection)
    # Using exit code 255 as a primary indicator of SSH connection failure
    is_connection_error=false
    if [ $lspci_exit_code -eq 255 ] || [[ "$lspci_output" == *"Connection timed out"* ]] || [[ "$lspci_output" == *"Operation timed out"* ]] || [[ "$lspci_output" == *"Connection refused"* ]] || [[ "$lspci_output" == *"No route to host"* ]] || [[ "$lspci_output" == *"Permission denied"* ]]; then
        is_connection_error=true
    fi

    if ! $is_connection_error; then
        conn_status="Connected"

        if [ $lspci_exit_code -eq 0 ]; then
            hw_status="NVIDIA GPU Detected"
            # Now check nvidia-smi
            nvidia_smi_cmd="$SSH_CMD_BASE \"nvidia-smi\""
            if [ "$debug_mode" = true ]; then echo "DEBUG: Running command: $SSHPASS_CMD_BASE \"nvidia-smi\"" ; fi
            nvidia_smi_output=$(sshpass -p "$SSH_PASS" $SSH_CMD_BASE "nvidia-smi" 2>&1)
            nvidia_smi_exit_code=$?
            if [ "$debug_mode" = true ]; then echo "DEBUG: nvidia-smi exit code: $nvidia_smi_exit_code" ; fi

            if [ $nvidia_smi_exit_code -eq 0 ]; then
                driver_status="Driver OK"
                driver_version=$(echo "$nvidia_smi_output" | grep -i "Driver Version" | awk '{print $3}')
                if [ -n "$driver_version" ]; then
                    driver_status="Driver OK (v$driver_version)"
                fi
            elif [[ "$nvidia_smi_output" == *"Failed to initialize NVML: Driver/library version mismatch"* ]]; then
                driver_status="Driver/Library Mismatch"
            elif [[ "$nvidia_smi_output" == *"command not found"* ]]; then
                # Check if lspci found a card - if so, driver not installed, otherwise N/A.
                driver_status="Driver Not Installed"
            else
                driver_status="nvidia-smi Error (Code: $nvidia_smi_exit_code)"
                echo "$server: DEBUG nvidia-smi output - $nvidia_smi_output" >> "$output_file"
            fi
        elif [ $lspci_exit_code -eq 1 ]; then
            # lspci ran successfully but found no NVIDIA device (grep returned 1)
            hw_status="No NVIDIA GPU Detected"
            driver_status="N/A"
        else
             # lspci failed for a reason other than no match (e.g., command not found on remote)
             hw_status="lspci Error (Code: $lspci_exit_code)"
             driver_status="Unknown"
             echo "$server: DEBUG lspci output - $lspci_output" >> "$output_file"
        fi
    else
        # Handle connection errors based on lspci output/exit code
        if [[ "$lspci_output" == *"Connection timed out"* || "$lspci_output" == *"Operation timed out"* ]]; then
            conn_status="Connection Timeout"
        elif [[ "$lspci_output" == *"Connection refused"* || "$lspci_output" == *"No route to host"* ]]; then
            conn_status="Offline/Unreachable"
        elif [[ "$lspci_output" == *"Permission denied"* ]]; then
            conn_status="Authentication Failed"
        elif [ $lspci_exit_code -eq 255 ]; then
             conn_status="SSH Connection Error"
        else
             # Fallback for unexpected lspci exit codes during connection phase
             conn_status="Unknown Connection Error (Code: $lspci_exit_code)"
             echo "$server: DEBUG lspci connection output - $lspci_output" >> "$output_file"
        fi
        hw_status="Unknown"
        driver_status="Unknown"
    fi

    # Combine statuses for final output line
    if [ "$conn_status" == "Connected" ]; then
        combined_status="$hw_status; Driver: $driver_status"
    else
        combined_status="$conn_status"
    fi

    echo "Result: $combined_status"
    echo "$server: $combined_status" >> "$output_file"

done

echo "----------------------------------------"
echo "Detailed GPU status check complete. Results saved to $output_file" 