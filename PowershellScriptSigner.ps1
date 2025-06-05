Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-MessageBox {
    param (
        [string]$text,
        [string]$caption = "Message"
    )
    [System.Windows.Forms.MessageBox]::Show($text, $caption, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# GUI Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "PowerShell Script Signer"
$form.Size = New-Object System.Drawing.Size(500,300)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# Script Files
$scriptLabel = New-Object System.Windows.Forms.Label
$scriptLabel.Text = "PowerShell Scripts (.ps1):"
$scriptLabel.Location = New-Object System.Drawing.Point(10,20)
$scriptLabel.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($scriptLabel)

$scriptBox = New-Object System.Windows.Forms.TextBox
$scriptBox.Location = New-Object System.Drawing.Point(10,40)
$scriptBox.Size = New-Object System.Drawing.Size(350,40)
$scriptBox.Multiline = $true
$scriptBox.ScrollBars = "Vertical"
$form.Controls.Add($scriptBox)

$scriptBrowse = New-Object System.Windows.Forms.Button
$scriptBrowse.Text = "Browse"
$scriptBrowse.Location = New-Object System.Drawing.Point(370,38)
$scriptBrowse.Add_Click({
	$fd = New-Object System.Windows.Forms.OpenFileDialog
	$fd.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
	$fd.Multiselect = $true
	$initialDir = if ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    Get-Location
}
$fd.InitialDirectory = $initialDir


    if ($fd.ShowDialog() -eq "OK") {
        $scriptBox.Text = ($fd.FileNames -join "`r`n")
    }
})
$form.Controls.Add($scriptBrowse)

# PFX File
$pfxLabel = New-Object System.Windows.Forms.Label
$pfxLabel.Text = "Certificate (.pfx):"
$pfxLabel.Location = New-Object System.Drawing.Point(10,90)
$pfxLabel.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($pfxLabel)

$pfxBox = New-Object System.Windows.Forms.TextBox
$pfxBox.Location = New-Object System.Drawing.Point(10,110)
$pfxBox.Size = New-Object System.Drawing.Size(350,20)
$form.Controls.Add($pfxBox)

$pfxBrowse = New-Object System.Windows.Forms.Button
$pfxBrowse.Text = "Browse"
$pfxBrowse.Location = New-Object System.Drawing.Point(370,108)
$pfxBrowse.Add_Click({
    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.Filter = "PFX Files (*.pfx)|*.pfx"
    if ($fd.ShowDialog() -eq "OK") {
        $pfxBox.Text = $fd.FileName
    }
})
$form.Controls.Add($pfxBrowse)

# Sign Button
$signButton = New-Object System.Windows.Forms.Button
$signButton.Text = "Sign Scripts"
$signButton.Location = New-Object System.Drawing.Point(10,150)
$signButton.Size = New-Object System.Drawing.Size(100,30)
$signButton.Add_Click({
    $scriptPaths = $scriptBox.Text -split "`r`n" | Where-Object { $_ -and (Test-Path $_) }
    $pfxPath = $pfxBox.Text

    if (-not $scriptPaths -or -not (Test-Path $pfxPath)) {
        Show-MessageBox "Script or PFX file path is invalid." "Error"
        return
    }

    $passwordDialog = New-Object System.Windows.Forms.Form
    $passwordDialog.Text = "Enter PFX Password"
    $passwordDialog.Size = New-Object System.Drawing.Size(300,150)
    $passwordDialog.StartPosition = "CenterParent"

    $pwdBox = New-Object System.Windows.Forms.MaskedTextBox
    $pwdBox.UseSystemPasswordChar = $true
    $pwdBox.Size = New-Object System.Drawing.Size(250,20)
    $pwdBox.Location = New-Object System.Drawing.Point(20,20)
    $passwordDialog.Controls.Add($pwdBox)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "OK"
    $okBtn.Location = New-Object System.Drawing.Point(100,60)
    $okBtn.Add_Click({ $passwordDialog.DialogResult = [System.Windows.Forms.DialogResult]::OK; $passwordDialog.Close() })
    $passwordDialog.Controls.Add($okBtn)

    if ($passwordDialog.ShowDialog() -ne "OK") { return }

    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $cert.Import($pfxPath, $pwdBox.Text, 'Exportable,PersistKeySet')

        foreach ($script in $scriptPaths) {
            Set-AuthenticodeSignature -FilePath $script -Certificate $cert | Out-Null
        }
        Show-MessageBox "All scripts successfully signed."
    } catch {
        Show-MessageBox "Signing failed: $_"
    }
})
$form.Controls.Add($signButton)

# Verify Button
$verifyButton = New-Object System.Windows.Forms.Button
$verifyButton.Text = "Verify Signatures"
$verifyButton.Location = New-Object System.Drawing.Point(120,150)
$verifyButton.Size = New-Object System.Drawing.Size(120,30)
$verifyButton.Add_Click({
    $scriptPaths = $scriptBox.Text -split "`r`n" | Where-Object { $_ -and (Test-Path $_) }

    if (-not $scriptPaths) {
        Show-MessageBox "No valid script files to verify." "Error"
        return
    }

    $results = foreach ($script in $scriptPaths) {
        $result = Get-AuthenticodeSignature -FilePath $script
        "$script`nStatus: $($result.Status)`nMessage: $($result.StatusMessage)`n"
    }

    Show-MessageBox ($results -join "`n---`n") "Verification Results"
})
$form.Controls.Add($verifyButton)

# Run the GUI
[void]$form.ShowDialog()
