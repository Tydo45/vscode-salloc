#!/bin/bash

REMOTE_SERVER="dh-mgmt3.hpc.msoe.edu"
SESSION_NAME="vscode-salloc"
WIN_USER=$(wslpath "$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')")
WIN_HOME=$(wslpath "$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')")
ID_FILE_PATH="C:\\Users\\$WIN_USER\\.ssh\\id_ed25519"
SSH_CONFIG="$WIN_HOME/.ssh/config"
MARKER_FILE="$HOME/.vscode_salloc_initialized"

setup_ssh_config() {
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
    [ -z "$time_arg" ] && echo "3600" && return
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
    NODE=$(ssh -q $REMOTE_SERVER "
        tmux new-session -d -s $SESSION_NAME \"salloc $@\";
        sleep 5;
        tmux capture-pane -p -t $SESSION_NAME" | 
        grep -oP 'Nodes\s*=?\s*\K(dh-node[0-9]+|dh-dgx[0-9]+-[0-9]+|dh-dgxh100-[0-9]+)')
    [[ "$NODE" =~ ^dh-(node[0-9]+|dgx[0-9]+-[0-9]+|dgxh100-[0-9]+)$ ]] && echo "$NODE" || echo ""
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

if [[ "$@" =~ "--setup" || ! -f "$MARKER_FILE" ]]; then
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
# Check if SSH key has been copied and notify user if it hasn't
if [ "$SSH_KEY_COPIED" != "true" ]; then
    echo "WARNING: SSH key has not been copied to the remote server."
    echo "For passwordless login, please run the script with --setup flag:"
    echo "    $0 --setup"
fi

TIME_IN_SECONDS=$(parse_time "$@")
NODE=$(allocate_node "$@")

if [ -n "$NODE" ]; then
    echo "Allocated Node: $NODE"
    code --new-window --remote "ssh-remote+$NODE" 2>/dev/null
    echo "Press 'x' to Exit Allocation and Cleanup"
    if [ -t 0 ]; then
        SAVED_STTY="`stty --save`"
        stty -echo -icanon -icrnl time 0 min 0
    fi
    keypress=''
    
    while [ "x$keypress" = "x" ] && [ $TIME_IN_SECONDS -gt 0 ]; do
        sleep 1
        ((TIME_IN_SECONDS--))
        ((ELAPSED++))
        PERCENT=$(( (ELAPSED * 100) / (ELAPSED + TIME_IN_SECONDS) ))
        FILLED=$((PERCENT / 5))
        BAR=$(printf "%0.s█" $(seq 1 $FILLED))$(printf "%0.s-" $(seq 1 $((20 - FILLED))))
        printf "\rTime remaining: $(date -u -d @$TIME_IN_SECONDS +%H:%M:%S) [$BAR] $PERCENT%% "
        keypress="`cat -v`"
    done
    if [ -t 0 ]; then stty "$SAVED_STTY"; fi
    echo -e "\nAllocation exited and cleaned up. Goodbye!"
else
    echo "Error: Could not retrieve or validate allocated node."
    echo "This could be due to a failed ssh connection or unavailable resources."
fi
ssh -q $REMOTE_SERVER "tmux kill-session -t $SESSION_NAME"
