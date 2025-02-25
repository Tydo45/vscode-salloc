Add-Type -AssemblyName System.Windows.Forms

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "WSL Salloc Configurator"
$form.Size = New-Object System.Drawing.Size(400, 350)
$form.StartPosition = "CenterScreen"
$form.DialogResult = [System.Windows.Forms.DialogResult]::None

# Label & Dropdown for Predefined Configurations
$labelConfig = New-Object System.Windows.Forms.Label
$labelConfig.Text = "Select a Preset:"
$labelConfig.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($labelConfig)

$dropdownConfig = New-Object System.Windows.Forms.ComboBox
$dropdownConfig.Location = New-Object System.Drawing.Point(150, 20)
$dropdownConfig.Size = New-Object System.Drawing.Size(200, 20)
$dropdownConfig.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($dropdownConfig)

# Predefined configurations
$configs = @{
    "Default" = @{ time="01:00:00"; partition="teaching"; gpus="1"; cpus="8" }
    "GPU Heavy" = @{ time="01:00:00"; partition="teaching"; gpus="1"; cpus="16" }
    "CPU Heavy" = @{ time="01:00:00"; partition="teaching"; gpus="1"; cpus="32" }
    "Short Test" = @{ time="00:30:00"; partition="teaching"; gpus="1"; cpus="4" }
}

# Labels and Dropdowns for individual parameters
$labels = @("Time:", "Partition:", "GPUs:", "CPUs per Task:")
$paramKeys = @("time", "partition", "gpus", "cpus")
$paramDropdowns = @{}
$paramTextboxes = @{}
$paramCheckboxes = @{}

$timeOptions = @("01:00:00", "02:00:00", "03:00:00", "04:00:00")
$partitionOptions = @("teaching", "dgx", "dgxh100")
$gpuOptions = @("0", "1", "2", "4")
$cpuOptions = @("8", "16", "32")

$options = @{
    "time" = $timeOptions
    "partition" = $partitionOptions
    "gpus" = $gpuOptions
    "cpus" = $cpuOptions
}

for ($i = 0; $i -lt $labels.Count; $i++) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $labels[$i]
    $label.Location = New-Object System.Drawing.Point(20, (60 + ($i * 40)))
    $form.Controls.Add($label)

    $dropdown = New-Object System.Windows.Forms.ComboBox
    $dropdown.Location = New-Object System.Drawing.Point(150, (60 + ($i * 40)))
    $dropdown.Size = New-Object System.Drawing.Size(120, 20)
    $dropdown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $dropdown.Items.AddRange($options[$paramKeys[$i]])
    $form.Controls.Add($dropdown)
    $paramDropdowns[$paramKeys[$i]] = $dropdown

    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = "Custom"
    $checkbox.Location = New-Object System.Drawing.Point(280, (60 + ($i * 40)))
    $form.Controls.Add($checkbox)
    $paramCheckboxes[$paramKeys[$i]] = $checkbox

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(150, (60 + ($i * 40)))
    $textbox.Size = New-Object System.Drawing.Size(120, 20)
    $textbox.Visible = $false
    $form.Controls.Add($textbox)
    $paramTextboxes[$paramKeys[$i]] = $textbox

    # Toggle visibility between dropdown and textbox
    $checkbox.Add_CheckStateChanged({
        if ($checkbox.Checked) {
            $dropdown.Visible = $false
            $textbox.Visible = $true
        } else {
            $dropdown.Visible = $true
            $textbox.Visible = $false
        }
    })
}

# Function to update dropdown values based on selected config
$dropdownConfig.Add_SelectedIndexChanged({
    $selectedConfig = $configs[$dropdownConfig.SelectedItem]
    
    foreach ($key in $paramKeys) {
        if (-not $paramCheckboxes[$key].Checked) {
            $paramDropdowns[$key].SelectedItem = $selectedConfig[$key]
        }
    }
})

# Populate the config dropdown
$dropdownConfig.Items.AddRange($configs.Keys)
$dropdownConfig.SelectedIndex = 0  # Select the first config by default

# Run Button
$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "Run"
$runButton.Location = New-Object System.Drawing.Point(150, 260)
$runButton.Add_Click({
    try {
        $selectedConfig = $configs[$dropdownConfig.SelectedItem]
        
        # Collect selected values
        $time = if ($paramCheckboxes["time"].Checked) { $paramTextboxes["time"].Text } else { $paramDropdowns["time"].SelectedItem }
        $partition = if ($paramCheckboxes["partition"].Checked) { $paramTextboxes["partition"].Text } else { $paramDropdowns["partition"].SelectedItem }
        $gpus = if ($paramCheckboxes["gpus"].Checked) { $paramTextboxes["gpus"].Text } else { $paramDropdowns["gpus"].SelectedItem }
        $cpus = if ($paramCheckboxes["cpus"].Checked) { $paramTextboxes["cpus"].Text } else { $paramDropdowns["cpus"].SelectedItem }

        # Get the script directory using $PSScriptRoot
        $scriptPath = $PSScriptRoot
        if (-not $scriptPath) {
            $scriptPath = Split-Path -Parent $PSCommandPath
        }
        if (-not $scriptPath) {
            $scriptPath = $PWD.Path
        }
        Write-Host "Script Path: $scriptPath"
        
        $bashScript = Join-Path $scriptPath "vscode-salloc-autosetup-v2.sh"
        Write-Host "Bash Script Path: $bashScript"
        
        # Verify bash script exists
        if (-not (Test-Path $bashScript)) {
            throw "Bash script not found at: $bashScript"
        }
        
        # Create a temporary script to execute the command
        $tempScript = Join-Path $scriptPath "temp_run.sh"
        $bashCommand = @"
#!/bin/bash
script_path=`$(wslpath -u "$bashScript")
chmod +x "`$script_path"
"`$script_path" --time="$time" --partition="$partition" --gpus="$gpus" --cpus-per-task="$cpus"
rm "`$(wslpath -u "$tempScript")" 2>/dev/null
"@
        # Write the script with Unix line endings
        [System.IO.File]::WriteAllText($tempScript, $bashCommand.Replace("`r`n", "`n"))
        
        # Run the temporary script through WSL without waiting
        Start-Process "wsl" -ArgumentList "bash `"$(wsl wslpath -u "$tempScript")`"" -NoNewWindow
        
        # Set DialogResult to OK before closing
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Error: $errorMessage"
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred: $errorMessage`n`nPlease check that both scripts are in the same directory.",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        # Set DialogResult to OK even on error, since we're handling it
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    }
})

$form.Controls.Add($runButton)

# Add form closing event handler
$form.Add_FormClosing({
    param($sender, $e)
    if ($form.DialogResult -eq [System.Windows.Forms.DialogResult]::None) {
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    }
})

# Show the form
$form.ShowDialog() | Out-Null
