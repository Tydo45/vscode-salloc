Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form with modern styling
$form = New-Object System.Windows.Forms.Form
$form.Text = "ROSIE Resource Allocator"
$form.Size = New-Object System.Drawing.Size(500, 450)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.DialogResult = [System.Windows.Forms.DialogResult]::None

# Create a title panel
$titlePanel = New-Object System.Windows.Forms.Panel
$titlePanel.Dock = [System.Windows.Forms.DockStyle]::Top
$titlePanel.Height = 60
$titlePanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "ROSIE Resource Allocator"
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Regular)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titlePanel.Controls.Add($titleLabel)

$form.Controls.Add($titlePanel)

# Main content panel
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainPanel.Padding = New-Object System.Windows.Forms.Padding(20)
$form.Controls.Add($mainPanel)

# Label & Dropdown for Predefined Configurations with styling
$labelConfig = New-Object System.Windows.Forms.Label
$labelConfig.Text = "Preset:"
$labelConfig.Location = New-Object System.Drawing.Point(20, 80)
$labelConfig.Size = New-Object System.Drawing.Size(120, 25)
$labelConfig.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$mainPanel.Controls.Add($labelConfig)

# Path to save configurations
$configFilePath = Join-Path $PSScriptRoot 'configurations.json'

# Function to load configurations from file
function Load-Configurations {
    $defaultConfigs = @{
        "Default" = @{ time="01:00:00"; partition="teaching"; gpus="1"; cpus="8" }
    }
    
    # Create a hashtable to store both configs and metadata
    $result = @{
        Configs = $defaultConfigs.Clone()
        LastUsedPreset = "Default"  # Default preset name
    }
    
    if (Test-Path $configFilePath) {
        try {
            $jsonContent = Get-Content $configFilePath -Raw
            $jsonObject = ConvertFrom-Json $jsonContent -ErrorAction Stop
            
            # Load LastUsedPreset if it exists
            if ($jsonObject.PSObject.Properties.Name -contains "LastUsedPreset") {
                $result.LastUsedPreset = $jsonObject.LastUsedPreset
            }
            
            # Load configurations if they exist
            if ($jsonObject.PSObject.Properties.Name -contains "Configs") {
                $jsonConfigs = $jsonObject.Configs
                
                # Process each configuration
                $jsonConfigs.PSObject.Properties | ForEach-Object {
                    $configName = $_.Name
                    $configValue = $_.Value
                    
                    $result.Configs[$configName] = @{}
                    
                    # Process each property of the configuration
                    $configValue.PSObject.Properties | ForEach-Object {
                        $propName = $_.Name
                        $propValue = $_.Value
                        $result.Configs[$configName][$propName] = $propValue
                    }
                }
            }
            
            return $result
        }
        catch {
            Write-Host "Error loading configurations: $_"
            return $result
        }
    }
    return $result
}

# Function to save configurations to file
function Save-Configurations($configsData, $lastUsedPreset) {
    $saveObject = @{
        Configs = $configsData
        LastUsedPreset = $lastUsedPreset
    }
    
    $json = $saveObject | ConvertTo-Json -Depth 4
    Set-Content -Path $configFilePath -Value $json
}

# Load existing configurations
$configsData = Load-Configurations
$configs = $configsData.Configs
$lastUsedPreset = $configsData.LastUsedPreset

# Initialize dropdown
$dropdownConfig = New-Object System.Windows.Forms.ComboBox
$dropdownConfig.Location = New-Object System.Drawing.Point(150, 80)
$dropdownConfig.Size = New-Object System.Drawing.Size(150, 25)
$dropdownConfig.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$dropdownConfig.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$dropdownConfig.BackColor = [System.Drawing.Color]::White
$dropdownConfig.Items.Clear()
$dropdownConfig.Items.AddRange($configs.Keys)
$mainPanel.Controls.Add($dropdownConfig)

# We'll load the last used configuration after all controls are created

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

