#!/bin/bash

REMOTE_SERVER="dh-mgmt3.hpc.msoe.edu"  # The hostname or IP of your remote machine
SESSION_NAME="vscode-salloc"
COMMAND_TO_RUN="salloc $@"

WIN_USER=$(wslpath "$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')")  # Get Windows username
ID_FILE_PATH="C:\\Users\\$WIN_USER\\.ssh\\id_ed25519"  # Windows-style path for the identity file

WIN_HOME=$(wslpath "$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')")

SSH_CONFIG="$WIN_HOME/.ssh/config"

MARKER_FILE="$HOME/.vscode_salloc_initialized"

# Check if the script is running for the first time or '--setup' flag is passed
if [[ "$@" =~ "--setup" || ! -f "$MARKER_FILE" ]]; then
    echo "Running first-time setup..."

    # Prompt the user for their Rosie SSH username
    read -rp "Enter your Rosie SSH username: " ROSIE_USER

    # Ensure the .ssh directory exists in Windows
    mkdir -p "$WIN_HOME/.ssh"

    # Check if the SSH config file already exists
    if [ -f "$SSH_CONFIG" ]; then
        echo "Existing SSH config detected. Appending hosts..."
    else
        echo "No SSH config found. Creating a new one..."
        touch "$SSH_CONFIG"
    fi

    # Append or update the new host configuration in the SSH config file
    if grep -q "Host Rosie" "$SSH_CONFIG"; then
        echo "Updating existing Rosie config..."
        sed -i "s|^  User .*|  User $ROSIE_USER|" "$SSH_CONFIG"  # Update the User line for Rosie

        # Check if IdentityFile is already correct, only update if needed
        if ! grep -q "IdentityFile $ID_FILE_PATH" "$SSH_CONFIG"; then
            sed -i "s|^  IdentityFile .*|  IdentityFile $ID_FILE_PATH|" "$SSH_CONFIG"  # Update IdentityFile line
        fi
    else
        echo "Adding new Rosie config..."
        cat >> "$SSH_CONFIG" <<EOL

Host Rosie
  HostName dh-mgmt3.hpc.msoe.edu
  User $ROSIE_USER
  IdentityFile $ID_FILE_PATH
EOL
    fi

    # Update the "Host dh-node*" config block
    if grep -q "Host dh-node*" "$SSH_CONFIG"; then
        echo "Updating existing dh-node* config..."
        sed -i "s|^  User .*|  User $ROSIE_USER|" "$SSH_CONFIG"  # Update the User line for dh-node*

        # Check if IdentityFile is already correct, only update if needed
        if ! grep -q "IdentityFile $ID_FILE_PATH" "$SSH_CONFIG"; then
            ESCAPED_ID_FILE_PATH=$(echo "$ID_FILE_PATH" | sed 's/\\/\\\\/g')
			sed -i "s|^  IdentityFile .*|  IdentityFile $ESCAPED_ID_FILE_PATH|" "$SSH_CONFIG"

        fi
    else
        echo "Adding new dh-node* config..."
        cat >> "$SSH_CONFIG" <<EOL

Host dh-node*
  HostName %h.hpc.msoe.edu
  User $ROSIE_USER
  IdentityFile $ID_FILE_PATH
  ProxyJump Rosie
EOL
    fi

    # Ensure Windows-style line endings
    unix2dos "$SSH_CONFIG" 2>/dev/null

    # Mark setup as complete and save the Rosie username in the new format
    printf "ROSIE_USER=%s\n" "$ROSIE_USER" > "$MARKER_FILE"
    echo "Setup complete. SSH config updated at $SSH_CONFIG"
