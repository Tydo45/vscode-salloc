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
* GUI interface for easy resource allocation (Windows)
* Automatic first-time setup and configuration

## Prerequisites
* Windows Subsystem for Linux (WSL)
* Visual Studio Code with Remote-SSH extension
* PowerShell (for GUI interface)

## Installation

Choose one of the following installation methods:

### Option 1: Command-Line Only (WSL)
If you only want to use the command-line interface:

1. Open WSL and navigate to your desired installation directory
2. Download and set up the script:
   ```bash
   wget https://raw.githubusercontent.com/Tydo45/vscode-salloc/main/vscode-salloc-autosetup-v2.sh
   chmod +x vscode-salloc-autosetup-v2.sh
   ```

### Option 2: GUI + Command-Line (Windows)
If you want to use both the GUI and command-line interface:

1. Create a folder on your Windows system (e.g., `C:\Tools\vscode-salloc`)
2. Download both files to this folder:
   - [vscode-salloc-autosetup-v2.sh](https://raw.githubusercontent.com/Tydo45/vscode-salloc/main/vscode-salloc-autosetup-v2.sh)
   - [salloc_gui.ps1](https://raw.githubusercontent.com/Tydo45/vscode-salloc/main/salloc_gui.ps1)
3. Open WSL and ensure the script is executable:
   ```bash
   cd /mnt/c/Tools/vscode-salloc  # Adjust path to match your folder
   chmod +x vscode-salloc-autosetup-v2.sh
   ```

**Note:** For Option 2, keep both files in the same directory for the GUI to work properly.

## First-Time Setup
The script automatically performs first-time setup on initial launch. This includes:
1. Prompting for your ROSIE username
2. Creating/updating SSH configuration
3. Generating SSH keys if needed
4. Setting up passwordless login

You don't need to run setup manually, but if you need to reconfigure, you can use:
```bash
# In WSL:
./vscode-salloc-autosetup-v2.sh --setup
```

## Usage Options

### 1. Command Line Interface (WSL Only)
All command-line operations must be run from within WSL:

#### Basic Usage:
```bash
# In WSL:
./vscode-salloc-autosetup-v2.sh
```
(This allocates resources with default settings - 1 hour on default partition)

#### With Specific Time:
```bash
# In WSL:
./vscode-salloc-autosetup-v2.sh --time=2:00:00
```

#### With Additional SLURM Options:
```bash
# In WSL:
./vscode-salloc-autosetup-v2.sh --time=1:00:00 --partition=teaching --gpus=1
```

#### View Help:
```bash
# In WSL:
./vscode-salloc-autosetup-v2.sh --info
```

### 2. GUI Interface (Windows)
#### Method 1: Run from PowerShell
```powershell
.\salloc_gui.ps1
```

#### Method 2: Create Desktop Shortcut (Recommended)
1. Right-click on your desktop and select `New > Shortcut`
2. In the location field, enter:
   ```
   powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\Path\To\Your\salloc_gui.ps1"
   ```
   Replace `C:\Path\To\Your` with the actual path to your script
3. Click Next
4. Name the shortcut (e.g., "ROSIE Allocation")
5. Right-click the new shortcut and select `Properties`
6. In the "Start in" field, enter the folder path containing your scripts
7. (Optional) Change the icon:
   - Click "Change Icon"
   - Browse to `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`
   - Select the PowerShell icon or choose another icon

The GUI provides:
* Predefined configurations for common use cases
* Easy selection of time, partition, GPUs, and CPUs
* Custom value input for advanced users
* One-click allocation launch
* Automatic WSL integration (no need to manually use WSL)

Preset Configurations:
* Default: 1 hour, teaching partition, 1 GPU, 8 CPUs
* GPU Heavy: 1 hour, teaching partition, 1 GPU, 16 CPUs
* CPU Heavy: 1 hour, teaching partition, 1 GPU, 32 CPUs
* Short Test: 30 minutes, teaching partition, 1 GPU, 4 CPUs

## Common SLURM Arguments
| Argument | Description |
|----------|-------------|
| `--time=HH:MM:SS` | Allocation time |
| `--partition=NAME` | Specify partition (teaching, dgx, dgxh100) |
| `--gpus=N` | Number of GPUs |
| `--cpus-per-task=N` | CPUs per task |

## Interactive Usage
### Command Line Mode (WSL)
* Press 'x' to exit allocation early
* Progress bar shows remaining time
* Closing the terminal will automatically clean up the allocation

### GUI Mode (Windows)
* Select a preset configuration or customize settings
* Toggle between preset and custom values using checkboxes
* Click "Run" to start the allocation
* The GUI will close automatically when the allocation starts
* Double-click the desktop shortcut for quick access (if created)

## Files and Locations
* SSH Config: ~/.ssh/config (in WSL)
* SSH Keys: ~/.ssh/id_ed25519 (private) and ~/.ssh/id_ed25519.pub (public) (in WSL)
* Script State: ~/.vscode_salloc_initialized (in WSL)
* GUI Script: salloc_gui.ps1 (Windows, must be in same directory as main script)

## Troubleshooting

### 1. GUI Issues:
   - Ensure both scripts are in the same directory
   - Run PowerShell as a regular user (not administrator)
   - Check that WSL can access the script directory
   - Verify WSL is properly installed and configured

### 2. WSL Command Line Issues:
   - Ensure you're running the script from within WSL
   - Check that the script has execute permissions (chmod +x)
   - Verify you're in the correct directory

### 3. If passwordless login isn't working:
```bash
# In WSL:
./vscode-salloc-autosetup-v2.sh --setup
```

### 4. If VS Code fails to connect:
   - Ensure the Remote-SSH extension is installed
   - Check your SSH configuration
   - Verify your network connection

### 5. If allocation fails:
   - Check SLURM partition availability
   - Verify resource requests are valid
   - Ensure you have allocation permissions

## Notes
* The GUI automatically handles path conversion between Windows and WSL
* Both interfaces use the same underlying allocation script
* All SSH configurations are backed up before modification
* The script prevents duplicate SSH key entries
* Multiple node types are supported automatically
* First-time setup runs automatically - no manual setup required

## Support
For SLURM-specific options and information, connect to ROSIE via SSH and use:
```bash
# In WSL:
man salloc
```

For script-specific help:
```bash
# In WSL:
./vscode-salloc-autosetup-v2.sh --info
```

For GUI-specific issues, ensure:
1. Both scripts are in the same directory
2. WSL is properly configured
3. PowerShell execution policy allows running scripts