# Adjust other controls' positions
for ($i = 0; $i -lt $labels.Count; $i++) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $labels[$i]
    $label.Location = New-Object System.Drawing.Point(20, (130 + ($i * 50)))
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $mainPanel.Controls.Add($label)

    $dropdown = New-Object System.Windows.Forms.ComboBox
    $dropdown.Location = New-Object System.Drawing.Point(150, (130 + ($i * 50)))
    $dropdown.Size = New-Object System.Drawing.Size(150, 25)
    $dropdown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $dropdown.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $dropdown.BackColor = [System.Drawing.Color]::White
    $dropdown.Items.AddRange($options[$paramKeys[$i]])
    $mainPanel.Controls.Add($dropdown)
    $paramDropdowns[$paramKeys[$i]] = $dropdown

    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = "Custom"
    $checkbox.Location = New-Object System.Drawing.Point(320, (130 + ($i * 50)))
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $mainPanel.Controls.Add($checkbox)
    $paramCheckboxes[$paramKeys[$i]] = $checkbox

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(150, (130 + ($i * 50)))
    $textbox.Size = New-Object System.Drawing.Size(150, 25)
    $textbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $textbox.BackColor = [System.Drawing.Color]::White
    $textbox.Visible = $false
    $mainPanel.Controls.Add($textbox)
    $paramTextboxes[$paramKeys[$i]] = $textbox

    # Store the current key for use in the event handler
    $currentKey = $paramKeys[$i]
    
    # Toggle visibility between dropdown and textbox
    $checkbox.Add_CheckStateChanged({
        param($sender, $e)
        $key = $currentKey
        if ($paramCheckboxes[$key].Checked) {
            $paramDropdowns[$key].Visible = $false
            $paramTextboxes[$key].Visible = $true
            # Copy current dropdown value to textbox
            $paramTextboxes[$key].Text = $paramDropdowns[$key].Text
        } else {
            $paramDropdowns[$key].Visible = $true
            $paramTextboxes[$key].Visible = $false
        }
    }.GetNewClosure())

    # Set initial dropdown value
    $dropdown.SelectedIndex = 0
}

# Now set up the preset dropdown event handler after all controls exist
$dropdownConfig.Add_SelectedIndexChanged({
    $selectedConfig = $configs[$dropdownConfig.SelectedItem]
    if ($selectedConfig) {
        foreach ($key in $paramKeys) {
            if (-not $paramCheckboxes[$key].Checked -and $paramDropdowns[$key] -ne $null) {
                $value = $selectedConfig[$key]
                $dropdown = $paramDropdowns[$key]
                foreach ($item in $dropdown.Items) {
                    if ($item -eq $value) {
                        $dropdown.Text = $value
                        break
                    }
                }
            }
        }
    }
})

# Load last used configuration
if ($configs.ContainsKey($lastUsedPreset)) {
    $dropdownConfig.SelectedItem = $lastUsedPreset
} else {
    $dropdownConfig.SelectedIndex = 0
}

# Run Button with modern styling
$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "Launch Allocation"
$runButton.Location = New-Object System.Drawing.Point(150, 300)
$runButton.Size = New-Object System.Drawing.Size(150, 35)
$runButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$runButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$runButton.ForeColor = [System.Drawing.Color]::White
$runButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$runButton.Cursor = [System.Windows.Forms.Cursors]::Hand

# Add hover effect
$runButton.Add_MouseEnter({
    $this.BackColor = [System.Drawing.Color]::FromArgb(0, 100, 180)
})
$runButton.Add_MouseLeave({
    $this.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
})

