#!/bin/bash

REMOTE_SERVER="dh-mgmt3.hpc.msoe.edu"
SESSION_NAME="vscode-salloc"
WIN_USER=$(wslpath "$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')")
WIN_HOME=$(wslpath "$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')")
ID_FILE_PATH="C:\\Users\\$WIN_USER\\.ssh\\id_ed25519"
SSH_CONFIG="$WIN_HOME/.ssh/config"
MARKER_FILE="$HOME/.vscode_salloc_initialized"

# Force cleanup of all sessions and allocations
cleanup_force() {
    echo "Cleaning up all sessions..."
    if check_ssh_connection; then
        ssh -q $REMOTE_SERVER "tmux list-sessions 2>/dev/null | grep $SESSION_NAME | cut -d: -f1 | xargs -I{} tmux kill-session -t {}"
        if [ -n "$ROSIE_USER" ]; then
            ssh -q $REMOTE_SERVER "squeue -h -u $ROSIE_USER -o %A | xargs -r scancel"
        fi
        echo "Cleanup complete."
    else
        echo "Could not connect to remote server for cleanup."
    fi
}

# Check SSH connection to remote server
check_ssh_connection() {
    if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_SERVER" exit 2>/dev/null; then
        echo "Error: Cannot connect to $REMOTE_SERVER"
        echo "Please check your network connection and try again."
        CONNECTION_FAILED=true
        return 1
    fi
    return 0
}

# Validate SSH configuration
validate_config() {
    if [ ! -r "$SSH_CONFIG" ] || ! grep -q "Host Rosie" "$SSH_CONFIG"; then
        echo "Error: SSH configuration is invalid or missing."
        echo "Please run --setup again."
        return 1
    fi
    return 0
}

setup_ssh_config() {
    # Validate SSH connection before proceeding
    if ! check_ssh_connection; then
        exit 1
    fi

    # Handle existing config directory
    if [ -d "$SSH_CONFIG" ]; then
        echo "Warning: Found a directory at $SSH_CONFIG"
        local backup_dir="${SSH_CONFIG}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Moving directory to $backup_dir"
        mv "$SSH_CONFIG" "$backup_dir"
    fi

    # Handle symbolic links
    if [ -L "$SSH_CONFIG" ]; then
        echo "Warning: Found symbolic link at $SSH_CONFIG"
        local backup_link="${SSH_CONFIG}.link_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Moving link to $backup_link"
        mv "$SSH_CONFIG" "$backup_link"
    fi

    # Backup existing config file
    if [ -f "$SSH_CONFIG" ]; then
        local backup_file="${SSH_CONFIG}.backup_$(date +%Y%m%d_%H%M%S)"
        echo "Backing up existing config to $backup_file"
        cp "$SSH_CONFIG" "$backup_file"
    fi

    local config_content="
Host Rosie
  HostName $REMOTE_SERVER
  User $ROSIE_USER
  IdentityFile $ID_FILE_PATH

Host dh-node* dh-dgx* dh-dgxh100*
  HostName %h.hpc.msoe.edu
  User $ROSIE_USER
  IdentityFile $ID_FILE_PATH
  ProxyJump Rosie"

    mkdir -p "$WIN_HOME/.ssh"
    # Ensure we can write to the config file
    if ! touch "$SSH_CONFIG" 2>/dev/null; then
        echo "Error: Cannot write to $SSH_CONFIG"
        echo "Please check permissions and try again."
        exit 1
    fi

    echo "$config_content" > "$SSH_CONFIG"
    unix2dos "$SSH_CONFIG" 2>/dev/null
    chmod 600 "$SSH_CONFIG" 2>/dev/null || true
    {
        echo "#!/bin/bash"
        echo "ROSIE_USER='$ROSIE_USER'"
    } > "$MARKER_FILE"

    # Handle SSH key creation during setup
    if [ ! -f "$WIN_HOME/.ssh/id_ed25519" ]; then
        read -p "SSH key does not exist. Create one? (y/n): " CREATE_KEY
        [[ "$CREATE_KEY" =~ ^[Yy] ]] && {
            ssh-keygen -t ed25519 -f "$WIN_HOME/.ssh/id_ed25519"
            mkdir -p ~/.ssh
            cp "$WIN_HOME/.ssh/id_ed25519"{,.pub} ~/.ssh/
            chmod 600 ~/.ssh/id_ed25519
            chmod 644 ~/.ssh/id_ed25519.pub
            echo "SSH key created and copied to WSL."
        }
    fi

    # Handle SSH key copying during setup
    echo "NOTE: SSH key copy is recommended for passwordless login."
    read -p "Copy SSH key to remote server? (y/n): " COPY_KEY
    [[ "$COPY_KEY" =~ ^[Yy] ]] && {
        # Get the content of the public key
        local PUB_KEY=$(cat "$WIN_HOME/.ssh/id_ed25519.pub")
        
        # Check if key already exists on remote server
        if ssh "$ROSIE_USER@$REMOTE_SERVER" "grep -qF '${PUB_KEY}' ~/.ssh/authorized_keys 2>/dev/null"; then
            echo "SSH key already exists on remote server. Skipping copy."
            echo "SSH_KEY_COPIED=true" >> "$MARKER_FILE"
        else
            ssh-copy-id -i "$WIN_HOME/.ssh/id_ed25519.pub" "$ROSIE_USER@$REMOTE_SERVER" && {
                echo "SSH_KEY_COPIED=true" >> "$MARKER_FILE"
                echo "SSH key copied to $REMOTE_SERVER."
            } || echo "Failed to copy SSH key. Check your connection."
        fi
    }
}