else
    echo "Setup already completed. Proceeding with task..."

    # Load previous setup data from marker file (if it exists)
    if [ -f "$MARKER_FILE" ]; then
        source "$MARKER_FILE"
    fi

    # Check if SSH key exists, if not, prompt user to create it
    if [ ! -f "$WIN_HOME/.ssh/id_ed25519" ]; then
        read -p "SSH key does not exist. Do you want to create one? (y/n): " CREATE_KEY
        if [[ "$CREATE_KEY" == "y" || "$CREATE_KEY" == "Y" ]]; then
            ssh-keygen -t ed25519 -f "$WIN_HOME/.ssh/id_ed25519"
            echo "SSH key created."
            
            # Copy key to WSL
            mkdir -p ~/.ssh
            cp /mnt/c/Users/$WIN_USER/.ssh/id_ed25519 ~/.ssh/
            cp /mnt/c/Users/$WIN_USER/.ssh/id_ed25519.pub ~/.ssh/
            chmod 600 ~/.ssh/id_ed25519
            chmod 644 ~/.ssh/id_ed25519.pub
            echo "SSH key copied to WSL."
        fi
    fi

    # Check SSH key copy status using sourced variable
    if [ "$SSH_KEY_COPIED" = "true" ]; then
        echo "SSH key has already been copied to the remote server. Skipping..."
    else
        echo "NOTE: Skipping SSH Key Remote Copy is not recommended."
        read -p "Do you want to copy the SSH key to the remote server now? (y/n): " COPY_KEY
        if [[ "$COPY_KEY" == "y" || "$COPY_KEY" == "Y" ]]; then
            ssh-copy-id -i "$WIN_HOME/.ssh/id_ed25519.pub" "$ROSIE_USER@$REMOTE_SERVER"
            
            if [ $? -eq 0 ]; then
                echo "SSH key copied to $REMOTE_SERVER."
                
                # Update marker file with new SSH key status while preserving ROSIE_USER
                printf "SSH_KEY_COPIED=%s\n" "true" >> "$MARKER_FILE"
            else
                echo "Failed to copy SSH key to $REMOTE_SERVER. Please check your connection or try again later."
            fi
        fi
    fi

    # Proceed with the command execution
    echo "Running the command: $COMMAND_TO_RUN"
	# Extract time from arguments (default to 1 hour if not provided)
	TIME_IN_SECONDS=3600  # Default: 1 hour

	# Regex to match time in the format days-HH:MM:SS (days optional)
	if [[ "$@" =~ --time=([0-9]+)-([0-9]+):([0-9]+):([0-9]+) ]]; then
	  DAYS=${BASH_REMATCH[1]}
	  HOURS=${BASH_REMATCH[2]}
	  MINUTES=${BASH_REMATCH[3]}
	  SECONDS=${BASH_REMATCH[4]}
	  TIME_IN_SECONDS=$((DAYS * 86400 + HOURS * 3600 + MINUTES * 60 + SECONDS))
	elif [[ "$@" =~ --time=([0-9]+):([0-9]+):([0-9]+) ]]; then
	  HOURS=${BASH_REMATCH[1]}
	  MINUTES=${BASH_REMATCH[2]}
	  SECONDS=${BASH_REMATCH[3]}
	  TIME_IN_SECONDS=$((HOURS * 3600 + MINUTES * 60 + SECONDS))
	fi

	# SSH into the remote server and execute the tmux command
	echo "Connecting to Rosie"
	echo "Allocating Resources"
	NODE=$(ssh -q $REMOTE_SERVER "
	  tmux new-session -d -s $SESSION_NAME \"$COMMAND_TO_RUN\"; 
	  sleep 5  # Wait for the session to start and output to be generated
	  captured_output=\$(tmux capture-pane -p -t $SESSION_NAME);
	  echo \"\$captured_output\" 
	")

	# Extract the node from the captured output
	NODE=$(echo "$NODE" | grep -oP 'Nodes\s+\Kdh-node[0-9]+')

	# Validate Node
	if [[ "$NODE" =~ ^dh-node[0-9]+$ ]]; then
	  echo "Allocated Node: $NODE"
	  echo "Launching VS-Code Remote Connection"
	  code --new-window --remote "ssh-remote+$NODE" 2>/dev/null

	  # Countdown Timer with Progress Bar
	  echo "Press 'x' to Exit Allocation and Cleanup"
	  if [ -t 0 ]; then
		SAVED_STTY="`stty --save`"
		stty -echo -icanon -icrnl time 0 min 0
	  fi
	  keypress=''
	  while [ "x$keypress" = "x" ] && [ $TIME_IN_SECONDS -gt 0 ]; do
		sleep 1
		TIME_IN_SECONDS=$((TIME_IN_SECONDS - 1))
		ELAPSED=$((ELAPSED + 1))

		# Calculate progress percentage
		PERCENT=$(( (ELAPSED * 100) / (ELAPSED + TIME_IN_SECONDS) ))

		# Generate progress bar
		FILLED=$((PERCENT / 5))  # Scale to 20 characters
		EMPTY=$((20 - FILLED))
		BAR=$(printf "%0.s█" $(seq 1 $FILLED))$(printf "%0.s-" $(seq 1 $EMPTY))

		# Display countdown with progress bar
		printf "\rTime remaining: $(date -u -d @$TIME_IN_SECONDS +%H:%M:%S) [$BAR] $PERCENT%% "
		keypress="`cat -v`"
	  done
	  if [ -t 0 ]; then stty "$SAVED_STTY"; fi

	  echo ""

	  # Cleanup
	  ssh -q $REMOTE_SERVER "tmux kill-session -t $SESSION_NAME"
	  echo "Allocation exited and cleaned up. Goodbye!"
	else
	  echo "Error: Could not retrieve or validate allocated node."
	  echo "This could be due a failed ssh connection or resources being unavailable"
	  echo "Cleaning up allocation..."
	  
	  ssh -q $REMOTE_SERVER "tmux kill-session -t $SESSION_NAME"
	  echo "Allocation exited due to error. Goodbye!"
	fi
fi