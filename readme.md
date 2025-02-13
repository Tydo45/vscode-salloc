# VSCode SALLOC Auto Setup Script (v2)
===================================

This script automates the process of setting up and using VS Code with SLURM 
allocations on ROSIE (MSOE's HPC cluster). It handles SSH configuration, key 
management, and resource allocation automatically.

## Features
* Automated SSH configuration for ROSIE and compute nodes
* SSH key generation and management
* Passwordless login setup
* SLURM resource allocation
* VS Code remote session launching
* Progress bar with remaining time
* Support for multiple node types (dh-node*, dh-dgx*, dh-dgxh100*)

## Prerequisites
* Windows Subsystem for Linux (WSL)
* Visual Studio Code with Remote-SSH extension
* OpenSSH client
* tmux
* unix2dos utility

## Installation
1. Download the script:
   ```bash
   wget https://raw.githubusercontent.com/your-repo/vscode-salloc-autosetup-v2.sh
   chmod +x vscode-salloc-autosetup-v2.sh
   ```

## First-Time Setup
Run the script with the --setup flag:
    ./vscode-salloc-autosetup-v2.sh --setup

This will:
1. Prompt for your ROSIE username
2. Create/update SSH configuration
3. Generate SSH keys if needed
4. Set up passwordless login

## Usage

### Basic Usage:
    ./vscode-salloc-autosetup-v2.sh
    (This allocates resources with default settings - 1 hour on default partition)

### With Specific Time:
    ./vscode-salloc-autosetup-v2.sh --time=2:00:00

### With Additional SLURM Options:
    ./vscode-salloc-autosetup-v2.sh --time=1:00:00 --partition=teaching --gpus=1

### View Help:
    ./vscode-salloc-autosetup-v2.sh --info

## Common SLURM Arguments
| Argument | Description |
|----------|-------------|
| `--time=HH:MM:SS` | Allocation time |
| `--partition=NAME` | Specify partition (teaching, dgx, dgxh100) |
| `--gpus=N` | Number of GPUs |
| `--cpus-per-task=N` | CPUs per task |
| `--mem=SIZE` | Memory per node (e.g., 16G) |

## Interactive Usage
* Press 'x' to exit allocation early
* Progress bar shows remaining time
* Closing the terminal will automatically clean up the allocation

## Files and Locations
* SSH Config: ~/.ssh/config
* SSH Keys: ~/.ssh/id_ed25519 (private) and ~/.ssh/id_ed25519.pub (public)
* Script State: ~/.vscode_salloc_initialized

## Troubleshooting

### 1. If passwordless login isn't working:
   ./vscode-salloc-autosetup-v2.sh --setup

### 2. If VS Code fails to connect:
   - Ensure the Remote-SSH extension is installed
   - Check your SSH configuration
   - Verify your network connection

### 3. If allocation fails:
   - Check SLURM partition availability
   - Verify resource requests are valid
   - Ensure you have allocation permissions

## Notes
* The script automatically handles cleanup if interrupted
* All SSH configurations are backed up before modification
* The script prevents duplicate SSH key entries
* Multiple node types are supported automatically

## Support
For SLURM-specific options and information, connect to ROSIE via SSH and use:
    man salloc

For script-specific help:
    ./vscode-salloc-autosetup-v2.sh --info 