parse_time() {
    local time_arg=$(echo "$@" | grep -o '\--time=[0-9:.-]*')
    [ -z "$time_arg" ] && echo "3600" && return 0
    local parts=(${time_arg#--time=})
    if [[ $parts =~ ^([0-9]+)-([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        echo $((${BASH_REMATCH[1]}*86400 + ${BASH_REMATCH[2]}*3600 + ${BASH_REMATCH[3]}*60 + ${BASH_REMATCH[4]}))
    elif [[ $parts =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        echo $((${BASH_REMATCH[1]}*3600 + ${BASH_REMATCH[2]}*60 + ${BASH_REMATCH[3]}))
    else
        echo "3600"
    fi
}

allocate_node() {
    # Validate SSH connection before allocation
    if ! check_ssh_connection; then
        # Connection failed flag is set in check_ssh_connection
        # Just return empty to indicate failure
        return 1
    fi

    # Only attempt to allocate if SSH connection is successful
    NODE=$(ssh -q $REMOTE_SERVER "
        tmux new-session -d -s $SESSION_NAME \"salloc $@\";
        sleep 5;
        tmux capture-pane -p -t $SESSION_NAME" | 
        grep -oP 'Nodes\s*=?\s*\K(dh-node[0-9]+|dh-dgx[0-9]+-[0-9]+|dh-dgxh100-[0-9]+)')
    
    # Strict validation of node name - must be exactly one of the three patterns
    if [[ "$NODE" =~ ^dh-node[0-9]+$ || "$NODE" =~ ^dh-dgx[0-9]+-[0-9]+$ || "$NODE" =~ ^dh-dgxh100-[0-9]+$ ]]; then
        echo "$NODE"
    else
        echo ""
    fi
}

# Enhanced progress display with end time
show_progress() {
    local end_time=$(date -d "@$(($(date +%s) + TIME_IN_SECONDS))" '+%H:%M:%S')
    local remaining="$(date -u -d @$TIME_IN_SECONDS +%H:%M:%S)"
    local filled=$((PERCENT / 5))
    local bar=$(printf "%0.s█" $(seq 1 $filled))$(printf "%0.s-" $(seq 1 $((20 - filled))))
    printf "\rTime remaining: %s [%s] %d%% (Ends at: %s)" "$remaining" "$bar" "$PERCENT" "$end_time"
}

print_info() {
    cat << 'EOF'
VSCode SALLOC Auto Setup Script

This script automates the process of:
1. Setting up SSH configuration for Rosie and compute nodes
2. Managing SSH keys for passwordless login
3. Allocating SLURM resources
4. Launching VS Code remote sessions

Usage:
    ./vscode-salloc-autosetup-v2.sh [OPTIONS] [SALLOC_ARGS]

Options:
    --setup          Run first-time setup or reconfigure
    --info           Display this help message
    --cleanup        Force cleanup of hanging sessions and allocations
    --time=          Specify allocation time (formats: HH:MM:SS or D-HH:MM:SS)
    --partition=     Specify Partition (Supports: Teaching, dgx, dgxh100)
    --gpus=          Specify Number of GPUs for Allocation
    --cpus-per-task= Specify Number of CPUs per task
  These are example arguments, this script can accept any salloc arguments

Examples:
    # First time setup
    ./vscode-salloc-autosetup-v2.sh --setup

    # Basic usage (1-hour allocation)
    ./vscode-salloc-autosetup-v2.sh

    # Specify allocation time
    ./vscode-salloc-autosetup-v2.sh --time=2:00:00

    # Pass additional salloc arguments
    ./vscode-salloc-autosetup-v2.sh --time=1:00:00 --partition=teaching

Notes:
    - The script creates/updates SSH config in ~/.ssh/config
    - SSH keys are stored in ~/.ssh/id_ed25519
    - Press 'x' to exit allocation early
    - The progress bar shows remaining allocation time

For more information about SLURM options, see: man salloc (Run this when connected to ROSIE via SSH)
EOF
}

# Cleanup function to handle all cleanup operations
cleanup_allocation() {
    local exit_code=$?
    local force=$1
    # Static variable to prevent double cleanup
    if [ "${CLEANUP_RUN:-0}" -eq 1 ]; then
        return 0
    fi
    CLEANUP_RUN=1
    
    # Only run cleanup if forced or if we have an active node
    if [ "$force" = "true" ] || [ -n "$NODE" ]; then
        echo -e "\nRunning cleanup..."
        
        # Kill tmux session if it exists
        ssh -q $REMOTE_SERVER "tmux kill-session -t $SESSION_NAME" 2>/dev/null || true
        echo "Allocation cleaned up."
        
        # Restore terminal settings if they were modified
        if [ -n "$SAVED_STTY" ]; then
            stty "$SAVED_STTY" 2>/dev/null || true
        fi
    fi
    
    # Only exit if this was triggered by a trap
    if [ "$force" = "true" ]; then
        exit $exit_code
    fi
}

# Trap various signals
trap 'cleanup_allocation false' EXIT      # Normal exit
trap 'cleanup_allocation true' SIGINT     # Ctrl+C
trap 'cleanup_allocation true' SIGTERM    # Kill command
trap 'cleanup_allocation true' SIGHUP     # Terminal closed

# Main script execution
if [[ "$1" == "--cleanup" ]]; then
    cleanup_force
    exit 0
elif [[ "$@" =~ "--setup" || ! -f "$MARKER_FILE" ]]; then
    read -rp "Enter your Rosie SSH username: " ROSIE_USER
    setup_ssh_config
    echo "Setup complete. SSH config updated at $SSH_CONFIG"
    echo -e "\nTip: Run with --info flag to see usage information:"
    echo "    $0 --info"
    exit 0
elif [[ "$1" == "--info" ]]; then
    print_info
    exit 0
fi

source "$MARKER_FILE"
# Validate configuration before proceeding
if ! validate_config; then
    exit 1
fi

# Check if SSH key has been copied and notify user if it hasn't
if [ "$SSH_KEY_COPIED" != "true" ]; then
    echo "WARNING: SSH key has not been copied to the remote server."
    echo "For passwordless login, please run the script with --setup flag:"
    echo "    $0 --setup"
fi

# Initialize connection failure flag
CONNECTION_FAILED=false

TIME_IN_SECONDS=$(parse_time "$@")
# Capture the allocated node and handle errors
NODE=$(allocate_node "$@" 2>/dev/null)

# Extra validation to ensure NODE is exactly a valid node name and nothing else
if [[ ! "$NODE" =~ ^dh-node[0-9]+$ && ! "$NODE" =~ ^dh-dgx[0-9]+-[0-9]+$ && ! "$NODE" =~ ^dh-dgxh100-[0-9]+$ ]]; then
    NODE=""
fi

# Only proceed if we have a valid node AND no connection failure occurred
if [ -n "$NODE" ] && [ "$CONNECTION_FAILED" = "false" ]; then
    echo "Allocated Node: $NODE"
    code --new-window --remote "ssh-remote+$NODE" 2>/dev/null
    echo "Press 'x' to Exit Allocation and Cleanup"
    if [ -t 0 ]; then
        SAVED_STTY="`stty --save`"
        stty -echo -icanon -icrnl time 0 min 0
    fi
    keypress=''
    ELAPSED=0
    
    while [ "x$keypress" = "x" ] && [ $TIME_IN_SECONDS -gt 0 ]; do
        sleep 1
        ((TIME_IN_SECONDS--))
        ((ELAPSED++))
        PERCENT=$(( (ELAPSED * 100) / (ELAPSED + TIME_IN_SECONDS) ))
        show_progress
        keypress="`cat -v`"
    done
    cleanup_allocation true
else
    if [ "$CONNECTION_FAILED" = "true" ]; then
        echo "Failed to allocate a node due to connection failure."
        echo "Please check your network connection and try again."
    else
        echo "Failed to allocate a node. No valid node name was returned."
        echo "This may be due to resource unavailability or SLURM configuration."
    fi
    cleanup_allocation true
    exit 1
fi