# Add Save Configuration Button
$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "Save Configuration"
$saveButton.Location = New-Object System.Drawing.Point(150, 350)
$saveButton.Size = New-Object System.Drawing.Size(150, 35)
$saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$saveButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$saveButton.ForeColor = [System.Drawing.Color]::White
$saveButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$saveButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$saveButton.Add_Click({
    $inputBox = New-Object System.Windows.Forms.Form
    $inputBox.Text = "Enter Configuration Name"
    $inputBox.Size = New-Object System.Drawing.Size(300, 150)
    $inputBox.StartPosition = "CenterParent"

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(20, 20)
    $textBox.Size = New-Object System.Drawing.Size(240, 25)
    $inputBox.Controls.Add($textBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(100, 60)
    $okButton.Size = New-Object System.Drawing.Size(75, 30)
    $okButton.Add_Click({
        $name = $textBox.Text
        if ($name -ne "") {
            $configs[$name] = @{
                time = if ($paramCheckboxes["time"].Checked) { $paramTextboxes["time"].Text } else { $paramDropdowns["time"].SelectedItem }
                partition = if ($paramCheckboxes["partition"].Checked) { $paramTextboxes["partition"].Text } else { $paramDropdowns["partition"].SelectedItem }
                gpus = if ($paramCheckboxes["gpus"].Checked) { $paramTextboxes["gpus"].Text } else { $paramDropdowns["gpus"].SelectedItem }
                cpus = if ($paramCheckboxes["cpus"].Checked) { $paramTextboxes["cpus"].Text } else { $paramDropdowns["cpus"].SelectedItem }
            }
            Save-Configurations $configs $lastUsedPreset
            $dropdownConfig.Items.Clear()
            $dropdownConfig.Items.AddRange($configs.Keys)
            
            # Select the newly created configuration
            $dropdownConfig.SelectedItem = $name
            
            $inputBox.Close()
        }
    })
    $inputBox.Controls.Add($okButton)

    $inputBox.ShowDialog() | Out-Null
})

# Add Delete Configuration Button
$deleteButton = New-Object System.Windows.Forms.Button
$deleteButton.Text = "Delete Configuration"
$deleteButton.Location = New-Object System.Drawing.Point(320, 350)
$deleteButton.Size = New-Object System.Drawing.Size(150, 35)
$deleteButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$deleteButton.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$deleteButton.ForeColor = [System.Drawing.Color]::White
$deleteButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$deleteButton.Cursor = [System.Windows.Forms.Cursors]::Hand

# Add hover effect for delete button
$deleteButton.Add_MouseEnter({
    $this.BackColor = [System.Drawing.Color]::FromArgb(200, 35, 51)
})
$deleteButton.Add_MouseLeave({
    $this.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
})

# Add delete functionality
$deleteButton.Add_Click({
    $selectedConfig = $dropdownConfig.SelectedItem
    
    # Define default configurations that cannot be deleted
    $defaultConfigNames = @("Default", "GPU Heavy", "CPU Heavy", "Short Test")
    
    if ($selectedConfig -in $defaultConfigNames) {
        [System.Windows.Forms.MessageBox]::Show(
            "Default configurations cannot be deleted.",
            "Cannot Delete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Are you sure you want to delete the configuration '$selectedConfig'?",
        "Confirm Deletion",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        # Remove the configuration
        $configs.Remove($selectedConfig)
        
        # If we deleted the last used preset, set it to Default
        if ($lastUsedPreset -eq $selectedConfig) {
            $lastUsedPreset = "Default"
        }
        
        # Save configurations
        Save-Configurations $configs $lastUsedPreset
        
        # Update dropdown
        $dropdownConfig.Items.Clear()
        $dropdownConfig.Items.AddRange($configs.Keys)
        
        # Select Default or first item
        if ($configs.ContainsKey("Default")) {
            $dropdownConfig.SelectedItem = "Default"
        } else {
            $dropdownConfig.SelectedIndex = 0
        }
        
        [System.Windows.Forms.MessageBox]::Show(
            "Configuration '$selectedConfig' has been deleted.",
            "Configuration Deleted",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
})

$mainPanel.Controls.Add($runButton)
$mainPanel.Controls.Add($saveButton)
$mainPanel.Controls.Add($deleteButton)

# Adjust the layout to ensure visibility
$labelConfig.BringToFront()
$dropdownConfig.BringToFront()

# Update the run button to save the last used preset
$runButton.Add_Click({
    try {
        $selectedPreset = $dropdownConfig.SelectedItem
        
        # Collect selected values
        $time = if ($paramCheckboxes["time"].Checked) { $paramTextboxes["time"].Text } else { $paramDropdowns["time"].SelectedItem }
        $partition = if ($paramCheckboxes["partition"].Checked) { $paramTextboxes["partition"].Text } else { $paramDropdowns["partition"].SelectedItem }
        $gpus = if ($paramCheckboxes["gpus"].Checked) { $paramTextboxes["gpus"].Text } else { $paramDropdowns["gpus"].SelectedItem }
        $cpus = if ($paramCheckboxes["cpus"].Checked) { $paramTextboxes["cpus"].Text } else { $paramDropdowns["cpus"].SelectedItem }

        # Save the last used preset name
        Save-Configurations $configs $selectedPreset

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
        
        # Close the form immediately
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
        $form.Close()
    }
})

# Show the form
$form.ShowDialog() | Out-Null
