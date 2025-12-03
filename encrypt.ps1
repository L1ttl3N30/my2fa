param (
    # Your GPG recipient key ID (for encrypting the VC password)
    [Parameter(Mandatory=$true)]
    [string]$GpgRecipient,

    # USB path where the encrypted password (and optionally keys) will be stored
    [Parameter(Mandatory=$true)]
    [string]$UsbPath,             # e.g. X:\

    # If $true → export secret keys to USB and delete from local keyring
    [Parameter(Mandatory=$false)]
    [bool]$MoveKeysToUsb = $false
)

function FailAndExit {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $UsbPath)) {
    FailAndExit "USB path '$UsbPath' does not exist."
}

# 1. Generate strong password using GPG RNG
Write-Host "[1] Generating strong SSD password using GPG RNG..."
# 64 bytes of random → ~512 bits, armored
gpg --gen-random --armor 2 64 > "vc_pass.txt"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "vc_pass.txt")) {
    FailAndExit "Failed to generate random password using gpg."
}

Write-Host "[OK] Random password saved temporarily to vc_pass.txt"

# 2. Encrypt the password with your GPG key
Write-Host "[2] Encrypting password with GPG recipient $GpgRecipient ..."
gpg --encrypt --recipient $GpgRecipient "vc_pass.txt"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "vc_pass.txt.gpg")) {
    FailAndExit "Failed to encrypt vc_pass.txt with GPG."
}

# 3. Move encrypted password to USB
$destEnc = Join-Path $UsbPath "vc_pass.txt.gpg"
Write-Host "[3] Moving encrypted password to USB: $destEnc"
Move-Item "vc_pass.txt.gpg" $destEnc -Force

# 4. Secure overwrite & delete plaintext vc_pass.txt
Write-Host "[4] Securely overwriting plaintext password file..."
try {
    $bytes = New-Object byte[] 4096
    (New-Object Random).NextBytes($bytes)
    [IO.File]::WriteAllBytes("vc_pass.txt", $bytes)
} catch {
    Write-Host "[WARN] Failed to overwrite vc_pass.txt, deleting anyway."
}
Remove-Item "vc_pass.txt" -Force -ErrorAction SilentlyContinue

Write-Host "[OK] Plaintext password wiped. Only encrypted password remains on USB."

# 5. Optionally export secret keys to USB and delete locally
if ($MoveKeysToUsb) {
    Write-Host ""
    Write-Host "!!! DANGEROUS OPERATION !!!" -ForegroundColor Yellow
    Write-Host "This will export your GPG SECRET KEYS for $GpgRecipient to USB and delete them from this machine." -ForegroundColor Yellow
    Write-Host "If you lose the USB or these files, you may permanently lose access to all data encrypted with this key." -ForegroundColor Yellow
    $confirm = Read-Host "Type 'I UNDERSTAND' to continue"
    if ($confirm -ne "I UNDERSTAND") {
        Write-Host "[INFO] Aborting key move operation."
        exit 0
    }

    $secKeyPath      = Join-Path $UsbPath "gpg_secret_keys_$($GpgRecipient).key"
    $secSubKeyPath   = Join-Path $UsbPath "gpg_secret_subkeys_$($GpgRecipient).key"
    $ownertrustPath  = Join-Path $UsbPath "ownertrust_$($GpgRecipient).txt"

    Write-Host "[5] Exporting secret keys to USB..."
    gpg --export-secret-keys $GpgRecipient > $secKeyPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $secKeyPath)) {
        FailAndExit "Failed to export secret keys."
    }

    gpg --export-secret-subkeys $GpgRecipient > $secSubKeyPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $secSubKeyPath)) {
        FailAndExit "Failed to export secret subkeys."
    }

    gpg --export-ownertrust > $ownertrustPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ownertrustPath)) {
        FailAndExit "Failed to export ownertrust."
    }

    Write-Host "[OK] Secret keys and ownertrust exported to USB."
    Write-Host "  Secret keys:        $secKeyPath"
    Write-Host "  Secret subkeys:     $secSubKeyPath"
    Write-Host "  Ownertrust:         $ownertrustPath"

    # Delete local secret keys
    Write-Host "[6] Deleting local secret keys from this machine..."
    gpg --delete-secret-keys $GpgRecipient --yes 2>$null
    Write-Host "[OK] Local secret keys removed. Private key now ONLY on USB."

} else {
    Write-Host "[INFO] Not moving GPG keys. Use -MoveKeysToUsb \$true if you want key only on USB."
}

Write-Host ""
Write-Host "[DONE] Setup complete."
Write-Host "Encrypted VeraCrypt password is stored at: $destEnc"
if ($MoveKeysToUsb) {
    Write-Host "Your GPG private key now exists only on USB (for this key ID)."
}


# usage example:
.\setup_vc_password_and_move_keys.ps1 `
  -GpgRecipient "YOURKEYID" `
  -UsbPath "X:\" `
  -MoveKeysToUsb $false
# Notes:
- change to $true to move keys to usb and delete local copies -> will be prompted for confirmation