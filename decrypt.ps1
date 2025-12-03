# download veracrypt portable cli from https://www.veracrypt.fr/en/Downloads.html to usb
param (
    # Path to VeraCrypt portable CLI
    [Parameter(Mandatory=$true)]
    [string]$VeraCryptExePath,     # e.g. X:\VeraCrypt\veracrypt_x64.exe

    # Path to the VeraCrypt container that holds your GPG keys
    [Parameter(Mandatory=$true)]
    [string]$VaultPath,            # e.g. X:\Vault.vc

    # Drive letter where the vault will be mounted
    [Parameter(Mandatory=$true)]
    [string]$DriveLetter,          # e.g. K

    # Encrypted password file (on USB, outside or inside vault)
    [Parameter(Mandatory=$true)]
    [SecureString]$EncryptedPasswordPath, # e.g. X:\vc_pass.txt.gpg

    # Your GPG key ID (the one used to encrypt vc_pass.txt.gpg)
    [Parameter(Mandatory=$true)]
    [string]$GpgKeyID
)

# Helper to fail fast
function FailAndExit {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

# 1. Mount VeraCrypt vault (keys vault)
Write-Host "[*] Mounting VeraCrypt vault..."
& $VeraCryptExePath /v "$VaultPath" /l $DriveLetter /q /a
if ($LASTEXITCODE -ne 0) {
    FailAndExit "Failed to mount VeraCrypt volume. Check path, password, and VeraCrypt executable."
}

# Normalize the drive path
$vaultDrive = "$DriveLetter`:"

# 2. Import GPG keys from inside vault
$masterKeyPath   = Join-Path $vaultDrive "gpg\private-master.key"
$subkeysPath     = Join-Path $vaultDrive "gpg\private-subkeys.key"
$ownertrustPath  = Join-Path $vaultDrive "gpg\ownertrust.txt"

Write-Host "[*] Importing GPG keys from vault..."
if (-not (Test-Path $masterKeyPath) -or -not (Test-Path $subkeysPath) -or -not (Test-Path $ownertrustPath)) {
    FailAndExit "GPG key files not found in vault (expected gpg\private-master.key, gpg\private-subkeys.key, gpg\ownertrust.txt)."
}

gpg --import "$masterKeyPath"
if ($LASTEXITCODE -ne 0) { FailAndExit "Failed to import private-master.key" }

gpg --import "$subkeysPath"
if ($LASTEXITCODE -ne 0) { FailAndExit "Failed to import private-subkeys.key" }

gpg --import-ownertrust "$ownertrustPath"
if ($LASTEXITCODE -ne 0) { FailAndExit "Failed to import ownertrust.txt" }

# 3. Decrypt password to a temp file
Write-Host "[*] Decrypting SSD password..."
$tempFile = Join-Path $env:TEMP "vc_pass.tmp"

gpg --decrypt "$EncryptedPasswordPath" > $tempFile
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tempFile)) {
    FailAndExit "Failed to decrypt SSD password. Check EncryptedPasswordPath and GPG key."
}

# 4. Load password into RAM
$password = Get-Content $tempFile -Raw

# 5. Put password into clipboard (Option B)
Set-Clipboard -Value $password
Write-Host "[OK] SSD password placed in clipboard for 10 seconds."
Write-Host "Paste it into VeraCrypt or wherever needed, then wait..."

Start-Sleep -Seconds 10

# 6. Clear clipboard
Set-Clipboard -Value ""
Write-Host "[*] Clipboard cleared."

# 7. Secure overwrite and delete temp file
Write-Host "[*] Wiping temp file..."
try {
    $bytes = New-Object byte[] 4096
    (New-Object Random).NextBytes($bytes)
    [IO.File]::WriteAllBytes($tempFile, $bytes)
} catch {
    Write-Host "[WARN] Failed to overwrite temp file, deleting anyway."
}
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

# 8. Clear password from RAM
$password = $null
Remove-Variable password -ErrorAction SilentlyContinue

# 9. Delete GPG secret keys from this machine
Write-Host "[*] Deleting imported secret keys from GPG keyring..."
gpg --delete-secret-keys $GpgKeyID --yes 2>$null

# 10. Kill gpg-agent (clear from RAM)
Write-Host "[*] Killing gpg-agent..."
gpgconf --kill gpg-agent

# 11. Dismount VeraCrypt vault
Write-Host "[*] Dismounting VeraCrypt vault..."
& $VeraCryptExePath /d $DriveLetter /q

Write-Host "[DONE] Vault dismounted, keys removed, clipboard wiped, temp wiped."


Example usage:
.\unified_vault_clipboard.ps1 `
  -VeraCryptExePath "X:\VeraCrypt\veracrypt_x64.exe" `
  -VaultPath "X:\Vault.vc" `
  -DriveLetter "K" `
  -EncryptedPasswordPath "X:\vc_pass.txt.gpg" `
  -GpgKeyID "YOURKEYID"
